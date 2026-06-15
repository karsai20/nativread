import SwiftUI

/// A centred "card over a dimmed backdrop" loading indicator, themed by
/// the active reader palette. Used for blocking async work such as book
/// import where the result must land before the user continues.
struct LoadingOverlay: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let palette: ReaderPalette
    let message: String

    var body: some View {
        ZStack {
            // Dim the shelf behind without fully hiding it.
            palette.background
                .opacity(0.45)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(palette.accent)
                    // Reduce Motion: ProgressView spin is system-managed,
                    // but we avoid any extra animation of our own.
                    .scaleEffect(reduceMotion ? 1.0 : 1.1)

                Text(message)
                    .font(.system(size: 14, weight: .medium, design: .serif))
                    .foregroundStyle(palette.text)
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 26)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(palette.surfaceRaised)
                    .shadow(
                        color: .black.opacity(0.18),
                        radius: 18, y: 8
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(palette.hairline, lineWidth: 1)
            )
        }
        .transition(.opacity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
    }
}
