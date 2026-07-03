import SwiftUI

/// App-wide settings sheet: appearance and app language. Styled in the same
/// editorial idiom as StatsView and VocabularyView — BrandPalette, eyebrow
/// section labels with hairline rules, Cormorant display typography. Launched
/// from the library header gear button.
struct SettingsView: View {
    @Environment(LocalizationStore.self) private var localizationStore
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    private var palette: BrandPalette {
        BrandPalette.resolve(systemDark: colorScheme == .dark)
    }

    // Staged selections — nil means "unchanged from the store". Tapping a row
    // only stages locally (checkmark moves, app does not switch); the change is
    // committed on Done so the UI never re-localises out from under the user.
    @State private var pendingAppLanguage: AppLanguage?
    @State private var backendURL: String = ""

    private var selectedAppLanguage: AppLanguage {
        pendingAppLanguage ?? localizationStore.appLanguage
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    appearanceSection
                    translationBackendSection
                    appLanguageSection
                }
                .padding(Spacing.lg)
            }
            .background(palette.background.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { applyAndDismiss() }
                        .tint(palette.accent)
                        .accessibilityIdentifier("settings.done")
                }
            }
        }
        .accessibilityIdentifier("settings.sheet")
    }

    // MARK: - Commit

    /// Applies any staged language changes, then dismisses. Tapping rows only
    /// stages; nothing re-localises until Done so the screen never flips
    /// language mid-edit.
    private func applyAndDismiss() {
        if let pendingAppLanguage,
           pendingAppLanguage != localizationStore.appLanguage {
            localizationStore.setLanguage(pendingAppLanguage)
        }
        settingsStore.setTranslationBackendURL(backendURL)
        dismiss()
    }

    // MARK: - Appearance

    /// Light / Dark / System toggle. `System` follows the device — applied
    /// instantly on tap (unlike language) so the change is its own feedback.
    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            sectionLabel("Appearance")

            VStack(spacing: Spacing.xs) {
                ForEach(AppAppearance.allCases, id: \.rawValue) { appearance in
                    SettingsChoiceRow(
                        title: appearanceLabel(appearance),
                        isSelected: settingsStore.appAppearance == appearance,
                        palette: palette
                    )
                    .onTapGesture { settingsStore.setAppearance(appearance) }
                    .accessibilityIdentifier(
                        "settings.appearance.\(appearance.rawValue)"
                    )
                    .accessibilityLabel(appearanceLabel(appearance))
                    .accessibilityAddTraits(
                        settingsStore.appAppearance == appearance
                            ? [.isSelected] : []
                    )
                }
            }
        }
    }

    private func appearanceLabel(_ appearance: AppAppearance) -> String {
        switch appearance {
        case .system:
            return localizationStore.localizedString(
                "settings.appearance.system", value: "System")
        case .light:
            return localizationStore.localizedString(
                "settings.appearance.light", value: "Light")
        case .dark:
            return localizationStore.localizedString(
                "settings.appearance.dark", value: "Dark")
        }
    }

    // MARK: - Translation Backend

    private var translationBackendSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            sectionLabel("Translation Backend")

            VStack(alignment: .leading, spacing: Spacing.xs) {
                TextField("http://192.168.1.205:48218", text: $backendURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .font(Typography.control(16))
                    .foregroundStyle(palette.text)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.md)
                    .background {
                        RoundedRectangle(
                            cornerRadius: Spacing.radiusSmall,
                            style: .continuous
                        )
                        .fill(palette.surface)
                        .overlay {
                            RoundedRectangle(
                                cornerRadius: Spacing.radiusSmall,
                                style: .continuous
                            )
                            .strokeBorder(palette.hairline, lineWidth: 0.8)
                        }
                    }
                    .accessibilityIdentifier("settings.translationBackendURL")

                Text("Defaults to the dedicated NativRead translator backend on your Proxmox LAN.")
                    .font(Typography.meta())
                    .foregroundStyle(palette.secondaryText)
            }
        }
        .onAppear {
            if backendURL.isEmpty {
                backendURL = settingsStore.translationBackendURLString
            }
        }
    }

    // MARK: - App Language

    private var appLanguageSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            sectionLabel("App Language")

            VStack(spacing: Spacing.xs) {
                ForEach(AppLanguage.pickable, id: \.rawValue) { language in
                    SettingsChoiceRow(
                        title: language.endonym,
                        isSelected: selectedAppLanguage == language,
                        palette: palette
                    )
                    .onTapGesture { pendingAppLanguage = language }
                    .accessibilityIdentifier(
                        "settings.applang.\(language.rawValue)"
                    )
                    .accessibilityLabel(language.endonym)
                    .accessibilityAddTraits(
                        selectedAppLanguage == language
                            ? [.isSelected] : []
                    )
                }
            }
        }
    }

    // MARK: - Section label

    /// Uppercase eyebrow label with a trailing hairline rule — the same
    /// editorial device used throughout LibraryView and StatsView.
    private func sectionLabel(_ text: String) -> some View {
        HStack(spacing: Spacing.sm) {
            // LocalizedStringKey so a String argument still routes through the
            // catalog (Text(String) would render verbatim).
            Text(LocalizedStringKey(text))
                .font(Typography.eyebrow)
                .tracking(Typography.eyebrowTracking)
                .textCase(.uppercase)
                .foregroundStyle(palette.secondaryText)
            Rectangle()
                .fill(palette.hairline)
                .frame(height: Spacing.hairlineWidth)
        }
    }
}

// MARK: - Choice row

/// A single tappable row in a Settings picker (language or appearance).
/// Selected row warms to the accent tint with a hairline ring. Uses the clean
/// `control` font so chrome stays modern and consistent, not serif.
private struct SettingsChoiceRow: View {
    let title: String
    let isSelected: Bool
    let palette: BrandPalette

    var body: some View {
        HStack {
            Text(title)
                .font(Typography.control(17, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? palette.accent : palette.text)
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
