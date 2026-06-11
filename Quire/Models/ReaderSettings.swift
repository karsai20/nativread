import SwiftUI

/// The four reading atmospheres. Chrome colours follow the page so the
/// whole screen feels like one sheet of paper, the way Apple Books does it.
enum ReaderTheme: String, Codable, CaseIterable, Identifiable {
    case paper, sepia, dusk, ink

    var id: String { rawValue }

    var label: String {
        switch self {
        case .paper: return "Paper"
        case .sepia: return "Sepia"
        case .dusk: return "Dusk"
        case .ink: return "Ink"
        }
    }

    var backgroundHex: String {
        switch self {
        case .paper: return "#FAF6EE"
        case .sepia: return "#F2E5CF"
        case .dusk: return "#23262C"
        case .ink: return "#000000"
        }
    }

    var textHex: String {
        switch self {
        case .paper: return "#1F1A14"
        case .sepia: return "#41311E"
        case .dusk: return "#C8CAD1"
        case .ink: return "#ABABAB"
        }
    }

    var secondaryTextHex: String {
        switch self {
        case .paper: return "#8A8070"
        case .sepia: return "#94805F"
        case .dusk: return "#7C7F88"
        case .ink: return "#5E5E5E"
        }
    }

    var accentHex: String {
        switch self {
        case .paper: return "#9A3B2E"
        case .sepia: return "#8F4B26"
        case .dusk: return "#D08770"
        case .ink: return "#B3552F"
        }
    }

    var isDark: Bool {
        switch self {
        case .paper, .sepia: return false
        case .dusk, .ink: return true
        }
    }

    var background: Color { Color(hex: backgroundHex) }
    var text: Color { Color(hex: textHex) }
    var secondaryText: Color { Color(hex: secondaryTextHex) }
    var accent: Color { Color(hex: accentHex) }
}

enum ReaderFont: String, Codable, CaseIterable, Identifiable {
    case newYork, georgia, palatino, charter, sanFrancisco

    var id: String { rawValue }

    var label: String {
        switch self {
        case .newYork: return "New York"
        case .georgia: return "Georgia"
        case .palatino: return "Palatino"
        case .charter: return "Charter"
        case .sanFrancisco: return "San Francisco"
        }
    }

    /// CSS font stack injected into the chapter document.
    var cssFamily: String {
        switch self {
        case .newYork: return "ui-serif, 'New York', Georgia, serif"
        case .georgia: return "Georgia, serif"
        case .palatino: return "'Palatino', 'Palatino Linotype', 'Book Antiqua', serif"
        case .charter: return "'Charter', 'Iowan Old Style', Georgia, serif"
        case .sanFrancisco: return "-apple-system, ui-sans-serif, 'Helvetica Neue', sans-serif"
        }
    }

    /// SwiftUI preview font for the typography panel.
    var previewFont: Font {
        switch self {
        case .newYork: return .system(.body, design: .serif)
        case .sanFrancisco: return .system(.body)
        case .georgia: return .custom("Georgia", size: 17)
        case .palatino: return .custom("Palatino", size: 17)
        case .charter: return .custom("Charter", size: 17)
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
        case .paged: return "Pages"
        case .scroll: return "Scroll"
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
    case slide, fade, instant

    var id: String { rawValue }

    var label: String {
        switch self {
        case .slide: return "Slide"
        case .fade: return "Fade"
        case .instant: return "None"
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
    let isDark: Bool

    var background: Color { Color(hex: backgroundHex) }
    var text: Color { Color(hex: textHex) }
    var secondaryText: Color { Color(hex: secondaryTextHex) }
    var accent: Color { Color(hex: accentHex) }
}

struct ReaderSettings: Codable, Equatable {
    var theme: ReaderTheme = .paper
    /// Theme used in system mode when the device is in dark appearance.
    var darkTheme: ReaderTheme = .dusk
    var themeMode: ThemeMode = .manual
    /// 0 = neutral page, 1 = strongest amber shift (blue light cut).
    var warmth: Double = 0
    var pageFlow: PageFlow = .paged
    var pageTransition: PageTransition = .slide
    var font: ReaderFont = .newYork
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
        pageTransition = try container.decodeIfPresent(
            PageTransition.self, forKey: .pageTransition
        ) ?? defaults.pageTransition
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
