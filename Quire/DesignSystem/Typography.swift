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
    /// Grand editorial headline — covers, chapter titles, pull-quotes.
    /// Cormorant Garamond's high contrast makes it feel typeset, not digital.
    static func display(_ size: CGFloat = 34) -> Font {
        .custom("Cormorant Garamond", size: size)
    }

    /// Section or card title — a readable literary serif that bridges
    /// display and body without dropping to system defaults.
    static func title(_ size: CGFloat = 20) -> Font {
        .custom("Crimson Pro", size: size)
    }

    /// Primary content copy — Crimson Pro at reading sizes. Matches the
    /// reader's default font so the library and reader feel like one app.
    static func body(_ size: CGFloat = 17) -> Font {
        .custom("Crimson Pro", size: size)
    }

    /// Uppercase category label — tight tracking signals "label, not prose".
    /// Apply `.tracking(Typography.eyebrowTracking)` and `.textCase(.uppercase)` alongside this font.
    static var eyebrow: Font {
        .system(size: eyebrowSize, weight: .semibold)
    }

    /// Tracking to pair with `eyebrow`. Spaced out to reinforce the label role.
    static let eyebrowTracking: CGFloat = 1.6

    /// Canonical point size for eyebrow labels.
    static let eyebrowSize: CGFloat = 12

    /// Timestamps, byte counts, and supplementary captions.
    /// Plain SF at small sizes stays legible without competing with serif copy.
    static func meta(_ size: CGFloat = 13) -> Font {
        .system(size: size, weight: .regular)
    }
}
