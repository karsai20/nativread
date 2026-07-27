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
    let tertiaryTextHex: String
    let accentHex: String
    let accentSoftHex: String
    let surfaceHex: String
    let surfaceRaisedHex: String
    let hairlineHex: String
    let infoHex: String
    let infoSoftHex: String
    let noteHex: String
    let noteSoftHex: String
    let dangerHex: String
    let shadowOpacity: Double
    let overlayOpacity: Double
    let isDark: Bool

    var background: Color { Color(hex: backgroundHex) }
    var text: Color { Color(hex: textHex) }
    var secondaryText: Color { Color(hex: secondaryTextHex) }
    /// Third-level copy: metadata that must recede behind `secondaryText`.
    var tertiaryText: Color { Color(hex: tertiaryTextHex) }
    var accent: Color { Color(hex: accentHex) }
    /// Tinted fill behind accent-coloured icons, pills and selected controls.
    var accentSoft: Color { Color(hex: accentSoftHex) }
    var surface: Color { Color(hex: surfaceHex) }
    var surfaceRaised: Color { Color(hex: surfaceRaisedHex) }
    var hairline: Color { Color(hex: hairlineHex) }
    /// Steel blue — progress and status that is neither brand nor warning.
    var info: Color { Color(hex: infoHex) }
    var infoSoft: Color { Color(hex: infoSoftHex) }
    /// Warm taupe — highlights and annotation accents.
    var note: Color { Color(hex: noteHex) }
    var noteSoft: Color { Color(hex: noteSoftHex) }
    var danger: Color { Color(hex: dangerHex) }
    /// Scrim behind modal sheets.
    var overlay: Color { Color(hex: isDark ? "#000000" : "#181F1B").opacity(overlayOpacity) }
}

extension BrandPalette {
    /// "Papír" — warm, eye-friendly light theme. No pure white; low-blue-light
    /// paper tones keep the focus on text. Accent is a calm, desaturated sage
    /// that ties to the NativRead wordmark and rests the eye.
    ///
    /// Values are the measured mobile-redesign palette rather than derived
    /// blends: `surface` sits *lighter* than the canvas so grouped cards lift
    /// off the page, while `surfaceRaised` sits darker for recessed tracks.
    static let light = BrandPalette(
        backgroundHex:    "#F4F1E9",
        textHex:          "#181F1B",
        secondaryTextHex: "#6C7866",
        tertiaryTextHex:  "#8D9285",
        accentHex:        "#6C7866",
        accentSoftHex:    "#E1DED5",
        surfaceHex:       "#FAF7EF",
        surfaceRaisedHex: "#EBE8E0",
        hairlineHex:      "#D6D4CB",
        infoHex:          "#5D8EB9",
        infoSoftHex:      "#DDE8EF",
        noteHex:          "#8E846F",
        noteSoftHex:      "#EDE8DC",
        dangerHex:        "#B85F5F",
        shadowOpacity:    0.10,
        overlayOpacity:   0.34,
        isDark:           false
    )

    /// "Tinta" — warm charcoal dark theme. Background is never pure black and
    /// text is a warm off-white, which reduces halation and night-time glare.
    /// Sage accent lightens here to hold contrast against the dark surface.
    static let dark = BrandPalette(
        backgroundHex:    "#181B18",
        textHex:          "#F4F1E9",
        secondaryTextHex: "#B4B8AB",
        tertiaryTextHex:  "#92928B",
        accentHex:        "#B4B8AB",
        accentSoftHex:    "#3A4339",
        surfaceHex:       "#2D2E2B",
        surfaceRaisedHex: "#3A3834",
        hairlineHex:      "#3A3834",
        infoHex:          "#97A8B2",
        infoSoftHex:      "#2C3C43",
        noteHex:          "#B8AE96",
        noteSoftHex:      "#433E33",
        dangerHex:        "#E27676",
        shadowOpacity:    0.40,
        overlayOpacity:   0.68,
        isDark:           true
    )

    /// Picks `dark` or `light` based on the current system appearance,
    /// the same way `ReaderSettings.effectiveTheme(systemDark:)` does.
    static func resolve(systemDark: Bool) -> BrandPalette {
        systemDark ? .dark : .light
    }
}
