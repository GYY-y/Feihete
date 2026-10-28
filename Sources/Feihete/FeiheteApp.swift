import SwiftUI
import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        StatsEngine.shared.activate()
        if AppPreferences.shared.autoCheckUpdates {
            UpdateService.shared.checkForUpdates()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        StatsEngine.shared.flush()
    }
}

@main
struct FeiheteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var engine = StatsEngine.shared
    @StateObject private var preferences = AppPreferences.shared
    @StateObject private var router = WindowRouter.shared
    @StateObject private var updateService = UpdateService.shared

    var body: some Scene {
        MenuBarExtra {
            LiveView()
                .environmentObject(engine)
                .environmentObject(preferences)
                .environmentObject(router)
                .environmentObject(updateService)
        } label: {
            if let logo = AppBranding.menuBarLogo(size: NSSize(width: 18, height: 18)) {
                Image(nsImage: logo)
            } else {
                Label("Feihete", systemImage: "keyboard")
            }
        }
        .menuBarExtraStyle(.window)

        Window("Feihete", id: "dashboard") {
            MainWindowView()
                .environmentObject(engine)
                .environmentObject(preferences)
                .environmentObject(router)
                .environmentObject(updateService)
                .frame(minWidth: 680, minHeight: 620)
        }
        .windowResizability(.contentMinSize)
    }
}

enum LaunchAtLogin {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }
    static func set(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch {}
    }
}
