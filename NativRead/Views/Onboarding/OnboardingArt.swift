import SwiftUI


/// Shared warm paper backdrop used by every onboarding step.
struct OnboardingPaperBackground: View {
    let palette: BrandPalette

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [palette.background, palette.surface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(palette.accent.opacity(palette.isDark ? 0.08 : 0.06))
                .frame(width: 320, height: 320)
                .blur(radius: 2)
                .offset(x: 180, y: -300)

            Circle()
                .fill(palette.text.opacity(palette.isDark ? 0.04 : 0.025))
                .frame(width: 260, height: 260)
                .offset(x: -180, y: 340)
        }
        .ignoresSafeArea()
    }
}

/// An open book whose translated page quietly comes alive. The movement is
/// intentionally slow and small: explanatory, not decorative distraction.
/// The animated open-book scene on the welcome step: a source page turning
/// into a translated one.
struct WelcomeBookScene: View {
    let palette: BrandPalette
    let isAnimated: Bool

    @State private var animate = false

    var body: some View {
        ZStack {
            Ellipse()
                .fill(.black.opacity(palette.isDark ? 0.26 : 0.10))
                .frame(width: 278, height: 32)
                .blur(radius: 11)
                .offset(y: 92)

            HStack(spacing: 3) {
                page(isTranslated: false)
                    .rotation3DEffect(
                        .degrees(animate && isAnimated ? 3 : 0),
                        axis: (x: 0, y: 1, z: 0),
                        anchor: .trailing,
                        perspective: 0.4
                    )

                page(isTranslated: true)
                    .rotation3DEffect(
                        .degrees(animate && isAnimated ? -5 : -1),
                        axis: (x: 0, y: 1, z: 0),
                        anchor: .leading,
                        perspective: 0.4
                    )
            }
            .padding(8)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(palette.accent.opacity(0.86))
                    .shadow(
                        color: .black.opacity(palette.shadowOpacity + 0.04),
                        radius: 18,
                        y: 12
                    )
            }
            .rotationEffect(.degrees(animate && isAnimated ? 0.8 : -0.8))
            .offset(y: animate && isAnimated ? -4 : 2)

            languageBridge
                .offset(y: -112)
        }
        .onAppear {
            guard isAnimated else { return }
            withAnimation(
                .easeInOut(duration: 2.5).repeatForever(autoreverses: true)
            ) {
                animate = true
            }
        }
    }

    private func page(isTranslated: Bool) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Image(systemName: isTranslated ? "globe" : "doc.text")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(
                        isTranslated ? palette.accent : palette.secondaryText
                    )
                Spacer()
                Image(systemName: isTranslated ? "sparkles" : "text.alignleft")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(
                        isTranslated ? palette.accent : palette.secondaryText
                    )
            }

            RoundedRectangle(cornerRadius: 2)
                .fill(palette.text.opacity(0.72))
                .frame(width: isTranslated ? 76 : 88, height: 7)

            ForEach(0..<6, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(
                        isTranslated && index < 3
                            ? palette.accent.opacity(0.52)
                            : palette.text.opacity(0.20)
                    )
                    .frame(
                        width: index == 5 ? 64 : (index == 2 ? 91 : 104),
                        height: 4
                    )
                    .opacity(
                        isTranslated && isAnimated
                            ? (animate || index > 2 ? 1 : 0.35)
                            : 1
                    )
            }
            Spacer()
            HStack(spacing: 5) {
                Image(systemName: isTranslated ? "checkmark.circle.fill" : "book.closed.fill")
                    .font(.system(size: 10, weight: .semibold))
                RoundedRectangle(cornerRadius: 1.5)
                    .frame(width: isTranslated ? 58 : 48, height: 4)
            }
            .foregroundStyle(
                isTranslated ? palette.accent : palette.secondaryText
            )
        }
        .padding(15)
        .frame(width: 132, height: 188, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(palette.background)
        )
    }

    private var languageBridge: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "doc.text")
            Image(systemName: "arrow.right")
                .offset(x: animate && isAnimated ? 3 : -2)
            Image(systemName: "globe")
        }
        .font(.system(size: 12, weight: .bold, design: .rounded))
        .foregroundStyle(palette.accent)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(palette.surfaceRaised)
                .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
        )
        .overlay(Capsule().strokeBorder(palette.hairline))
    }
}
