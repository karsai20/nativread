import SwiftUI

extension Color {
    /// Creates a colour from "#RRGGBB" / "RRGGBB".
    init(hex: String) {
        var value: UInt64 = 0
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        Scanner(string: cleaned).scanHexInt64(&value)
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    /// Linear blend between two "#RRGGBB" colours in sRGB; amount 0
    /// returns `base`, 1 returns `target`. Pure string math so it can
    /// feed both CSS generation and SwiftUI without UIKit.
    static func blendHex(
        _ base: String, toward target: String, amount: Double
    ) -> String {
        let weight = min(max(amount, 0), 1)
        let from = rgb(base)
        let to = rgb(target)
        func mix(_ a: UInt64, _ b: UInt64) -> Int {
            Int((Double(a) + (Double(b) - Double(a)) * weight).rounded())
        }
        return String(
            format: "#%02X%02X%02X",
            mix(from.r, to.r), mix(from.g, to.g), mix(from.b, to.b)
        )
    }

    private static func rgb(_ hex: String) -> (r: UInt64, g: UInt64, b: UInt64) {
        var value: UInt64 = 0
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        Scanner(string: cleaned).scanHexInt64(&value)
        return ((value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF)
    }
}
