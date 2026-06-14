import SwiftUI

/// Shared visual language for reader controls: one corner radius, one tap
/// target, one spacing rhythm, and accent reserved for the selected state.
enum ReaderControlStyle {
    static let cornerRadius: CGFloat = 10
    static let cardCornerRadius: CGFloat = 14
    static let minTapTarget: CGFloat = 44
    static let rowSpacing: CGFloat = 8
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
    }

    /// Raised card for the top "live" group: surfaceRaised fill, hairline
    /// stroke, subtle per-theme shadow — intentional depth, no re-theming.
    func panelCard(palette: ReaderPalette) -> some View {
        padding(14)
        .background(
            RoundedRectangle(cornerRadius: ReaderControlStyle.cardCornerRadius)
                .fill(palette.surfaceRaised))
        .overlay(
            RoundedRectangle(cornerRadius: ReaderControlStyle.cardCornerRadius)
                .strokeBorder(palette.hairline))
        .shadow(color: .black.opacity(palette.shadowOpacity), radius: 12, y: 4)
    }
}
