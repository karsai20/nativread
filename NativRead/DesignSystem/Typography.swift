import SwiftUI

/// Editorial type roles for app chrome. Each role maps to a deliberate font
/// choice: Cormorant Garamond anchors the grand display moments, Crimson Pro
/// carries body and title copy, and the system font handles utility text.
///
/// Roles are deliberately thin — callers pick one and pass it to `.font()`.
/// Pairing guidance: display for covers/headings, title for section labels,
/// body for list content, eyebrow for category labels, meta for timestamps
/// and captions.
enum Typography {
    /// Grand editorial headline — wordmark, covers, chapter titles.
    /// Charter is a built-in iOS book serif that renders reliably at every
    /// size (no variable-font registration pitfalls), and its warm, sturdy
    /// letterforms match the reading type the app pairs it with.
    static func display(_ size: CGFloat = 34) -> Font {
        .custom("Charter", size: size, relativeTo: .largeTitle)
    }

    /// Registered family name of the bundled Cormorant Garamond variable font,
    /// kept for the reader's "Cormorant" font option preview.
    static let displayFamily = "Cormorant Garamond Light"

    /// Section or card title — a readable literary serif that bridges
    /// display and body without dropping to system defaults.
    static func title(_ size: CGFloat = 20) -> Font {
        .custom("Crimson Pro", size: size, relativeTo: .title2)
    }

    /// Primary content copy — Crimson Pro at reading sizes. Matches the
    /// reader's default font so the library and reader feel like one app.
    static func body(_ size: CGFloat = 17) -> Font {
        .custom("Crimson Pro", size: size, relativeTo: .body)
    }

    /// Interactive chrome controls — settings rows, language pickers,
    /// onboarding options and buttons. The system font keeps utility UI clean,
    /// modern and consistent, leaving the serif roles for genuine brand and
    /// reading moments. Weight is passed by the caller for selected emphasis.
    static func control(_ size: CGFloat = 17, weight: Font.Weight = .regular) -> Font {
        let style: Font.TextStyle
        switch size {
        case 26...: style = .title
        case 20...: style = .title3
        case ..<14: style = .footnote
        case ..<16: style = .subheadline
        default: style = .body
        }
        return .system(style, design: .default, weight: weight)
    }

    /// Chrome headings — large titles, sheet titles, card headlines. Heavy
    /// system sans with negative tracking: the reading serif stays inside the
    /// reader, while navigation reads as unmistakably native iOS.
    /// Pair with `headingTracking(size)`.
    static func heading(_ size: CGFloat, relativeTo style: Font.TextStyle = .largeTitle) -> Font {
        .system(size: size, weight: .heavy, design: .default).width(.standard)
    }

    /// Optical tracking for `heading` — the bigger the type, the tighter it
    /// sets, matching how the redesign's titles were drawn.
    static func headingTracking(_ size: CGFloat) -> CGFloat {
        switch size {
        case 32...: return -1.1
        case 22...: return -0.4
        default:    return -0.2
        }
    }

    /// Uppercase category label — tight tracking signals "label, not prose".
    /// Apply `.tracking(Typography.eyebrowTracking)` and `.textCase(.uppercase)` alongside this font.
    static var eyebrow: Font {
        .system(.caption, design: .default, weight: .semibold)
    }

    /// Tracking to pair with `eyebrow`. Spaced out to reinforce the label role.
    static let eyebrowTracking: CGFloat = 1.6

    /// Canonical point size for eyebrow labels.
    static let eyebrowSize: CGFloat = 12

    /// Timestamps, byte counts, and supplementary captions.
    /// Plain SF at small sizes stays legible without competing with serif copy.
    static func meta(_ size: CGFloat = 13) -> Font {
        switch size {
        case ..<12:
            return .system(.caption2, design: .default)
        case ..<13:
            return .system(.caption, design: .default)
        default:
            return .system(.footnote, design: .default)
        }
    }
}
