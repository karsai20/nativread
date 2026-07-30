import SwiftUI

/// Plain-language privacy policy that is always available inside the app.
/// Keep it aligned with `docs/legal/privacy-policy.*.md` and the public policy.
struct PrivacyPolicyView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.locale) private var locale

    private var palette: BrandPalette {
        BrandPalette.resolve(systemDark: colorScheme == .dark)
    }

    private var copy: PrivacyPolicyCopy {
        PrivacyPolicyCopy.make(
            languageCode: locale.language.languageCode?.identifier,
            providerName: TranslationPrivacy.aiProviderName
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                header

#if DEBUG
                Label(copy.draftNotice, systemImage: "wrench.and.screwdriver")
                    .font(Typography.meta())
                    .foregroundStyle(palette.secondaryText)
                    .padding(Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(palette.accent.opacity(0.10))
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: Spacing.radiusSmall,
                            style: .continuous
                        )
                    )
#endif

                ForEach(Array(copy.sections.enumerated()), id: \.offset) {
                    index, section in
                    policySection(number: index + 1, section: section)
                }

                if let url = TranslationPrivacy.publicPolicyURL {
                    Link(destination: url) {
                        Label(copy.publicLink, systemImage: "arrow.up.right")
                            .font(Typography.control(16, weight: .semibold))
                            .foregroundStyle(palette.accent)
                    }
                    .accessibilityIdentifier("privacy.public.link")
                }
            }
            .padding(Spacing.lg)
            .padding(.bottom, Spacing.lg)
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
        .background(palette.background.ignoresSafeArea())
        .navigationTitle(copy.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("privacy.screen")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 23, weight: .semibold))
                .foregroundStyle(palette.accent)
                .frame(width: 52, height: 52)
                .background(palette.accent.opacity(0.12), in: Circle())

            Text(copy.title)
                .font(Typography.display(32))
                .foregroundStyle(palette.text)

            Text(copy.version)
                .font(Typography.meta())
                .foregroundStyle(palette.secondaryText)

            Text(copy.introduction)
                .font(Typography.body(17))
                .foregroundStyle(palette.text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func policySection(
        number: Int,
        section: PrivacyPolicyCopy.Section
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("\(number). \(section.title)")
                .font(Typography.control(18, weight: .semibold))
                .foregroundStyle(palette.text)

            ForEach(Array(section.paragraphs.enumerated()), id: \.offset) {
                _, paragraph in
                Text(paragraph)
                    .font(Typography.body(16))
                    .foregroundStyle(palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surface)
        .clipShape(
            RoundedRectangle(cornerRadius: Spacing.radiusCard, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: Spacing.radiusCard, style: .continuous)
                .strokeBorder(palette.hairline, lineWidth: Spacing.hairlineWidth)
        }
    }
}

private struct PrivacyPolicyCopy {
    struct Section {
        let title: String
        let paragraphs: [String]
    }

    let navigationTitle: String
    let title: String
    let version: String
    let introduction: String
    let draftNotice: String
    let publicLink: String
    let sections: [Section]

    static func make(
        languageCode: String?,
        providerName: String
    ) -> PrivacyPolicyCopy {
        languageCode == "hu"
            ? hungarian(providerName: providerName)
            : english(providerName: providerName)
    }

    private static func english(providerName: String) -> PrivacyPolicyCopy {
        PrivacyPolicyCopy(
            navigationTitle: "Privacy Policy",
            title: "NativRead Privacy Policy",
            version: "Effective July 22, 2026 · Version 1.2",
            introduction: "Reading is private by default. Your books stay on this device unless you deliberately start an AI translation.",
            draftNotice: "Product-ready draft · add the final public URL and operator contact before App Store submission.",
            publicLink: "View the published policy",
            sections: [
                Section(
                    title: "Who is responsible",
                    paragraphs: [
                        "The developer identified on NativRead’s App Store product page is the data controller. Current support and contact information is available on that page."
                    ]
                ),
                Section(
                    title: "Private, offline reading",
                    paragraphs: [
                        "Importing, reading, highlights, Apple Look Up, and reader settings work locally. NativRead contains no advertising or analytics SDK and does not sell personal data.",
                        "A book leaves your device only when you choose AI translation."
                    ]
                ),
                Section(
                    title: "Data used for translation",
                    paragraphs: [
                        "Sign in with Apple provides a stable account identifier. NativRead does not request your name or email address from Apple.",
                        "The service processes the uploaded EPUB, its technical fingerprint, chosen language, translation status, and purchase or entitlement records only to authenticate you, translate the book, deliver the result, restore access, prevent abuse, and keep the service reliable.",
                        "To demonstrate active Terms acceptance, NativRead stores the pseudonymous account, book fingerprint, client and server time, acceptance ID, locale, method, statement and Terms versions, and archived Terms URL. This record contains neither the book title nor book text."
                    ]
                ),
                Section(
                    title: "AI and service providers",
                    paragraphs: [
                        "After your separate permission, the book text is sent to \(providerName), a third-party AI service, to create the translation. Its paid API does not use prompts or responses to improve Google products. Google may retain them for a limited period for abuse detection and required legal disclosures.",
                        "Apple processes sign-in and in-app purchase data under its own privacy terms. NativRead uses Cloudflare for hosting and compute. Book-file storage in R2, the D1 metadata database, and translation containers are restricted to the EU jurisdiction; the encrypted request may pass through Cloudflare’s global edge network. Cloudflare and the AI provider may process data only to provide the service and must protect it to at least the level described here."
                    ]
                ),
                Section(
                    title: "Retention and deletion",
                    paragraphs: [
                        "The source and translated server copies are removed after successful delivery. Normal automatic expiry is 24 hours; a separate storage safety rule ensures that an object surviving an abnormal interruption is never retained beyond 30 days.",
                        "Account, entitlement, and acceptance metadata remains until you delete the account. Records that must be kept for a legal claim or by tax, accounting, fraud-prevention, or other law may be retained only for the required period. Books already stored in your local library are not removed by account deletion."
                    ]
                ),
                Section(
                    title: "Your choices and rights",
                    paragraphs: [
                        "You can decline AI processing and continue using the offline reader. You may withdraw permission for future AI processing without undoing processing already completed at your request. You can delete your translation account from Settings; deletion removes the backend account and associated data that NativRead is not legally required to retain.",
                        "Depending on where you live, you may also request access, correction, restriction, portability, or object to processing through the support contact on the App Store page."
                    ]
                ),
                Section(
                    title: "Security and children",
                    paragraphs: [
                        "Sessions are stored in the iOS Keychain and translation requests use authenticated connections. No system can be guaranteed perfectly secure, but access is limited to what is needed to operate the service.",
                        "NativRead’s translation service is for adults and does not knowingly create translation accounts for people under 18."
                    ]
                ),
                Section(
                    title: "Changes",
                    paragraphs: [
                        "Material changes to AI processing require new permission in the app. The effective date and version above change whenever this policy is materially updated."
                    ]
                )
            ]
        )
    }

    private static func hungarian(providerName: String) -> PrivacyPolicyCopy {
        PrivacyPolicyCopy(
            navigationTitle: "Adatkezelési tájékoztató",
            title: "NativRead Adatkezelési tájékoztató",
            version: "Hatályos: 2026. július 22. · 1.2 verzió",
            introduction: "Az olvasás alapból magánügy. A könyveid a készülékeden maradnak, hacsak tudatosan nem indítasz AI-fordítást.",
            draftNotice: "Termékkész tervezet · App Store-beküldés előtt a nyilvános URL-t és az üzemeltető elérhetőségét véglegesíteni kell.",
            publicLink: "Közzétett tájékoztató megnyitása",
            sections: [
                Section(
                    title: "Ki felel az adatkezelésért",
                    paragraphs: [
                        "Az adatkezelő a NativRead App Store-termékoldalán megjelölt fejlesztő. Az aktuális támogatási és kapcsolati adatok ugyanott érhetők el."
                    ]
                ),
                Section(
                    title: "Privát, offline olvasás",
                    paragraphs: [
                        "Az importálás, az olvasás, a kiemelések, az Apple Look Up és az olvasási beállítások helyben működnek. A NativRead nem tartalmaz hirdetési vagy analitikai SDK-t, és nem értékesít személyes adatot.",
                        "A könyv csak akkor hagyja el a készülékedet, amikor AI-fordítást indítasz."
                    ]
                ),
                Section(
                    title: "A fordításhoz kezelt adatok",
                    paragraphs: [
                        "Az Apple-lel történő bejelentkezés egy állandó fiókazonosítót biztosít. A NativRead nem kéri el az Apple-től a nevedet vagy az e-mail-címedet.",
                        "A szolgáltatás a feltöltött EPUB-fájlt, annak technikai ujjlenyomatát, a választott nyelvet, a fordítás állapotát és a vásárlási vagy jogosultsági adatokat kizárólag azonosításra, fordításra, kézbesítésre, hozzáférés-helyreállításra, visszaélés-megelőzésre és a szolgáltatás megbízható működtetésére használja.",
                        "Az aktív feltételelfogadás bizonyíthatóságához a NativRead az álneves fiókot, a könyv ujjlenyomatát, kliens- és szerveridőpontot, elfogadásazonosítót, nyelvet, módszert, nyilatkozat- és feltételverziót, valamint az archivált feltétel URL-jét tárolja. Ez a rekord nem tartalmaz könyvcímet vagy könyvszöveget."
                    ]
                ),
                Section(
                    title: "AI- és egyéb szolgáltatók",
                    paragraphs: [
                        "Külön engedélyed után a könyv szövegét a \(providerName), egy külső AI-szolgáltatás kapja meg a fordítás elkészítéséhez. A fizetős API a kéréseket és válaszokat nem használja Google-termékek fejlesztésére. A Google visszaélés-felismerés és kötelező jogi adatszolgáltatás céljából korlátozott ideig megőrizheti őket.",
                        "Az Apple a saját adatvédelmi feltételei szerint kezeli a bejelentkezési és alkalmazáson belüli vásárlási adatokat. A NativRead tárhely- és futtatási szolgáltatója a Cloudflare. A könyvfájlok R2-tárhelye, a D1-metaadatbázis és a fordítókonténerek EU-joghatósághoz kötöttek; a titkosított kérés Cloudflare globális peremhálózatán haladhat át. A Cloudflare és az AI-szolgáltató kizárólag a szolgáltatás biztosításához dolgozhatja fel az adatokat, legalább az itt leírt védelemmel."
                    ]
                ),
                Section(
                    title: "Megőrzés és törlés",
                    paragraphs: [
                        "A forrás- és a lefordított szerverpéldány a sikeres kézbesítés után törlődik. A normál automatikus lejárat 24 óra; külön tárhelyi biztonsági szabály biztosítja, hogy rendellenes megszakadás után se maradjon objektum 30 napnál tovább.",
                        "A fiók-, jogosultsági és elfogadási metaadatok a fiók törléséig maradnak meg. Jogi igény, adózási, számviteli, csalásmegelőzési vagy más kötelező megőrzés esetén csak a szükséges ideig őrizzük őket. A helyi könyvtáradban lévő könyveket a fióktörlés nem távolítja el."
                    ]
                ),
                Section(
                    title: "Döntéseid és jogaid",
                    paragraphs: [
                        "Az AI-feldolgozást elutasíthatod, az offline olvasót ettől továbbra is használhatod. A jövőbeli AI-feldolgozáshoz adott engedélyt visszavonhatod; ez nem teszi semmissé a kérésedre már befejezett feldolgozást. A fordítási fiókot a Beállításokban törölheted; ezzel eltávolítjuk a szerveroldali fiókot és minden kapcsolódó adatot, amelyet jogszabály alapján nem kell megőriznünk.",
                        "Lakóhelyedtől függően hozzáférést, helyesbítést, korlátozást és adathordozhatóságot is kérhetsz, illetve tiltakozhatsz az adatkezelés ellen az App Store-oldalon megadott elérhetőségen."
                    ]
                ),
                Section(
                    title: "Biztonság és gyermekek",
                    paragraphs: [
                        "A munkamenet az iOS Kulcskarikában tárolódik, a fordítási kérések pedig hitelesített kapcsolaton mennek. Tökéletes biztonság nem garantálható, de a hozzáférést a szolgáltatás működtetéséhez szükséges körre korlátozzuk.",
                        "A NativRead fordítószolgáltatása felnőtteknek szól, és tudatosan nem hoz létre fordítási fiókot 18 év alattiaknak."
                    ]
                ),
                Section(
                    title: "Változások",
                    paragraphs: [
                        "Az AI-adatkezelés lényeges változásához új engedélyt kérünk az appban. Lényeges módosításkor a fenti hatálybalépési dátum és verzió is frissül."
                    ]
                )
            ]
        )
    }
}
