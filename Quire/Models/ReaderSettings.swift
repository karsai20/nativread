import SwiftUI

/// The four reading atmospheres. Chrome colours follow the page so the
/// whole screen feels like one sheet of paper, the way Apple Books does it.
enum ReaderTheme: String, Codable, CaseIterable, Identifiable {
    case paper, sepia, dusk, ink, academia

    var id: String { rawValue }

    var label: String {
        switch self {
        case .paper:    return Bundle.main.localizedString(forKey: "theme.label.paper", value: "Paper", table: nil)
        case .sepia:    return Bundle.main.localizedString(forKey: "theme.label.sepia", value: "Sepia", table: nil)
        case .dusk:     return Bundle.main.localizedString(forKey: "theme.label.dusk", value: "Dusk", table: nil)
        case .ink:      return Bundle.main.localizedString(forKey: "theme.label.ink", value: "Ink", table: nil)
        case .academia: return Bundle.main.localizedString(forKey: "theme.label.academia", value: "Academia", table: nil)
        }
    }

    // Eye-friendly, modern set: no pure white or black, warm low-blue-light
    // tones, and a unified calm sage accent that ties to the NativRead brand.
    // `academia` is the deliberate exception — it keeps a gold accent for its
    // dark-academia character.
    var backgroundHex: String {
        switch self {
        case .paper: return "#F5F1E8"
        case .sepia: return "#F1E6CF"
        case .dusk: return "#21252B"
        case .ink: return "#181A18"
        case .academia: return "#18241B"
        }
    }

    var textHex: String {
        switch self {
        case .paper: return "#2B2A26"
        case .sepia: return "#3B3020"
        case .dusk: return "#CBCED4"
        case .ink: return "#E7E3D8"
        case .academia: return "#E8E0CD"
        }
    }

    var secondaryTextHex: String {
        switch self {
        case .paper: return "#706E66"
        case .sepia: return "#8C7B5C"
        case .dusk: return "#868B93"
        case .ink: return "#9B9A8F"
        case .academia: return "#A2AE97"
        }
    }

    var accentHex: String {
        switch self {
        case .paper: return "#6F7E68"
        case .sepia: return "#6E7A5F"
        case .dusk: return "#A6B49E"
        case .ink: return "#A6B49E"
        case .academia: return "#C6A24A"
        }
    }

    /// Slightly raised fill vs the page background, for grouped wells.
    var surfaceHex: String {
        Color.blendHex(backgroundHex, toward: textHex, amount: isDark ? 0.10 : 0.05)
    }
    /// A touch more lift than `surface`, for cards / selected wells.
    var surfaceRaisedHex: String {
        Color.blendHex(backgroundHex, toward: textHex, amount: isDark ? 0.16 : 0.08)
    }
    /// Hairline divider / stroke colour.
    var hairlineHex: String {
        Color.blendHex(backgroundHex, toward: textHex, amount: isDark ? 0.20 : 0.12)
    }
    /// Shadow strength tuned per theme: pure-black ink needs the strongest.
    var shadowOpacity: Double {
        switch self {
        case .paper: return 0.10
        case .sepia: return 0.12
        case .dusk:  return 0.30
        case .ink:   return 0.38
        case .academia: return 0.40
        }
    }

    var isDark: Bool {
        switch self {
        case .paper, .sepia: return false
        case .dusk, .ink, .academia: return true
        }
    }

    var background: Color { Color(hex: backgroundHex) }
    var text: Color { Color(hex: textHex) }
    var secondaryText: Color { Color(hex: secondaryTextHex) }
    var accent: Color { Color(hex: accentHex) }
    var surface: Color { Color(hex: surfaceHex) }
    var surfaceRaised: Color { Color(hex: surfaceRaisedHex) }
    var hairline: Color { Color(hex: hairlineHex) }
}

enum ReaderFont: String, Codable, CaseIterable, Identifiable {
    case newYork, georgia, palatino, charter, sanFrancisco, crimson, cormorant

    var id: String { rawValue }

    var label: String {
        switch self {
        case .newYork:      return Bundle.main.localizedString(forKey: "font.label.newYork", value: "New York", table: nil)
        case .georgia:      return Bundle.main.localizedString(forKey: "font.label.georgia", value: "Georgia", table: nil)
        case .palatino:     return Bundle.main.localizedString(forKey: "font.label.palatino", value: "Palatino", table: nil)
        case .charter:      return Bundle.main.localizedString(forKey: "font.label.charter", value: "Charter", table: nil)
        case .sanFrancisco: return Bundle.main.localizedString(forKey: "font.label.sanFrancisco", value: "San Francisco", table: nil)
        case .crimson:      return Bundle.main.localizedString(forKey: "font.label.crimson", value: "Crimson Pro", table: nil)
        case .cormorant:    return Bundle.main.localizedString(forKey: "font.label.cormorant", value: "Cormorant", table: nil)
        }
    }

