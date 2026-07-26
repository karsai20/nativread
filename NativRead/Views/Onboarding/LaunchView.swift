import SwiftUI

/// A user-paced welcome screen. The old timed splash disappeared before a
/// slower reader could absorb it; this version waits for an explicit action
/// and uses a calm animated book to preview the app's core promise.
struct LaunchView: View {
    var onFinished: (AppLanguage) -> Void

    @Environment(LocalizationStore.self) private var localizationStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var visualShown = false
    @State private var copyShown = false
    @State private var buttonShown = false

    private var palette: BrandPalette {
        BrandPalette.resolve(systemDark: colorScheme == .dark)
    }

    /// First launch follows the iPhone language automatically. The two
    /// endonym buttons remain visible so the suggestion is always explicit
    /// and can be changed before the user reads any instructions.
    private var selectedLanguage: AppLanguage {
        if AppLanguage.pickable.contains(localizationStore.appLanguage) {
            return localizationStore.appLanguage
        }
        let deviceLanguage = AppLanguage.matchingDevice()
        return AppLanguage.pickable.contains(deviceLanguage)
            ? deviceLanguage
            : .en
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                OnboardingPaperBackground(palette: palette)

                ScrollView(showsIndicators: false) {
                    Group {
                        if proxy.size.width > proxy.size.height {
                            landscapeContent
                        } else {
                            portraitContent
                        }
                    }
                    .frame(
                        minHeight: max(0, proxy.size.height - 116),
                        alignment: .center
                    )
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.lg)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            welcomeAction
        }
        .onAppear { reveal() }
    }

    private var portraitContent: some View {
        VStack(spacing: dynamicTypeSize.isAccessibilitySize ? Spacing.md : Spacing.lg) {
            brandMark
            languagePicker

            WelcomeBookScene(palette: palette, isAnimated: !reduceMotion)
                .frame(maxWidth: 360)
                .frame(height: 260)
                .scaleEffect(dynamicTypeSize.isAccessibilitySize ? 0.68 : 0.80)
                .frame(height: dynamicTypeSize.isAccessibilitySize ? 190 : 205)
                .opacity(visualShown ? 1 : 0)
                .scaleEffect(visualShown ? 1 : 0.94)
                .accessibilityHidden(true)

            welcomeCopy
        }
    }

    private var landscapeContent: some View {
        HStack(spacing: Spacing.xl) {
            WelcomeBookScene(palette: palette, isAnimated: !reduceMotion)
                .frame(width: min(330, UIScreen.main.bounds.width * 0.42))
                .frame(height: 230)
                .opacity(visualShown ? 1 : 0)
                .scaleEffect(visualShown ? 1 : 0.94)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.lg) {
                brandMark
                languagePicker
                welcomeCopy
            }
            .frame(maxWidth: 430, alignment: .leading)
        }
    }

    private var brandMark: some View {
        HStack(spacing: Spacing.xs) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(palette.accent)
                .frame(width: 4, height: 28)

            Text("NativRead")
                .font(Typography.display(
                    dynamicTypeSize.isAccessibilitySize ? 22 : 28
                ))
                .dynamicTypeSize(...DynamicTypeSize.xxLarge)
                .tracking(0.4)
                .foregroundStyle(palette.text)
                .accessibilityLabel("NativRead")
                .accessibilityIdentifier("onboarding.wordmark")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(copyShown ? 1 : 0)
        .offset(y: copyShown ? 0 : 8)
    }

    private var welcomeCopy: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Welcome")
                .font(Typography.eyebrow)
                .tracking(Typography.eyebrowTracking)
                .textCase(.uppercase)
                .foregroundStyle(palette.accent)

            Text("Your books, now in your language.")
                .font(Typography.display(42))
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                .foregroundStyle(palette.text)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("onboarding.welcome.title")

            Text("Bring a book you already have. NativRead can translate it, then gives you a calm and comfortable place to read.")
                .font(Typography.body(20))
                .foregroundStyle(palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Spacing.xxs)

            if dynamicTypeSize.isAccessibilitySize {
                Label(
                    "No complicated setup. We will guide you step by step.",
                    systemImage: "checkmark.circle"
                )
                .font(Typography.control(15, weight: .medium))
                .foregroundStyle(palette.accent)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Spacing.sm)
            }
        }
        .frame(maxWidth: 540, alignment: .leading)
        .opacity(copyShown ? 1 : 0)
        .offset(y: copyShown ? 0 : 10)
    }

    private var languagePicker: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "globe")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(palette.accent)
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)

            ForEach(AppLanguage.pickable, id: \.rawValue) { language in
                languageButton(language)
            }
        }
        .padding(Spacing.xs)
        .background {
            RoundedRectangle(
                cornerRadius: Spacing.radiusCard,
                style: .continuous
            )
            .fill(palette.surface.opacity(0.88))
            .overlay {
                RoundedRectangle(
                    cornerRadius: Spacing.radiusCard,
                    style: .continuous
                )
                .strokeBorder(palette.hairline)
            }
        }
        .frame(maxWidth: 540)
        .opacity(copyShown ? 1 : 0)
        .offset(y: copyShown ? 0 : 8)
    }

    private func languageButton(_ language: AppLanguage) -> some View {
        let isSelected = selectedLanguage == language
        return Button {
            withAnimation(
                reduceMotion
                    ? nil
                    : .spring(response: 0.34, dampingFraction: 0.82)
            ) {
                localizationStore.setLanguage(language)
            }
        } label: {
            HStack(spacing: Spacing.xs) {
                Text(language.endonym)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                }
            }
            .font(Typography.control(16, weight: .semibold))
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            .foregroundStyle(isSelected ? palette.background : palette.text)
            .padding(.horizontal, Spacing.xs)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(isSelected ? palette.accent : palette.surfaceRaised)
            .clipShape(RoundedRectangle(
                cornerRadius: Spacing.radiusSmall,
                style: .continuous
            ))
            .overlay {
                if !isSelected {
                    RoundedRectangle(
                        cornerRadius: Spacing.radiusSmall,
                        style: .continuous
                    )
                    .strokeBorder(palette.hairline)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(
            "onboarding.welcome.language.\(language.rawValue)"
        )
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var welcomeAction: some View {
        VStack(spacing: Spacing.sm) {
            Button { onFinished(selectedLanguage) } label: {
                HStack(spacing: Spacing.sm) {
                    Text("Show me how it works")
                    Image(systemName: "arrow.right")
                }
                .font(Typography.control(18, weight: .semibold))
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                .foregroundStyle(palette.background)
                .frame(maxWidth: .infinity, minHeight: 58)
                .background(palette.accent)
                .clipShape(RoundedRectangle(
                    cornerRadius: Spacing.radiusCard,
                    style: .continuous
                ))
            }
            .accessibilityIdentifier("onboarding.welcome.start")

            if !dynamicTypeSize.isAccessibilitySize {
                Text("No complicated setup. We will guide you step by step.")
                    .font(Typography.control(15))
                    .foregroundStyle(palette.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.sm)
        .background(
            LinearGradient(
                colors: [palette.background.opacity(0), palette.background],
                startPoint: .top,
                endPoint: .center
            )
        )
        .opacity(buttonShown ? 1 : 0)
        .offset(y: buttonShown ? 0 : 10)
    }

    private func reveal() {
        guard !reduceMotion else {
            visualShown = true
            copyShown = true
            buttonShown = true
            return
        }

        withAnimation(.spring(response: 0.72, dampingFraction: 0.82)) {
            visualShown = true
        }
        withAnimation(.easeOut(duration: 0.6).delay(0.16)) {
            copyShown = true
        }
        withAnimation(.easeOut(duration: 0.5).delay(0.38)) {
            buttonShown = true
        }
    }
}

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
private struct WelcomeBookScene: View {
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
