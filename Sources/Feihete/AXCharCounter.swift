import Foundation
import ApplicationServices

final class AXCharCounter {
    private var lastElement: AXUIElement?
    private var lastCount: Int?

    func reset() {
        lastElement = nil
        lastCount = nil
    }

    func poll() -> Int {
        let sysWide = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(sysWide, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let ref = focused else {
            reset()
            return 0
        }
        guard CFGetTypeID(ref) == AXUIElementGetTypeID() else {
            reset()
            return 0
        }
        let element = unsafeDowncast(ref, to: AXUIElement.self)

        let count = characterCount(of: element)
        defer { lastElement = element }

        guard count >= 0 else {
            lastCount = nil
            return 0
        }

        if let last = lastElement, let anchor = lastCount, CFEqual(last, element) {
            lastCount = count
            let delta = count - anchor
            if delta > 0 && delta <= 80 {
                return delta
            }
            return 0
        }
        lastCount = count
        return 0
    }

    private func characterCount(of element: AXUIElement) -> Int {
        var value: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXNumberOfCharactersAttribute as CFString, &value) == .success,
           let num = value as? Int {
            return num
        }
        if AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value) == .success,
           let str = value as? String {
            return str.count <= 20000 ? str.count : -1
        }
        return 0
    }
}
