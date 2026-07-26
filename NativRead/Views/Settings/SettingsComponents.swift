import SwiftUI

/// Building blocks for the editorial Settings restyle: page-like appearance
/// tiles, a grouped surface card with hairline row separators, and the choice
/// row that lives inside it. All colours/fonts/spacing come from the
/// DesignSystem tokens (`BrandPalette`, `Typography`, `Spacing`).

// MARK: - Grouped surface card

extension View {
    /// Wraps a stack of rows in one surface with a hairline border, echoing the
    /// library cards. Clips to the card radius so a selected row's accent
    /// wash respects the rounded corners instead of bleeding past them.
    func settingsGroupedCard(palette: BrandPalette) -> some View {
        self
            .background(palette.surface)
            .clipShape(
                RoundedRectangle(cornerRadius: Spacing.radiusCard, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Spacing.radiusCard, style: .continuous)
                    .strokeBorder(palette.hairline, lineWidth: Spacing.hairlineWidth)
            )
    }
}

/// Inset hairline between two rows in a grouped card — leading inset aligns it
/// under the row text, the way native grouped lists inset their separators.
struct SettingsRowDivider: View {
    let palette: BrandPalette

    var body: some View {
        Rectangle()
            .fill(palette.hairline)
            .frame(height: Spacing.hairlineWidth)
            .padding(.leading, Spacing.md)
    }
}

// MARK: - Choice row (inside a grouped card)

/// A single tappable option in a Settings picker. Unlike the old floating
/// cards, this row has no border of its own — the enclosing `settingsGroupedCard`
/// supplies the surface and hairlines. Selected rows warm to a subtle accent
/// wash with a semibold accent title and trailing checkmark.
struct SettingsGroupedRow: View {
    let title: String
    var subtitle: String? = nil
    let isSelected: Bool
    let palette: BrandPalette

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title)
                    .font(Typography.control(17, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? palette.accent : palette.text)
                if let subtitle {
                    Text(subtitle)
                        .font(Typography.meta())
                        .foregroundStyle(palette.secondaryText)
                }
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(palette.accent)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? palette.accent.opacity(0.10) : Color.clear)
        // Whole row (including the wash and trailing gap) stays tappable.
        .contentShape(Rectangle())
        .animation(.easeOut(duration: 0.18), value: isSelected)
    }
}

// MARK: - Appearance tile

/// The bottom-right half of a rect — used to paint the "dark" side of the
/// System tile as a diagonal split over the light page.
struct DiagonalSplitShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// A page-like swatch for the Light / Dark / System appearance choice, echoing
/// the reader's `ThemeTile`: a mini "page" showing the mode's real paper/ink
/// with an "Aa" specimen, a label underneath, and an accent ring + lift when
/// selected. System shows a diagonal split of the two pages. Applied instantly
/// on tap (the mode change is its own feedback).
struct AppearanceTile: View {
    let appearance: AppAppearance
    let label: String
    let isSelected: Bool
    let palette: BrandPalette
    let action: () -> Void

    // Real chrome palettes so the previews are faithful, not approximated.
    private var lightBg: Color { BrandPalette.light.background }
    private var lightInk: Color { BrandPalette.light.text }
    private var darkBg: Color { BrandPalette.dark.background }
    private var darkInk: Color { BrandPalette.dark.text }

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.xs) {
                preview
                    .frame(height: 72)
                    .frame(maxWidth: .infinity)
                    .clipShape(
                        RoundedRectangle(cornerRadius: Spacing.radiusSmall, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Spacing.radiusSmall, style: .continuous)
                            .strokeBorder(
                                isSelected ? palette.accent : palette.hairline,
                                lineWidth: isSelected ? 2.5 : 1
                            )
                    )
                    .shadow(
                        color: .black.opacity(isSelected ? palette.shadowOpacity : 0),
                        radius: 5, y: 2
                    )

                Text(label)
                    .font(Typography.control(14, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? palette.accent : palette.secondaryText)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var preview: some View {
        switch appearance {
        case .light:
            page(background: lightBg, ink: lightInk)
        case .dark:
            page(background: darkBg, ink: darkInk)
        case .system:
            ZStack {
                lightBg
                darkBg.clipShape(DiagonalSplitShape())
                // Accent glyph reads on both the paper and the charcoal half.
                specimen(ink: palette.accent)
            }
        }
    }

    private func page(background: Color, ink: Color) -> some View {
        ZStack {
            background
            specimen(ink: ink)
        }
    }

    private func specimen(ink: Color) -> some View {
        Text("Aa")
            .font(.custom(Typography.displayFamily, size: 26))
            .foregroundStyle(ink)
    }
}
