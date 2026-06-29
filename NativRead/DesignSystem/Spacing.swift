import CoreGraphics

/// App-wide spacing scale, corner radii, and touch-target constants.
///
/// The scale is a geometric step sequence — each value roughly doubles the
/// previous one — so layouts built with two adjacent steps feel harmonious
/// while layouts with values far apart create intentional contrast.
///
/// These constants generalise the values that currently live in
/// `ReaderControlStyle` (cornerRadius 10, cardCornerRadius 14, minTapTarget
/// 44, rowSpacing 8) so later design-system phases can unify both layers
/// without changing existing reader views.
enum Spacing {

    // MARK: — Spacing scale

    /// 4 pt — icon-to-label gap, inline badge padding.
    static let xxs: CGFloat = 4
    /// 8 pt — list row spacing, tight inline gaps.
    static let xs: CGFloat = 8
    /// 12 pt — intra-group padding, compact sections.
    static let sm: CGFloat = 12
    /// 16 pt — standard content padding, card insets.
    static let md: CGFloat = 16
    /// 24 pt — section spacing, card-to-card gap.
    static let lg: CGFloat = 24
    /// 32 pt — large section gaps, hero padding.
    static let xl: CGFloat = 32
    /// 48 pt — screen-level vertical breathing room.
    static let xxl: CGFloat = 48

    // MARK: — Corner radii

    /// 10 pt — small controls: segmented wells, icon buttons.
    /// Matches `ReaderControlStyle.cornerRadius`.
    static let radiusSmall: CGFloat = 10
    /// 14 pt — cards and elevated panels.
    /// Matches `ReaderControlStyle.cardCornerRadius`.
    static let radiusCard: CGFloat = 14
    /// 18 pt — bottom sheets and modal containers.
    static let radiusSheet: CGFloat = 18

    // MARK: — Touch targets & strokes

    /// 44 pt — minimum interactive size per HIG.
    /// Matches `ReaderControlStyle.minTapTarget`.
    static let minTapTarget: CGFloat = 44
    /// 1 pt — hairline dividers and strokes (physical pixel on 1× screens).
    static let hairlineWidth: CGFloat = 1
}
