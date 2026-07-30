import SwiftUI

/// Explicit permission shown before a book is sent for third-party AI
/// processing. This is deliberately separate from accepting the Terms.
struct AIProcessingConsentView: View {
    let providerName: String
    let onAllow: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss

    private var palette: BrandPalette {
        BrandPalette.resolve(systemDark: colorScheme == .dark)
    }

    private var copy: AIProcessingConsentCopy {
        locale.language.languageCode?.identifier == "hu"
            ? .hungarian(providerName: providerName)
            : .english(providerName: providerName)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // No "Done" action: on a consent screen the only ways out are
                // the two deliberate choices in the action bar.
                AppSheetHeader(
                    title: LocalizedStringKey(copy.navigationTitle),
                    palette: palette
                )
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.sm)

                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        header

                        AppSettingsSection(palette: palette) {
                            disclosureRow(
                                icon: "text.document",
                                title: copy.dataTitle,
                                detail: copy.dataDetail
                            )
                            rowSeparator
                            disclosureRow(
                                icon: "sparkles",
                                title: copy.providerTitle,
                                detail: copy.providerDetail
                            )
                            rowSeparator
                            disclosureRow(
                                icon: "trash",
                                title: copy.retentionTitle,
                                detail: copy.retentionDetail
                            )
                        }

                        NavigationLink {
                            PrivacyPolicyView()
                        } label: {
                            Label {
                                Text(verbatim: copy.privacyLink)
                            } icon: {
                                Image(systemName: "hand.raised")
                            }
                            .font(Typography.control(16, weight: .semibold))
                            .foregroundStyle(palette.accent)
                        }
                        .accessibilityIdentifier("translation.aiConsent.privacy")
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.lg)
                    .frame(maxWidth: 620)
                    .frame(maxWidth: .infinity)
                }
            }
            .background(palette.background.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                actionBar
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .presentationDetents([.large])
        .accessibilityIdentifier("translation.aiConsent.screen")
    }

    /// Matches the hairline `AppSettingsRow` draws, so these taller rows sit
    /// in the same grouped card without looking hand-made.
    private var rowSeparator: some View {
        Rectangle()
            .fill(palette.hairline)
            .frame(height: Spacing.hairlineWidth)
            .padding(.leading, Spacing.md)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Image(systemName: "sparkles.rectangle.stack.fill")
                .font(.system(size: 23, weight: .semibold))
                .foregroundStyle(palette.accent)
                .frame(width: 52, height: 52)
                .background(
                    palette.accentSoft,
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )

            Text(copy.title)
                .font(Typography.display(31))
                .foregroundStyle(palette.text)

            Text(copy.introduction)
                .font(Typography.body(17))
                .foregroundStyle(palette.text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func disclosureRow(
        icon: String,
        title: String,
        detail: String
    ) -> some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(palette.accent)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title)
                    .font(Typography.control(17, weight: .semibold))
                    .foregroundStyle(palette.text)
                Text(detail)
                    .font(Typography.meta())
                    .foregroundStyle(palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var actionBar: some View {
        VStack(spacing: Spacing.sm) {
            AppPrimaryButton(
                title: LocalizedStringKey(copy.allowButton),
                systemImage: "sparkles",
                action: {
                    dismiss()
                    onAllow()
                },
                palette: palette
            )
            .accessibilityIdentifier("translation.aiConsent.allow")

            AppPrimaryButton(
                title: LocalizedStringKey(copy.notNowButton),
                tone: .secondary,
                action: { dismiss() },
                palette: palette
            )
            .accessibilityIdentifier("translation.aiConsent.cancel")
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.md)
        .background(.ultraThinMaterial)
    }
}

private struct AIProcessingConsentCopy {
    let navigationTitle: String
    let title: String
    let introduction: String
    let dataTitle: String
    let dataDetail: String
    let providerTitle: String
    let providerDetail: String
    let retentionTitle: String
    let retentionDetail: String
    let privacyLink: String
    let allowButton: String
    let notNowButton: String

    static func english(providerName: String) -> AIProcessingConsentCopy {
        AIProcessingConsentCopy(
            navigationTitle: "AI processing",
            title: "Before we translate",
            introduction: "Your permission is needed before this book is shared for AI translation. This service is for adults aged 18 or over.",
            dataTitle: "What is sent",
            dataDetail: "The text of this book and the target language are sent through NativRead’s translation server.",
            providerTitle: "Where it goes",
            providerDetail: "\(providerName), a third-party AI service, processes the text only to create your translation. Its paid API does not use the text to improve models.",
            retentionTitle: "How long it stays",
            retentionDetail: "NativRead’s server copies are deleted after processing and delivery, or within 30 days if delivery is interrupted. Google may keep limited safety logs under its API terms.",
            privacyLink: "Read the Privacy Policy",
            allowButton: "Allow AI translation",
            notNowButton: "Not now"
        )
    }

    static func hungarian(providerName: String) -> AIProcessingConsentCopy {
        AIProcessingConsentCopy(
            navigationTitle: "AI-adatkezelés",
            title: "Mielőtt fordítunk",
            introduction: "Az engedélyed szükséges, mielőtt ezt a könyvet AI-fordítás céljából továbbítjuk. A szolgáltatást csak 18 éven felüliek használhatják.",
            dataTitle: "Mit küldünk el",
            dataDetail: "A könyv szövege és a célnyelv a NativRead fordítószerverén keresztül kerül továbbításra.",
            providerTitle: "Hová kerül",
            providerDetail: "A szöveget a \(providerName), egy külső AI-szolgáltatás kizárólag a fordítás elkészítéséhez dolgozza fel. A fizetős API a szöveget nem használja modellek fejlesztésére.",
            retentionTitle: "Meddig marad meg",
            retentionDetail: "A NativRead szerverpéldányai a feldolgozás és kézbesítés után, megszakadt kézbesítésnél legfeljebb 30 napon belül törlődnek. A Google az API-feltételei szerint korlátozott biztonsági naplót őrizhet.",
            privacyLink: "Adatkezelési tájékoztató elolvasása",
            allowButton: "AI-fordítás engedélyezése",
            notNowButton: "Most nem"
        )
    }
}
