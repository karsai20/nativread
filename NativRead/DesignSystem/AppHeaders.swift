import SwiftUI

/// Screen and sheet headers for the app shell.

// MARK: - Large title

/// The iOS large-title pattern in the app's own type: a heavy sans headline,
/// an optional grey subtitle line, and an optional trailing action that sits
/// on the headline's baseline.
struct AppLargeTitleHeader<Action: View>: View {
    let title: LocalizedStringKey
    var subtitle: String? = nil
    let palette: BrandPalette
    @ViewBuilder var action: Action

    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 34

    var body: some View {
        HStack(alignment: .bottom, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title)
                    .font(Typography.heading(titleSize))
                    .tracking(Typography.headingTracking(titleSize))
                    .foregroundStyle(palette.text)
                    .accessibilityAddTraits(.isHeader)

                if let subtitle {
                    Text(subtitle)
                        .font(Typography.control(15))
                        .foregroundStyle(palette.secondaryText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            action
        }
    }
}

extension AppLargeTitleHeader where Action == EmptyView {
    init(title: LocalizedStringKey, subtitle: String? = nil, palette: BrandPalette) {
        self.init(title: title, subtitle: subtitle, palette: palette, action: { EmptyView() })
    }
}

// MARK: - Section eyebrow

/// Small uppercase label that paces a scroll view into named regions.
struct AppSectionLabel: View {
    let title: LocalizedStringKey
    let palette: BrandPalette

    var body: some View {
        Text(title)
            .font(Typography.eyebrow)
            .tracking(Typography.eyebrowTracking)
            .textCase(.uppercase)
            .foregroundStyle(palette.secondaryText)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Sheet chrome

/// Grab handle, heavy title and a Done affordance — the shared top of every
/// presented sheet, so they stop drifting apart one sheet at a time.
struct AppSheetHeader: View {
    let title: LocalizedStringKey
    var onDone: (() -> Void)? = nil
    let palette: BrandPalette

    @ScaledMetric(relativeTo: .title2) private var titleSize: CGFloat = 24

    var body: some View {
        VStack(spacing: Spacing.sm) {
            Capsule(style: .continuous)
                .fill(palette.hairline)
                .frame(width: 36, height: 5)

            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(Typography.heading(titleSize, relativeTo: .title2))
                    .tracking(Typography.headingTracking(titleSize))
                    .foregroundStyle(palette.text)
                    .accessibilityAddTraits(.isHeader)

                Spacer(minLength: Spacing.sm)

                if let onDone {
                    Button("Done", action: onDone)
                        .font(Typography.control(16, weight: .semibold))
                        .foregroundStyle(palette.accent)
                }
            }
        }
        .padding(.top, Spacing.xs)
    }
}
