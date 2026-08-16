import SwiftUI
import StoreKit

/// App root: shows the tab shell and, on first launch, the welcome screen.
/// The app language follows the phone, so onboarding never asks for it.
struct RootView: View {
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(LibraryStore.self) private var library
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.requestReview) private var requestReview

    @State private var isOnboarding: Bool
    @State private var tabSelection: AppTabView.Destination = .library

    init(initialShowLaunch: Bool) {
        _isOnboarding = State(initialValue: initialShowLaunch)
    }

    var body: some View {
        ZStack {
            AppTabView(selection: $tabSelection)
                .accessibilityHidden(isOnboarding)
                .allowsHitTesting(!isOnboarding)

            if isOnboarding {
                WelcomeView(onFinished: finishOnboarding)
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
        // Settings can ask for the welcome again; the flow comes straight back
        // over the shelf, no relaunch needed.
        .onChange(of: settingsStore.onboardingReplayCount) { _, _ in
            isOnboarding = true
        }
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
        // "To my shelf" has to mean the shelf even when the welcome was
        // replayed from the Settings tab.
        tabSelection = .library
        isOnboarding = false
    }
}
