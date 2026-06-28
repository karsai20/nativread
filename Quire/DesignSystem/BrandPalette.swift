import SwiftUI

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
    /// Warm parchment light theme — editorial and inviting without being
    /// clinical. Accent is a muted terracotta-red that ages like ink on paper.
    static let light: BrandPalette = {
        let bg = "#F7F3EC"
        let fg = "#1A1714"
        return BrandPalette(
            backgroundHex:    bg,
            textHex:          fg,
            secondaryTextHex: "#6B6258",
            accentHex:        "#9A3B2E",
            surfaceHex:       Color.blendHex(bg, toward: fg, amount: 0.05),
            surfaceRaisedHex: Color.blendHex(bg, toward: fg, amount: 0.08),
            hairlineHex:      Color.blendHex(bg, toward: fg, amount: 0.12),
            shadowOpacity:    0.10,
            isDark:           false
        )
    }()

    /// Deep ink dark theme — the academic night mode, complementing the
    /// reader's "academia" atmosphere. Surfaces are lifted via the same
    /// blend amounts used by dark `ReaderTheme` cases.
    static let dark: BrandPalette = {
        let bg = "#1C1916"
        let fg = "#E9E2D6"
        return BrandPalette(
            backgroundHex:    bg,
            textHex:          fg,
            secondaryTextHex: "#9C9387",
            accentHex:        "#C25A45",
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
