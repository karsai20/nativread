import SwiftUI

/// A welcome and three short, animated lessons that explain the app's complete
/// core loop. Progress is always explicit and user-controlled; nothing advances
/// on a timer, which keeps the flow comfortable for older and first-time users.
///
/// The app language is not asked for here — it follows the phone, and Settings
/// can override it later.
struct OnboardingWalkthroughView: View {
    var onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var page: OnboardingTourPage = .welcome
    @State private var movingForward = true

    private var palette: BrandPalette {
        BrandPalette.resolve(systemDark: colorScheme == .dark)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                OnboardingPaperBackground(palette: palette)

                ScrollView(showsIndicators: false) {
                    Group {
                        if proxy.size.width > proxy.size.height {
                            HStack(alignment: .center, spacing: Spacing.xxl) {
                                illustration
                                    .frame(maxWidth: 390)
                                pageCopy
                                    .frame(maxWidth: 460, alignment: .leading)
                            }
                        } else {
                            VStack(
                                alignment: .leading,
                                spacing: dynamicTypeSize.isAccessibilitySize
                                    ? Spacing.md
                                    : Spacing.xl
                            ) {
                                illustration
                                    .frame(maxWidth: 410)
                                    .frame(maxWidth: .infinity)
                                pageCopy
                            }
                        }
                    }
                    .id(page)
                    .transition(pageTransition)
                    // Reserve the real bottom bar (action + back/note + padding)
                    // so the last copy line never centres itself underneath it.
                    .frame(
                        minHeight: max(0, proxy.size.height - 176),
                        alignment: .center
                    )
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.lg)
                }
                .animation(
                    reduceMotion
                        ? nil
                        : .spring(response: 0.48, dampingFraction: 0.88),
                    value: page
                )
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) { topBar }
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
    }

    /// A progress rail rather than a step counter: four short bars fill up as
    /// the reader moves, and Skip stays available but visually secondary.
    private var topBar: some View {
        HStack(spacing: Spacing.md) {
            HStack(spacing: 6) {
                ForEach(OnboardingTourPage.allCases, id: \.rawValue) { item in
                    Capsule()
                        .fill(
                            item.rawValue <= page.rawValue
                                ? palette.accent
                                : palette.hairline
                        )
                        .frame(width: 22, height: 4)
                }
            }
            .accessibilityElement()
            .accessibilityLabel(stepText)
            .accessibilityIdentifier("onboarding.tour.progress")
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.24),
                value: page
            )

            Spacer()

            Button("Skip", action: onFinished)
                .font(Typography.control(15, weight: .semibold))
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                .foregroundStyle(palette.secondaryText)
                .frame(minWidth: 48, minHeight: Spacing.minTapTarget, alignment: .trailing)
                .accessibilityIdentifier("onboarding.tour.skip")
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.xs)
    }

    @ViewBuilder
    private var illustration: some View {
        TourIllustrationShell(palette: palette) {
            switch page {
            case .welcome:
                WelcomeBookScene(palette: palette, isAnimated: !reduceMotion)
            case .addBook:
                AddBookTourAnimation(
                    palette: palette,
                    isAnimated: !reduceMotion
                )
            case .translate:
                TranslateTourAnimation(
                    palette: palette,
                    isAnimated: !reduceMotion
                )
            case .read:
                ReadTourAnimation(
                    palette: palette,
                    isAnimated: !reduceMotion
                )
            }
        }
        .frame(height: dynamicTypeSize.isAccessibilitySize ? 190 : 282)
        .accessibilityHidden(true)
    }

    private var pageCopy: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(page.eyebrow)
                .font(.system(size: Typography.eyebrowSize, weight: .heavy))
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                .tracking(1.05)
                .textCase(.uppercase)
                .foregroundStyle(palette.accent)

            Text(page.title)
                .font(Typography.heading(titleSize))
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                .tracking(-1.3)
                .foregroundStyle(palette.text)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("onboarding.tour.title")

            Text(page.body)
                .font(Typography.control(17))
                .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                .foregroundStyle(palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Spacing.xxs)

            Label(page.reassurance, systemImage: page.reassuranceIcon)
                .font(Typography.control(15, weight: .medium))
                .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                .foregroundStyle(palette.accent)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Spacing.sm)
        }
        .frame(maxWidth: 560, alignment: .leading)
    }

    private var bottomBar: some View {
        VStack(spacing: Spacing.sm) {
            AppPrimaryButton(
                title: nextButtonTitle,
                systemImage: page == .read ? "books.vertical.fill" : "arrow.right",
                action: advance,
                palette: palette
            )
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            .accessibilityIdentifier(
                page == .read
                    ? "onboarding.tour.finish"
                    : "onboarding.tour.next"
            )

            // The first step has nothing to go back to, so the space carries a
            // reassurance instead of a dead control.
            if page == .welcome {
                Text("Your imported books stay on this device.")
                    .font(Typography.meta(12))
                    .foregroundStyle(palette.tertiaryText)
                    .multilineTextAlignment(.center)
                    .frame(minHeight: 42)
            } else {
                Button("Back", action: goBack)
                    .font(Typography.control(15, weight: .semibold))
                    .foregroundStyle(palette.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 42)
                    .accessibilityIdentifier("onboarding.tour.back")
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.sm)
        .background(palette.background)
    }

    private var nextButtonTitle: LocalizedStringKey {
        switch page {
        case .welcome: return "Show me how it works"
        case .read: return "Open my library"
        default: return "Next"
        }
    }

    /// Titles set tighter than the redesign's 37pt on the smallest phones so a
    /// long Hungarian headline still fits above the fold.
    private var titleSize: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 28 : 34
    }

    private var stepText: String {
        String.localizedStringWithFormat(
            String(localized: "Step %lld of %lld"),
            page.rawValue + 1,
            OnboardingTourPage.allCases.count
        )
    }

    private var pageTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .move(edge: movingForward ? .trailing : .leading)
                .combined(with: .opacity),
            removal: .move(edge: movingForward ? .leading : .trailing)
                .combined(with: .opacity)
        )
    }

    private func advance() {
        guard page != .read else {
            onFinished()
            return
        }
        movingForward = true
        if let next = OnboardingTourPage(rawValue: page.rawValue + 1) {
            page = next
        }
    }

    private func goBack() {
        guard page != .welcome else { return }
        movingForward = false
        if let previous = OnboardingTourPage(rawValue: page.rawValue - 1) {
            page = previous
        }
    }
}

