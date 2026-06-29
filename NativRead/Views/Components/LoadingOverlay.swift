import SwiftUI

/// A centred "card over a dimmed backdrop" loading indicator, themed by
/// whichever palette owns the surface behind it — the reader's reading
/// palette or the library's brand palette. Used for blocking async work
/// such as book import where the result must land before the user continues.
struct LoadingOverlay: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let palette: any PaletteColors
    let message: String

    var body: some View {
        ZStack {
            // Dim the shelf behind without fully hiding it.
            palette.background
                .opacity(0.45)
                .ignoresSafeArea()

            VStack(spacing: Spacing.md) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(palette.accent)
                    // Reduce Motion: ProgressView spin is system-managed,
                    // but we avoid any extra animation of our own.
                    .scaleEffect(reduceMotion ? 1.0 : 1.1)

                Text(LocalizedStringKey(message))
                    .font(Typography.body())
                    .foregroundStyle(palette.text)
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: Spacing.radiusSheet, style: .continuous)
                    .fill(palette.surfaceRaised)
                    .shadow(
                        color: .black.opacity(0.18),
                        radius: Spacing.radiusSheet, y: Spacing.xs
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: Spacing.radiusSheet, style: .continuous)
                    .strokeBorder(palette.hairline, lineWidth: Spacing.hairlineWidth)
            )
        }
        .transition(.opacity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
    }
}