    /// CSS font stack injected into the chapter document. For bundled
    /// fonts the leading family matches the `@font-face` family name
    /// `ReaderStyle` declares, so the embedded TTF is used; the rest of
    /// the stack is the graceful fallback if the embed ever fails.
    var cssFamily: String {
        switch self {
        case .newYork: return "ui-serif, 'New York', Georgia, serif"
        case .georgia: return "Georgia, serif"
        case .palatino: return "'Palatino', 'Palatino Linotype', 'Book Antiqua', serif"
        case .charter: return "'Charter', 'Iowan Old Style', Georgia, serif"
        case .sanFrancisco: return "-apple-system, ui-sans-serif, 'Helvetica Neue', sans-serif"
        case .crimson: return "'Crimson Pro', Georgia, serif"
        case .cormorant: return "'Cormorant Garamond', Georgia, serif"
        }
    }

    /// The `.ttf` resource (no extension) that must be embedded as an
    /// `@font-face` for this font to render in the reader's WKWebView,
    /// which does not inherit the app's registered fonts. `nil` for
    /// system fonts, which need no embed.
    var bundledFontFile: String? {
        switch self {
        case .crimson: return "CrimsonPro-VariableFont_wght"
        case .cormorant: return "CormorantGaramond-VariableFont_wght"
        case .newYork, .georgia, .palatino, .charter, .sanFrancisco:
            return nil
        }
    }

    /// The `font-family` name the `@font-face` rule declares for a
    /// bundled font. Matches the leading family in `cssFamily`.
    var bundledFontFamily: String? {
        switch self {
        case .crimson: return "Crimson Pro"
        case .cormorant: return "Cormorant Garamond"
        case .newYork, .georgia, .palatino, .charter, .sanFrancisco:
            return nil
        }
    }

    /// SwiftUI preview font for the typography panel. Bundled fonts use
    /// the family name iOS exposes once registered via `UIAppFonts`.
    var previewFont: Font {
        switch self {
        case .newYork: return .system(.body, design: .serif)
        case .sanFrancisco: return .system(.body)
        case .georgia: return .custom("Georgia", size: 17)
        case .palatino: return .custom("Palatino", size: 17)
        case .charter: return .custom("Charter", size: 17)
        case .crimson: return .custom("Crimson Pro", size: 17)
        case .cormorant: return .custom(Typography.displayFamily, size: 17)
        }
    }
}

/// How the reading theme is chosen: pinned by hand, or following the
/// system light/dark appearance.
enum ThemeMode: String, Codable, CaseIterable {
    case manual, system
}

/// How the reader moves through a chapter: discrete pages turned
/// horizontally, or one continuous vertical scroll.
enum PageFlow: String, Codable, CaseIterable, Identifiable {
    case paged, scroll

    var id: String { rawValue }

    var label: String {
        switch self {
        case .paged:  return Bundle.main.localizedString(forKey: "flow.label.paged", value: "Pages", table: nil)
        case .scroll: return Bundle.main.localizedString(forKey: "flow.label.scroll", value: "Scroll", table: nil)
        }
    }

    var icon: String {
        switch self {
        case .paged: return "book.pages"
        case .scroll: return "arrow.up.and.down.text.horizontal"
        }
    }
}

/// The animation used when turning a page in paged flow.
enum PageTransition: String, Codable, CaseIterable, Identifiable {
    case slide, eink, instant

    var id: String { rawValue }

    var label: String {
        switch self {
        case .slide:   return Bundle.main.localizedString(forKey: "transition.label.slide", value: "Slide", table: nil)
        case .eink:    return Bundle.main.localizedString(forKey: "transition.label.eink", value: "E-Ink", table: nil)
        case .instant: return Bundle.main.localizedString(forKey: "transition.label.none", value: "None", table: nil)
        }
    }
}

/// The fully resolved colours for one reading session: theme mode and
/// warm-light shift already applied. Mirrors ReaderTheme's colour API
/// so views can swap between them freely.
struct ReaderPalette: Equatable {
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

struct ReaderSettings: Codable, Equatable {
    var theme: ReaderTheme = .paper
    /// Theme used in system mode when the device is in dark appearance.
    var darkTheme: ReaderTheme = .dusk
    // Follow the device/app appearance by default: light → Paper, dark → Dusk.
    // Keeps the reader consistent with the library (no bright/dark flip when a
    // book opens). Users can still pin a specific theme in the typography panel.
    var themeMode: ThemeMode = .system
    /// 0 = neutral page, 1 = strongest amber shift (blue light cut).
    var warmth: Double = 0
    var pageFlow: PageFlow = .paged
    var pageTransition: PageTransition = .slide
    // Defaults to Charter ('Charter' / 'Iowan Old Style' / Georgia) so a
    // fresh reader matches the warm book serif used across the app chrome.
    // Persisted settings from earlier versions keep whatever the reader chose.
    var font: ReaderFont = .charter
    var fontSize: Double = 18
    var lineHeight: Double = 1.55
    var horizontalMargin: Double = 26
    var isJustified: Bool = true