private enum OnboardingTourPage: Int, CaseIterable {
    case welcome
    case addBook
    case translate
    case read

    var eyebrow: LocalizedStringKey {
        switch self {
        case .welcome: return "Welcome to NativRead"
        case .addBook: return "First, add a book"
        case .translate: return "Then, translate"
        case .read: return "Finally, enjoy reading"
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .welcome: return "Your books, in your language."
        case .addBook: return "Choose a book from your iPhone"
        case .translate: return "Let NativRead bring it into your language"
        case .read: return "Read in comfort, at your own pace"
        }
    }

    var body: LocalizedStringKey {
        switch self {
        case .welcome:
            return "Bring every book into one calm place, stay in the story, and translate only when you need to."
        case .addBook:
            return "Tap Add a book, then choose the file in the Files app. Your original book is never changed."
        case .translate:
            return "For an eligible EPUB, tap Translate and choose a language. You can close the app while it works; the finished book returns to your shelf automatically."
        case .read:
            return "Make the text larger, choose a gentle theme, and turn pages with a tap or swipe. Hold a word to use Apple's familiar Look Up."
        }
    }

    var reassurance: LocalizedStringKey {
        switch self {
        case .welcome: return "No complicated setup — we walk you through it"
        case .addBook: return "EPUB, PDF, TXT, and supported DRM-free Kindle files"
        case .translate: return "Your progress is kept even if you leave the app"
        case .read: return "Text size and appearance can be changed at any time"
        }
    }

    var reassuranceIcon: String {
        switch self {
        case .welcome: return "hand.wave"
        case .addBook: return "doc.badge.plus"
        case .translate: return "checkmark.icloud"
        case .read: return "textformat.size"
        }
    }
}

private struct TourIllustrationShell<Content: View>: View {
    let palette: BrandPalette
    let content: Content

    init(
        palette: BrandPalette,
        @ViewBuilder content: () -> Content
    ) {
        self.palette = palette
        self.content = content()
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(palette.surface)
                .shadow(
                    color: .black.opacity(palette.shadowOpacity),
                    radius: 22,
                    y: 12
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .strokeBorder(palette.hairline)
                }

            content
                .padding(Spacing.lg)
        }
    }
}

private struct AddBookTourAnimation: View {
    let palette: BrandPalette
    let isAnimated: Bool
    @State private var animate = false

