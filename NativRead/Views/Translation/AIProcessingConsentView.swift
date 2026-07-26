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
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    header

                    VStack(spacing: 0) {
                        disclosureRow(
                            icon: "text.document",
                            title: copy.dataTitle,
                            detail: copy.dataDetail
                        )
                        SettingsRowDivider(palette: palette)
                        disclosureRow(
                            icon: "sparkles",
                            title: copy.providerTitle,
                            detail: copy.providerDetail
                        )
                        SettingsRowDivider(palette: palette)
                        disclosureRow(
                            icon: "trash",
                            title: copy.retentionTitle,
                            detail: copy.retentionDetail
                        )
                    }
                    .settingsGroupedCard(palette: palette)

                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        Label(copy.privacyLink, systemImage: "hand.raised")
                            .font(Typography.control(16, weight: .semibold))
                            .foregroundStyle(palette.accent)
                    }
                    .accessibilityIdentifier("translation.aiConsent.privacy")
                }
                .padding(Spacing.lg)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
            }
            .background(palette.background.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                actionBar
            }
            .navigationTitle(copy.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.large])
        .accessibilityIdentifier("translation.aiConsent.screen")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Image(systemName: "sparkles.rectangle.stack.fill")
                .font(.system(size: 23, weight: .semibold))
                .foregroundStyle(palette.accent)
                .frame(width: 52, height: 52)
                .background(palette.accent.opacity(0.12), in: Circle())

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
            Button {
                dismiss()
                onAllow()
            } label: {
                Text(copy.allowButton)
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 30)
            }
            .buttonStyle(.borderedProminent)
            .tint(palette.accent)
            .accessibilityIdentifier("translation.aiConsent.allow")

            Button(copy.notNowButton) { dismiss() }
                .font(Typography.control(16, weight: .semibold))
                .foregroundStyle(palette.secondaryText)
                .frame(minHeight: Spacing.minTapTarget)
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
