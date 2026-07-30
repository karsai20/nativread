import SwiftUI
import StoreKit

/// App root: shows the tab shell and, on first launch, a three-beat walk
/// through the core workflow. The app language follows the phone, so
/// onboarding never asks for it.
struct RootView: View {
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(LibraryStore.self) private var library
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.requestReview) private var requestReview

    @State private var isOnboarding: Bool

    init(initialShowLaunch: Bool) {
        _isOnboarding = State(initialValue: initialShowLaunch)
    }

    var body: some View {
        ZStack {
            AppTabView()
                .accessibilityHidden(isOnboarding)
                .allowsHitTesting(!isOnboarding)

            if isOnboarding {
                OnboardingWalkthroughView(onFinished: finishOnboarding)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .animation(
            reduceMotion
                ? nil
                : .spring(response: 0.50, dampingFraction: 0.90),
            value: isOnboarding
        )
        .onChange(of: library.reviewPromptRequested) { _, requested in
            guard requested else { return }
            library.reviewPromptRequested = false
            if !isOnboarding {
                requestReview()
            }
        }
    }

    private func finishOnboarding() {
        settingsStore.markOnboardingSeen()
        isOnboarding = false
    }
}
