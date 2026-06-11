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

struct ReaderSettings: Codable, Equatable {
    var theme: ReaderTheme = .paper
    var font: ReaderFont = .newYork
    var fontSize: Double = 18
    var lineHeight: Double = 1.55
    var horizontalMargin: Double = 26
    var isJustified: Bool = true

    static let fontSizeRange: ClosedRange<Double> = 13...26
    static let lineHeightRange: ClosedRange<Double> = 1.25...2.1
    static let marginRange: ClosedRange<Double> = 14...48
}
