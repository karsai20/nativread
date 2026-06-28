import SwiftUI

/// First-run language picker shown immediately after the brand splash. The
/// editorial `BrandPalette` and Cormorant display typography deliberately
/// match `LaunchView` so the two screens feel like one continuous moment.
///
/// Four concrete languages are offered as **endonyms** — each language's own
/// name in its own script — so every user can recognise their language
/// regardless of the current device locale. No flags are used (per UX
/// research: flags conflate language with nationality).
///
/// The device locale is used to pre-select the best match; if the device
/// language is not in the supported set, English is pre-selected.
struct LanguageSelectionView: View {

    /// Called when the user taps Continue, passing the confirmed choice.
    var onConfirmed: (AppLanguage) -> Void

    @Environment(LocalizationStore.self) private var localizationStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    /// The chrome palette resolved against the system appearance.
    private var palette: BrandPalette {
        BrandPalette.resolve(systemDark: colorScheme == .dark)
    }

    // MARK: - State

    @State private var headingShown = false
    @State private var optionsShown = false
    @State private var buttonShown  = false

    /// The currently highlighted language; defaults to the device's best
    /// match so the user can just tap Continue if it's already correct. Clamped
    /// to `pickable` so a device language that's recognised but not yet offered
    /// (e.g. Spanish/German) falls back to English instead of pre-selecting an
    /// invisible row.
    @State private var selected: AppLanguage = {
        let match = AppLanguage.matchingDevice()
        return AppLanguage.pickable.contains(match) ? match : .en
    }()

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background: the same subtle paper lift as the splash.
            LinearGradient(
                colors: [palette.background, palette.surface],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // ── Heading ──────────────────────────────────────────────
                VStack(spacing: 10) {
                    Text(
                        localizationStore.localizedString(
                            "onboarding.language.eyebrow",
                            value: "Language"
                        )
                    )
                    .font(Typography.eyebrow)
                    .tracking(Typography.eyebrowTracking)
                    .textCase(.uppercase)
                    .foregroundStyle(palette.accent)

                    Text(
                        localizationStore.localizedString(
                            "onboarding.language.title",
                            value: "Choose your language"
                        )
                    )
                    .font(Typography.display(30))
                    .foregroundStyle(palette.text)
                    .multilineTextAlignment(.center)

                    Text(
                        localizationStore.localizedString(
                            "onboarding.language.subtitle",
                            value: "You can change this at any time in Settings."
                        )
                    )
                    .font(Typography.display(18))
                    .italic()
                    .tracking(0.3)
                    .foregroundStyle(palette.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                }
                .opacity(headingShown ? 1 : 0)
                .offset(y: headingShown ? 0 : 12)

                Spacer().frame(height: 48)

                // ── Language options ──────────────────────────────────────
                VStack(spacing: 12) {
                    ForEach(AppLanguage.pickable, id: \.rawValue) { language in
                        LanguageRow(
                            language: language,
                            isSelected: selected == language,
                            palette: palette
                        )
                        .onTapGesture { selected = language }
                        .accessibilityIdentifier(
                            "onboarding.language.\(language.rawValue)"
                        )
                        .accessibilityLabel(language.endonym)
                        .accessibilityAddTraits(
                            selected == language ? [.isSelected] : []
                        )
                    }
                }
                .accessibilityLabel(
                    localizationStore.localizedString(
                        "onboarding.language.accessibility.picker",
                        value: "Language selection"
                    )
                )
                .opacity(optionsShown ? 1 : 0)
                .offset(y: optionsShown ? 0 : 10)

                Spacer().frame(height: 52)

                // ── Continue button ───────────────────────────────────────
                Button {
                    onConfirmed(selected)
                } label: {
                    Text(
                        localizationStore.localizedString(
                            "onboarding.language.continue",
                            value: "Continue"
                        )
                    )
                    .font(Typography.eyebrow)
                    .tracking(2.5)
                    .textCase(.uppercase)
                    .foregroundStyle(palette.background)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 15)
                    .background(palette.accent)
                    .clipShape(Capsule())
                }
                .accessibilityIdentifier("onboarding.language.continue")
                .opacity(buttonShown ? 1 : 0)
                .offset(y: buttonShown ? 0 : 8)
                .scaleEffect(buttonShown ? 1 : 0.96)

                Spacer()
            }
            .padding(.horizontal, 28)
        }
        .onAppear { reveal() }
    }

    // MARK: - Reveal animation (mirrors LaunchView.reveal())

    private func reveal() {
        guard !reduceMotion else {
            headingShown = true
            optionsShown = true
            buttonShown  = true
            return
        }
        withAnimation(.easeOut(duration: 0.6)) {
            headingShown = true
        }
        withAnimation(.easeOut(duration: 0.6).delay(0.25)) {
            optionsShown = true
        }
        withAnimation(.easeOut(duration: 0.5).delay(0.50)) {
            buttonShown = true
        }
    }
}

// MARK: - Language row

/// A single tappable row in the language picker, styled to the editorial
/// palette. The selected row warms to a russet tint with a hairline ring.
private struct LanguageRow: View {
    let language: AppLanguage
    let isSelected: Bool
    let palette: BrandPalette

    var body: some View {
        HStack {
            Text(language.endonym)
                .font(Typography.display(22))
                .fontWeight(isSelected ? .semibold : .regular)
                .tracking(0.3)
                .foregroundStyle(
                    isSelected ? palette.accent : palette.text
                )
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(palette.accent)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: Spacing.radiusSmall, style: .continuous)
                .fill(
                    isSelected
                        ? palette.accent.opacity(0.12)
                        : palette.surface
                )
                .overlay {
                    RoundedRectangle(cornerRadius: Spacing.radiusSmall, style: .continuous)
                        .strokeBorder(
                            isSelected
                                ? palette.accent.opacity(0.55)
                                : palette.hairline,
                            lineWidth: isSelected ? 1.2 : 0.8
                        )
                }
        }
        .animation(.easeOut(duration: 0.18), value: isSelected)
    }
}