    var body: some View {
        ZStack {
            HStack(alignment: .bottom, spacing: 10) {
                bookSpine(color: palette.accent.opacity(0.45), height: 92)
                bookSpine(color: palette.accent.opacity(0.72), height: 112)
                bookSpine(color: palette.text.opacity(0.18), height: 82)
            }
            .offset(x: -66, y: 48)

            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(palette.surfaceRaised)
                .frame(width: 252, height: 28)
                .overlay(alignment: .top) {
                    Capsule()
                        .fill(palette.hairline)
                        .frame(width: 218, height: 4)
                        .offset(y: -2)
                }
                .offset(y: 104)

            VStack(spacing: 12) {
                Image(systemName: "doc.richtext.fill")
                    .font(.system(size: 42, weight: .regular))
                Text("EPUB")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
            }
            .foregroundStyle(palette.accent)
            .frame(width: 104, height: 126)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(palette.background)
                    .shadow(color: .black.opacity(0.12), radius: 12, y: 7)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(palette.hairline)
                    )
            )
            .offset(
                x: 54,
                y: animate && isAnimated ? 38 : -48
            )
            .scaleEffect(animate && isAnimated ? 0.90 : 1)
        }
        .onAppear {
            guard isAnimated else { return }
            withAnimation(
                .easeInOut(duration: 2.1).repeatForever(autoreverses: true)
            ) {
                animate = true
            }
        }
    }

    private func bookSpine(color: Color, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(color)
            .frame(width: 34, height: height)
            .overlay(alignment: .top) {
                Capsule()
                    .fill(palette.background.opacity(0.65))
                    .frame(width: 20, height: 3)
                    .padding(.top, 12)
            }
    }
}

private struct TranslateTourAnimation: View {
    let palette: BrandPalette
    let isAnimated: Bool
    @State private var animate = false

    var body: some View {
        ZStack {
            miniPage(language: "EN", translated: false)
                .offset(x: -76, y: -4)
                .rotationEffect(.degrees(-3))

            miniPage(language: "HU", translated: true)
                .offset(x: 76, y: 4)
                .rotationEffect(.degrees(3))

            ZStack {
                Circle()
                    .fill(palette.accent)
                    .frame(width: 54, height: 54)
                    .shadow(color: .black.opacity(0.12), radius: 9, y: 4)
                Image(systemName: "sparkles")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(palette.background)
                    .rotationEffect(.degrees(animate && isAnimated ? 8 : -8))
            }
            .scaleEffect(animate && isAnimated ? 1.08 : 0.94)
        }
        .onAppear {
            guard isAnimated else { return }
            withAnimation(
                .easeInOut(duration: 1.7).repeatForever(autoreverses: true)
            ) {
                animate = true
            }
        }
    }

    private func miniPage(language: String, translated: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(language)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                Spacer()
                Image(systemName: translated ? "checkmark.circle.fill" : "text.alignleft")
            }
            .foregroundStyle(translated ? palette.accent : palette.secondaryText)

            ForEach(0..<6, id: \.self) { index in
                Capsule()
                    .fill(
                        translated
                            ? palette.accent.opacity(index < 4 ? 0.48 : 0.22)
                            : palette.text.opacity(0.20)
                    )
                    .frame(width: index == 5 ? 58 : 94, height: 5)
                    .opacity(
                        translated && isAnimated && index < 4
                            ? (animate ? 1 : 0.35)
                            : 1
                    )
            }
        }
        .padding(16)
        .frame(width: 126, height: 174, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(palette.background)
                .shadow(color: .black.opacity(0.10), radius: 10, y: 6)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(palette.hairline)
                )
        )
    }
}

private struct ReadTourAnimation: View {
    let palette: BrandPalette
    let isAnimated: Bool
    @State private var animate = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(palette.background)
                .frame(width: 218, height: 224)
                .shadow(color: .black.opacity(0.12), radius: 16, y: 9)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(palette.hairline)
                )

            VStack(alignment: .leading, spacing: 11) {
                Text("A quiet chapter")
                    .font(.system(size: 18, weight: .semibold, design: .serif))
                    .foregroundStyle(palette.text)

                ForEach(0..<6, id: \.self) { index in
                    Capsule()
                        .fill(palette.text.opacity(index == 2 ? 0.34 : 0.20))
                        .frame(
                            width: index == 5 ? 104 : (index == 2 ? 146 : 162),
                            height: animate && isAnimated ? 6 : 5
                        )
                }

                Spacer()

                HStack {
                    Text("1")
                    Spacer()
                    Image(systemName: "hand.tap")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(palette.secondaryText)
            }
            .padding(22)
            .frame(width: 218, height: 224, alignment: .topLeading)

            HStack(spacing: 5) {
                Text("A")
                    .font(.system(size: 13, weight: .medium))
                Text("A")
                    .font(.system(size: 22, weight: .semibold))
            }
            .foregroundStyle(palette.accent)
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background(
                Capsule()
                    .fill(palette.surfaceRaised)
                    .shadow(color: .black.opacity(0.10), radius: 8, y: 4)
            )
            .overlay(Capsule().strokeBorder(palette.hairline))
            .offset(x: 94, y: -88)
            .scaleEffect(animate && isAnimated ? 1.06 : 0.96)
        }
        .onAppear {
            guard isAnimated else { return }
            withAnimation(
                .easeInOut(duration: 1.8).repeatForever(autoreverses: true)
            ) {
                animate = true
            }
        }
    }
}
