import SwiftUI

/// The one Settings control the redesign's `AppSettingsSection` /
/// `AppSettingsRow` primitives do not cover: the page-like appearance tiles.
/// Everything else that used to live here moved to `DesignSystem/AppRows.swift`.

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
