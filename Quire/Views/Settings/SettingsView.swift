import SwiftUI

/// App-wide settings sheet: app language and Define (dictionary) language.
/// Styled in the same editorial idiom as StatsView and VocabularyView —
/// BrandPalette, eyebrow section labels with hairline rules, Cormorant display
/// typography. Launched from the library header gear button.
struct SettingsView: View {
    @Environment(LocalizationStore.self) private var localizationStore
    @Environment(DictionaryProvider.self) private var dictionaryProvider
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    private var palette: BrandPalette {
        BrandPalette.resolve(systemDark: colorScheme == .dark)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    appLanguageSection
                    defineLanguageSection
                }
                .padding(Spacing.lg)
            }
            .background(palette.background.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .tint(palette.accent)
                        .accessibilityIdentifier("settings.done")
                }
            }
        }
        .accessibilityIdentifier("settings.sheet")
    }

    // MARK: - App Language

    private var appLanguageSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            sectionLabel("App Language")

            VStack(spacing: Spacing.xs) {
                ForEach(AppLanguage.pickable, id: \.rawValue) { language in
                    SettingsLanguageRow(
                        language: language,
                        isSelected: localizationStore.appLanguage == language,
                        palette: palette
                    )
                    .onTapGesture {
                        localizationStore.setLanguage(language)
                        Task {
                            await dictionaryProvider.reprepare(
                                for: localizationStore.dictionaryLanguage
                            )
                        }
                    }
                    .accessibilityIdentifier(
                        "settings.applang.\(language.rawValue)"
                    )
                    .accessibilityLabel(language.endonym)
                    .accessibilityAddTraits(
                        localizationStore.appLanguage == language
                            ? [.isSelected] : []
                    )
                }
            }
        }
    }

    // MARK: - Define Language

    private var defineLanguageSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            sectionLabel("Define Language")

            VStack(spacing: Spacing.xs) {
                ForEach(AppLanguage.definePickable, id: \.rawValue) { language in
                    SettingsLanguageRow(
                        language: language,
                        isSelected: localizationStore.defineLanguage == language,
                        palette: palette
                    )
                    .onTapGesture {
                        localizationStore.setDefineLanguage(language)
                        Task {
                            await dictionaryProvider.reprepare(
                                for: localizationStore.dictionaryLanguage
                            )
                        }
                    }
                    .accessibilityIdentifier(
                        "settings.definelang.\(language.rawValue)"
                    )
                    .accessibilityLabel(language.endonym)
                    .accessibilityAddTraits(
                        localizationStore.defineLanguage == language
                            ? [.isSelected] : []
                    )
                }
            }

            // Caption explaining what each option provides.
            Text("English uses the WordNet dictionary. Magyar adds an English → Hungarian bilingual dictionary.")
                .font(Typography.meta())
                .foregroundStyle(palette.secondaryText)
                .padding(.top, Spacing.xxs)
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

// MARK: - Language row

/// A single tappable row in a Settings language picker. Selected row warms to
/// a russet tint with a hairline ring — mirrors `LanguageRow` in onboarding.
private struct SettingsLanguageRow: View {
    let language: AppLanguage
    let isSelected: Bool
    let palette: BrandPalette

    var body: some View {
        HStack {
            Text(language.endonym)
                .font(Typography.display(22))
                .fontWeight(isSelected ? .semibold : .regular)
                .tracking(0.3)
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
