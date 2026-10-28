import Foundation
import Carbon.HIToolbox

public func isCJKInputActive() -> Bool {
    guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return false }
    guard let ptr = TISGetInputSourceProperty(source, kTISPropertyInputSourceLanguages) else { return false }
    let langs = unsafeBitCast(ptr, to: CFArray.self) as? [String] ?? []
    return langs.contains { $0.hasPrefix("zh") }
}
