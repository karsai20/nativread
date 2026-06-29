import SwiftUI

extension AppAppearance {
    /// The SwiftUI colour scheme to force, or `nil` to follow the device.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

/// App-level colour palette for chrome surfaces — the editorial identity
/// layer that wraps the reader. Mirrors `ReaderPalette`'s API so views can
/// switch between reading and ambient contexts without re-learning the contract.
///
/// Surface and hairline colours are derived via `blendHex` using the same
/// amounts as `ReaderTheme`, keeping the two systems visually consistent.
struct BrandPalette: Equatable {
    let backgroundHex: String
    let textHex: String
    let secondaryTextHex: String
    let accentHex: String
    let surfaceHex: String
    let surfaceRaisedHex: String
    let hairlineHex: String
    let shadowOpacity: Double
    let isDark: Bool

    var background: Color { Color(hex: backgroundHex) }
    var text: Color { Color(hex: textHex) }
    var secondaryText: Color { Color(hex: secondaryTextHex) }
    var accent: Color { Color(hex: accentHex) }
    var surface: Color { Color(hex: surfaceHex) }
    var surfaceRaised: Color { Color(hex: surfaceRaisedHex) }
    var hairline: Color { Color(hex: hairlineHex) }
}

extension BrandPalette {
    /// "Papír" — warm, eye-friendly light theme. No pure white; low-blue-light
    /// paper tones keep the focus on text. Accent is a calm, desaturated sage
    /// that ties to the NativRead wordmark and rests the eye.
    static let light: BrandPalette = {
        let bg = "#F5F1E8"
        let fg = "#2B2A26"
        return BrandPalette(
            backgroundHex:    bg,
            textHex:          fg,
            secondaryTextHex: "#706E66",
            accentHex:        "#6F7E68",
            surfaceHex:       Color.blendHex(bg, toward: fg, amount: 0.05),
            surfaceRaisedHex: Color.blendHex(bg, toward: fg, amount: 0.08),
            hairlineHex:      Color.blendHex(bg, toward: fg, amount: 0.12),
            shadowOpacity:    0.10,
            isDark:           false
        )
    }()

    /// "Tinta" — warm charcoal dark theme. Background is never pure black and
    /// text is a warm off-white, which reduces halation and night-time glare.
    /// Sage accent lightens here to hold contrast against the dark surface.
    static let dark: BrandPalette = {
        let bg = "#181A18"
        let fg = "#E7E3D8"
        return BrandPalette(
            backgroundHex:    bg,
            textHex:          fg,
            secondaryTextHex: "#9B9A8F",
            accentHex:        "#A6B49E",
            surfaceHex:       Color.blendHex(bg, toward: fg, amount: 0.10),
            surfaceRaisedHex: Color.blendHex(bg, toward: fg, amount: 0.16),
            hairlineHex:      Color.blendHex(bg, toward: fg, amount: 0.20),
            shadowOpacity:    0.40,
            isDark:           true
        )
    }()

    /// Picks `dark` or `light` based on the current system appearance,
    /// the same way `ReaderSettings.effectiveTheme(systemDark:)` does.
    static func resolve(systemDark: Bool) -> BrandPalette {
        systemDark ? .dark : .light
    }
}
