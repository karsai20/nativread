import SwiftUI

/// What the reader is buying on the translation sheet: the free sample, or the
/// whole book. Both are always on screen — the sheet's single primary button
/// follows whichever one is selected.
enum TranslationPlan: Hashable {
    case freeChapter
    case wholeBook
}

/// One selectable plan on the translation sheet. Reads as a store row: a radio
/// mark, what you get, and what it costs on the trailing edge.
struct TranslationPlanCard: View {
    let plan: TranslationPlan
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    /// Already-localized: a StoreKit price is formatted by StoreKit, never by us.
    let badge: String
    var isRecommended: Bool = false
    let isSelected: Bool
    var isEnabled: Bool = true
    let palette: BrandPalette
    let action: () -> Void

    private var borderColor: Color {
        isSelected ? palette.accent : palette.hairline
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: Spacing.sm) {
                Image(
                    systemName: isSelected
                        ? "checkmark.circle.fill" : "circle"
                )
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(isSelected ? palette.accent : palette.tertiaryText)

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    HStack(spacing: Spacing.xs) {
                        Text(title)
                            .font(Typography.control(17, weight: .semibold))
                            .foregroundStyle(palette.text)

                        if isRecommended {
                            AppPill(
                                title: String(localized: "Best value"),
                                tone: .accent,
                                palette: palette
                            )
                        }
                    }

                    Text(subtitle)
                        .font(Typography.meta())
                        .foregroundStyle(palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(verbatim: badge)
                    .font(Typography.control(16, weight: .bold))
                    .foregroundStyle(isSelected ? palette.accent : palette.text)
                    .lineLimit(1)
                    .layoutPriority(1)
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? palette.accentSoft : palette.surface)
            .clipShape(
                RoundedRectangle(cornerRadius: Spacing.radiusCard, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: Spacing.radiusCard, style: .continuous)
                    .strokeBorder(
                        borderColor,
                        lineWidth: isSelected ? 2 : Spacing.hairlineWidth
                    )
            }
        }
        .buttonStyle(PressScaleButtonStyle())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.5)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
