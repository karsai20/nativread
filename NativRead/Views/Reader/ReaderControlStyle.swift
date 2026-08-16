import SwiftUI

/// Shared visual language for reader controls: one corner radius, one tap
/// target, one spacing rhythm, and accent reserved for the selected state.
///
/// Numeric constants now forward to `Spacing` tokens so the reader shares
/// the same shape vocabulary as the library chrome.
enum ReaderControlStyle {
    static let cornerRadius: CGFloat = Spacing.radiusSmall
    static let cardCornerRadius: CGFloat = Spacing.radiusCard
    static let minTapTarget: CGFloat = Spacing.minTapTarget
    static let rowSpacing: CGFloat = Spacing.xs
    static let selectedAccentOpacity: Double = 0.16
}

extension View {
    /// Rounded "well" used by segmented choices (flow / size). Accent only
    /// when selected; otherwise a calm surface + hairline.
    func segmentedWell(isSelected: Bool, palette: ReaderPalette) -> some View {
        background(
            RoundedRectangle(cornerRadius: ReaderControlStyle.cornerRadius)
                .fill(isSelected
                    ? palette.accent.opacity(ReaderControlStyle.selectedAccentOpacity)
                    : palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ReaderControlStyle.cornerRadius)
                .strokeBorder(isSelected ? palette.accent : palette.hairline)
        )
        .foregroundStyle(isSelected ? palette.accent : palette.text)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    /// Capsule pill used by the transition picker.
    func capsulePill(isSelected: Bool, palette: ReaderPalette) -> some View {
        background(
            Capsule().fill(isSelected
                ? palette.accent.opacity(ReaderControlStyle.selectedAccentOpacity)
                : palette.surface))
        .overlay(
            Capsule().strokeBorder(isSelected ? palette.accent : palette.hairline))
        .foregroundStyle(isSelected ? palette.accent : palette.secondaryText)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    /// Raised card for the top "live" group: surfaceRaised fill, hairline
    /// stroke, subtle per-theme shadow — intentional depth, no re-theming.
    func panelCard(palette: ReaderPalette) -> some View {
        padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: ReaderControlStyle.cardCornerRadius)
                .fill(palette.surfaceRaised))
        .overlay(
            RoundedRectangle(cornerRadius: ReaderControlStyle.cardCornerRadius)
                .strokeBorder(palette.hairline))
        .shadow(color: .black.opacity(palette.shadowOpacity), radius: 12, y: 4)
    }
}