    static let fontSizeRange: ClosedRange<Double> = 13...26
    static let lineHeightRange: ClosedRange<Double> = 1.25...2.1
    static let marginRange: ClosedRange<Double> = 14...48
    static let warmthRange: ClosedRange<Double> = 0...1

    /// Amber target the page is pulled toward as warmth rises, and how
    /// far each role is allowed to travel at full warmth. The page
    /// shifts hardest; ink shifts gently to preserve contrast; accent
    /// keeps its identity so chrome stays recognisable.
    private static let warmTargetHex = "#FFAE5C"
    private static let backgroundWarmthCap = 0.30
    private static let inkWarmthCap = 0.12

    func effectiveTheme(systemDark: Bool) -> ReaderTheme {
        themeMode == .system && systemDark ? darkTheme : theme
    }

    func palette(systemDark: Bool) -> ReaderPalette {
        let theme = effectiveTheme(systemDark: systemDark)
        guard warmth > 0 else {
            return ReaderPalette(
                backgroundHex: theme.backgroundHex,
                textHex: theme.textHex,
                secondaryTextHex: theme.secondaryTextHex,
                accentHex: theme.accentHex,
                surfaceHex: theme.surfaceHex,
                surfaceRaisedHex: theme.surfaceRaisedHex,
                hairlineHex: theme.hairlineHex,
                shadowOpacity: theme.shadowOpacity,
                isDark: theme.isDark
            )
        }
        func warmed(_ hex: String, cap: Double) -> String {
            Color.blendHex(
                hex, toward: Self.warmTargetHex, amount: warmth * cap
            )
        }
        return ReaderPalette(
            backgroundHex: warmed(
                theme.backgroundHex, cap: Self.backgroundWarmthCap
            ),
            textHex: warmed(theme.textHex, cap: Self.inkWarmthCap),
            secondaryTextHex: warmed(
                theme.secondaryTextHex, cap: Self.inkWarmthCap
            ),
            accentHex: theme.accentHex,
            surfaceHex: warmed(theme.surfaceHex, cap: Self.backgroundWarmthCap),
            surfaceRaisedHex: warmed(
                theme.surfaceRaisedHex, cap: Self.backgroundWarmthCap
            ),
            hairlineHex: warmed(theme.hairlineHex, cap: Self.backgroundWarmthCap),
            shadowOpacity: theme.shadowOpacity,
            isDark: theme.isDark
        )
    }
}

extension ReaderSettings {
    private enum CodingKeys: String, CodingKey {
        case theme, darkTheme, themeMode, warmth, pageFlow,
             pageTransition, font, fontSize, lineHeight,
             horizontalMargin, isJustified
    }

    /// Tolerant decoding: settings persisted by older versions are
    /// missing the newer keys and must fall back to defaults instead
    /// of resetting the user's whole configuration.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = ReaderSettings()
        theme = try container.decodeIfPresent(
            ReaderTheme.self, forKey: .theme) ?? defaults.theme
        darkTheme = try container.decodeIfPresent(
            ReaderTheme.self, forKey: .darkTheme) ?? defaults.darkTheme
        themeMode = try container.decodeIfPresent(
            ThemeMode.self, forKey: .themeMode) ?? defaults.themeMode
        warmth = try container.decodeIfPresent(
            Double.self, forKey: .warmth) ?? defaults.warmth
        pageFlow = try container.decodeIfPresent(
            PageFlow.self, forKey: .pageFlow) ?? defaults.pageFlow
        // Tolerant: a removed raw value ("fade") is present but no longer
        // decodable, so `try?` lets it fall back to the default instead of
        // failing the whole settings decode.
        pageTransition = (try? container.decodeIfPresent(
            PageTransition.self, forKey: .pageTransition
        )) ?? defaults.pageTransition
        font = try container.decodeIfPresent(
            ReaderFont.self, forKey: .font) ?? defaults.font
        fontSize = try container.decodeIfPresent(
            Double.self, forKey: .fontSize) ?? defaults.fontSize
        lineHeight = try container.decodeIfPresent(
            Double.self, forKey: .lineHeight) ?? defaults.lineHeight
        horizontalMargin = try container.decodeIfPresent(
            Double.self, forKey: .horizontalMargin
        ) ?? defaults.horizontalMargin
        isJustified = try container.decodeIfPresent(
            Bool.self, forKey: .isJustified) ?? defaults.isJustified
    }
}
