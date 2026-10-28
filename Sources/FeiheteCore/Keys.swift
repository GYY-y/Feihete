import Foundation

public enum Keys {
    private static let letterCodes: [Int: String] = [
        0x00: "A", 0x01: "S", 0x02: "D", 0x03: "F", 0x04: "H", 0x05: "G",
        0x06: "Z", 0x07: "X", 0x08: "C", 0x09: "V", 0x0B: "B",
        0x0C: "Q", 0x0D: "W", 0x0E: "E", 0x0F: "R", 0x10: "Y", 0x11: "T",
        0x1F: "O", 0x20: "U", 0x22: "I", 0x23: "P", 0x25: "L",
        0x26: "J", 0x27: "K", 0x2D: "N", 0x2E: "M"
    ]
    private static let digitCodes: [Int: String] = [
        0x12: "1", 0x13: "2", 0x14: "3", 0x15: "4", 0x17: "5", 0x16: "6",
        0x1A: "7", 0x1C: "8", 0x19: "9", 0x1D: "0",
        0x1B: "-", 0x18: "=", 0x21: "[", 0x1E: "]", 0x32: "`",
        0x29: ";", 0x27: "'", 0x2A: "\\", 0x2B: ",", 0x2C: "/", 0x2F: "."
    ]
    private static let specialCodes: [Int: String] = [
        0x24: "⏎", 0x30: "⇥", 0x31: "Space", 0x33: "⌫", 0x35: "Esc",
        0x7B: "←", 0x7C: "→", 0x7D: "↓", 0x7E: "↑",
        0x7A: "F1", 0x78: "F2", 0x63: "F3", 0x76: "F4", 0x60: "F5",
        0x61: "F6", 0x62: "F7", 0x64: "F8", 0x65: "F9", 0x6D: "F10",
        0x67: "F11", 0x6F: "F12", 0x72: "Ⓥ", 0x4C: "F19"
    ]

    public static func keyName(keyCode: Int64, unicode: String) -> String {
        let scalars = Array(unicode.unicodeScalars)
        if scalars.count == 1, let s = scalars.first, s.value >= 0x20, s.value <= 0x7E {
            return String(s)
        }
        let code = Int(keyCode)
        return letterCodes[code] ?? digitCodes[code] ?? specialCodes[code] ?? "Key\(code)"
    }

    public static func canonicalCombo(flags: UInt64, keyName: String) -> String? {
        let shift: UInt64 = 1 << 17
        let control: UInt64 = 1 << 18
        let option: UInt64 = 1 << 19
        let command: UInt64 = 1 << 20
        var out = ""
        if flags & shift != 0 { out += "⇧" }
        if flags & control != 0 { out += "⌃" }
        if flags & option != 0 { out += "⌥" }
        if flags & command != 0 { out += "⌘" }
        guard !out.isEmpty else { return nil }
        return out.map(String.init).joined(separator: "+") + "+" + keyName
    }

    /// Formats both newly recorded and legacy combo keys with a visible separator.
    public static func formattedCombo(_ combo: String) -> String {
        guard !combo.contains("+") else { return combo }
        let modifierCharacters: Set<Character> = ["⇧", "⌃", "⌥", "⌘"]
        var modifiers: [String] = []
        var remainder = combo
        while let first = remainder.first, modifierCharacters.contains(first) {
            modifiers.append(String(first))
            remainder.removeFirst()
        }
        guard !modifiers.isEmpty, !remainder.isEmpty else { return combo }
        return (modifiers + [remainder]).joined(separator: "+")
    }
}
