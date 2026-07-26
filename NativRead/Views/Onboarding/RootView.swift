import SwiftUI
import StoreKit

/// App root: shows the library and, on first launch, a language-aware welcome
/// followed by a three-step animated explanation of the core workflow.
struct RootView: View {
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(LocalizationStore.self) private var localizationStore
    @Environment(LibraryStore.self) private var library
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.requestReview) private var requestReview

    @State private var onboardingStep: OnboardingStep?
    @State private var movingForward = true

    init(initialShowLaunch: Bool) {
        _onboardingStep = State(
            initialValue: initialShowLaunch ? .welcome : nil
        )
    }

    var body: some View {
        ZStack {
            LibraryView()
                .id(localizationStore.appLanguage)
                .accessibilityHidden(onboardingStep != nil)
                .allowsHitTesting(onboardingStep == nil)

            if let onboardingStep {
                onboardingView(for: onboardingStep)
                    .id(onboardingStep)
                    .transition(stepTransition)
                    .zIndex(1)
            }
        }
        .animation(
            reduceMotion
                ? nil
                : .spring(response: 0.50, dampingFraction: 0.90),
            value: onboardingStep
        )
        .onChange(of: library.reviewPromptRequested) { _, requested in
            guard requested else { return }
            library.reviewPromptRequested = false
            if onboardingStep == nil {
                requestReview()
            }
        }
    }

    @ViewBuilder
    private func onboardingView(for step: OnboardingStep) -> some View {
        switch step {
        case .welcome:
            LaunchView(onFinished: languageDidConfirm)
        case .tour:
            OnboardingWalkthroughView(
                onBack: { move(to: .welcome, forward: false) },
                onFinished: finishOnboarding
            )
        }
    }

    private var stepTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .move(edge: movingForward ? .trailing : .leading)
                .combined(with: .opacity),
            removal: .move(edge: movingForward ? .leading : .trailing)
                .combined(with: .opacity)
        )
    }

    private func languageDidConfirm(_ language: AppLanguage) {
        localizationStore.setLanguage(language)
        move(to: .tour)
    }

    private func finishOnboarding() {
        settingsStore.markOnboardingSeen()
        movingForward = true
        onboardingStep = nil
    }

    private func move(to step: OnboardingStep, forward: Bool = true) {
        movingForward = forward
        onboardingStep = step
    }
}

private enum OnboardingStep: Int, Hashable {
    case welcome
    case tour
}
