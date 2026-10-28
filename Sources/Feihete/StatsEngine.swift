import Foundation
import AppKit
import CoreGraphics
import Combine

final class StatsEngine: ObservableObject {
    static let shared = StatsEngine()

    private let store = StatsStore()
    @Published private(set) var granted = false
    private(set) var today: DayStats
    private(set) var currentKPM = 0

    private var tap: CFMachPort?
    private var tapSource: CFRunLoopSource?
    private var timers: [Timer] = []

    private var frontCache: (bundle: String, name: String, at: Date)?
    private let axCounter = AXCharCounter()
    private var rolling = RollingMinute()
    private var lastIMEWasCJK = false
    private var imeCache: (isCJK: Bool, at: Date) = (false, .distantPast)
    private var lastKeyAt: Date?
    private var lastAXPoll = Date.distantPast
    private var dirty = false
    private var iconCache: [String: NSImage] = [:]

    private init() {
        today = store.load(StatsStore.formatDate(Date()))
        lastIMEWasCJK = isCJKInputActive()
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.frontCache = nil
        }
    }

    func activate() {
        permissionTick()
        timers = [
            schedule(2) { [weak self] in self?.permissionTick() },
            schedule(10) { [weak self] in self?.flush() },
            schedule(1) { [weak self] in self?.idleTick() }
        ]
    }

    private func schedule(_ interval: TimeInterval, _ action: @escaping () -> Void) -> Timer {
        let t = Timer(timeInterval: interval, repeats: true) { _ in action() }
        RunLoop.main.add(t, forMode: .common)
        return t
    }

    private var permissionPrompted = false

    private func permissionTick() {
        let trusted = AXIsProcessTrusted()
        if trusted != granted {
            granted = trusted
            objectWillChange.send()
        }
        if trusted && tap == nil {
            installTap()
        }
        if !trusted && !permissionPrompted {
            permissionPrompted = true
            AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as CFString: true] as CFDictionary)
        }
    }

    private func installTap() {
        guard tap == nil else { return }
        let mask = CGEventMask(1) << CGEventType.keyDown.rawValue
        guard let t = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let engine = Unmanaged<StatsEngine>.fromOpaque(refcon).takeUnretainedValue()
                engine.handleEvent(type: type, event: event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return }
        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, t, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: t, enable: true)
        tap = t
        tapSource = src
    }

    fileprivate func handleEvent(type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let t = tap { CGEvent.tapEnable(tap: t, enable: true) }
            return
        }
        guard type == .keyDown else { return }

        let now = Date()
        if event.getIntegerValueField(.keyboardEventAutorepeat) == 1 { return }

        checkRollover(now)
        rolling.push(now)
        currentKPM = rolling.count
        lastKeyAt = now

        let (bundle, name) = frontmost(now)
        let hour = Calendar.autoupdatingCurrent.component(.hour, from: now)
        today.addKeystroke(hour: hour, bundle: bundle, appName: name)
        dirty = true

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        var chars = [UniChar](repeating: 0, count: 8)
        var actual = 0
        event.keyboardGetUnicodeString(maxStringLength: 8, actualStringLength: &actual, unicodeString: &chars)
        let uni = String(decoding: chars.prefix(max(0, actual)), as: UTF16.self)

        let mods = event.flags.rawValue & (UInt64(0b1111) << 17)
        if mods & ((1 << 18) | (1 << 19) | (1 << 20)) != 0 {
            if let combo = Keys.canonicalCombo(flags: mods, keyName: Keys.keyName(keyCode: keyCode, unicode: uni)) {
                today.addCombo(combo)
            }
        } else if imeActive(now) {
            pollAX(now: now, bundle: bundle, appName: name)
        } else {
            let usable = uni.unicodeScalars.filter { $0.value >= 0x21 && $0.value <= 0x7E }
            if usable.count <= 3 {
                today.addLetters(usable.count, bundle: bundle, appName: name)
            }
        }

        today.bumpFastMinute(keys: rolling.count, at: now)
    }

    private func imeActive(_ now: Date) -> Bool {
        if now.timeIntervalSince(imeCache.at) < 0.5 {
            return imeCache.isCJK
        }
        let cjk = isCJKInputActive()
        if cjk != lastIMEWasCJK {
            axCounter.reset()
            lastIMEWasCJK = cjk
        }
        imeCache = (cjk, now)
        return cjk
    }

    private func pollAX(now: Date, bundle: String, appName: String) {
        guard now.timeIntervalSince(lastAXPoll) > 0.3 else { return }
        lastAXPoll = now
        let delta = axCounter.poll()
        if delta > 0 {
            today.addCJK(delta, bundle: bundle, appName: appName)
        }
    }

    private func idleTick() {
        let now = Date()
        checkRollover(now)
        rolling.prune(now)
        let kpm = rolling.count
        if kpm != currentKPM { currentKPM = kpm }

        guard let last = lastKeyAt, now.timeIntervalSince(last) < 6,
              now.timeIntervalSince(lastAXPoll) > 0.5 else { return }
        if imeActive(now) {
            let (bundle, name) = frontmost(now)
            let delta = axCounter.poll()
            if delta > 0 { today.addCJK(delta, bundle: bundle, appName: name) }
        }
    }

    private func checkRollover(_ now: Date) {
        let d = StatsStore.formatDate(now)
        guard d != today.date else { return }
        store.save(today)
        dirty = false
        today = store.load(d)
        axCounter.reset()
        rolling.reset()
        currentKPM = 0
        lastKeyAt = now
        objectWillChange.send()
    }

    private func frontmost(_ now: Date) -> (bundle: String, name: String) {
        if let c = frontCache, now.timeIntervalSince(c.at) < 0.3 {
            return (c.bundle, c.name)
        }
        let app = NSWorkspace.shared.frontmostApplication
        let bundle = app?.bundleIdentifier ?? "_unknown_"
        let name = app?.localizedName ?? "未知应用"
        frontCache = (bundle, name, now)
        return (bundle, name)
    }

    func snapshot() -> Snapshot {
        Snapshot(today: today, currentKPM: currentKPM, granted: granted)
    }

    func allDays() -> [DayStats] {
        store.loadAll()
    }

    func days(for range: StatsRange) -> [DayStats] {
        let todayDate = StatsStore.formatDate(Date())
        let persisted = allDays().filter { day in
            guard range != .today else { return day.date == todayDate }
            let cutoff = Calendar.autoupdatingCurrent.date(byAdding: .day, value: -(range.calendarDays - 1), to: Date()) ?? Date()
            return day.date >= StatsStore.formatDate(cutoff) && day.date <= todayDate
        }
        var days = persisted.filter { $0.date != today.date }
        days.append(today)
        return days.sorted { $0.date < $1.date }
    }

    func stats(for range: StatsRange) -> DayStats {
        DayStats.aggregate(days(for: range), date: range == .today ? today.date : "\(range.rawValue)-\(today.date)")
    }

    func flush() {
        guard dirty else { return }
        store.save(today)
        dirty = false
    }

    func icon(for bundle: String) -> NSImage? {
        if bundle == "_unknown_" { return nil }
        if let img = iconCache[bundle] { return img }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundle) else { return nil }
        let img = NSWorkspace.shared.icon(forFile: url.path)
        img.size = NSSize(width: 18, height: 18)
        iconCache[bundle] = img
        return img
    }

    func appName(for bundle: String, fallback: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundle),
              let appBundle = Bundle(url: url) else {
            return fallback.isEmpty ? bundle : fallback
        }
        let localized = appBundle.localizedInfoDictionary?["CFBundleDisplayName"] as? String
        let display = appBundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        let name = localized ?? display ?? fallback
        return name.isEmpty ? bundle : name
    }

    func openDataFolder() {
        NSWorkspace.shared.activateFileViewerSelecting([store.daysDirectory])
    }

    func clearAllData() {
        store.clearAll()
        today = DayStats(date: StatsStore.formatDate(Date()))
        rolling.reset()
        currentKPM = 0
        lastKeyAt = nil
        dirty = false
        objectWillChange.send()
    }
}
