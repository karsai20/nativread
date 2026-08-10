import SwiftUI

/// Plain-language terms for the optional AI translation service.
///
/// Apple’s Standard EULA continues to govern the app license. These additional
/// terms cover the user-supplied book, AI processing, and any translation
/// purchase. Keep this screen in sync with `docs/legal/terms-of-service.*.md`.
struct TermsOfUseView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.locale) private var locale

    private var palette: BrandPalette {
        BrandPalette.resolve(systemDark: colorScheme == .dark)
    }

    private var copy: TranslationTermsCopy {
        locale.language.languageCode?.identifier == "hu" ? .hungarian : .english
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
                    termsSection(number: index + 1, section: section)
                }

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text(copy.appleEULAExplanation)
                        .font(Typography.meta())
                        .foregroundStyle(palette.secondaryText)

                    Link(destination: TranslationTerms.appleStandardEULAURL) {
                        Label(copy.appleEULALink, systemImage: "arrow.up.right")
                            .font(Typography.control(16, weight: .semibold))
                            .foregroundStyle(palette.accent)
                    }
                }
                .padding(.bottom, Spacing.lg)
            }
            .padding(Spacing.lg)
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
        .background(palette.background.ignoresSafeArea())
        .navigationTitle(copy.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("terms.screen")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Image(systemName: "doc.text")
                .font(.system(size: 24, weight: .semibold))
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

    private func termsSection(
        number: Int,
        section: TranslationTermsCopy.Section
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

private struct TranslationTermsCopy {
    struct Section {
        let title: String
        let paragraphs: [String]
    }

    let navigationTitle: String
    let title: String
    let version: String
    let introduction: String
    let draftNotice: String
    let sections: [Section]
    let appleEULAExplanation: String
    let appleEULALink: String

    static let english = TranslationTermsCopy(
        navigationTitle: "Terms of Use",
        title: "NativRead Terms of Use",
        version: "Translation service · Version 1.3 · Effective 5 August 2026",
        introduction: "These terms apply to NativRead’s optional AI translation service. Before a book is uploaded for translation, you actively accept the current version of these terms. By accepting them and starting a translation you also confirm, per the User content and copyright section, that you may lawfully request that translation.",
        draftNotice: "Draft for product testing · legal review is still required before release.",
        sections: [
            Section(
                title: "The service",
                paragraphs: [
                    "The reader works offline with your own supported files. The translation service sends an eligible EPUB to the translation system and adds the result to your library as a separate book.",
                    "The AI translation service is for adults aged 18 or over. The first reading chapter is free once per book and account. If a paid whole-book option is offered, its exact App Store price is shown before purchase."
                ]
            ),
            Section(
                title: "Account and eligibility",
                paragraphs: [
                    "The translation service is for adults aged 18 or over. Sign in with Apple connects translation access and any purchase to your account.",
                    "Keep your account credentials secure. You are responsible for activity you authorise through your account and must notify us if you suspect unauthorised use."
                ]
            ),
            Section(
                title: "AI translation",
                paragraphs: [
                    "Translations are produced by artificial intelligence, not a human literary translator. They may contain errors, awkward wording, or inconsistencies.",
                    "Some books may be declined by the translation provider’s content rules. If the free preview is declined, that attempt is not treated as used.",
                    "We do not use your books, your translations, or your reading data to train AI models, and the paid API terms of the provider we use prohibit using your text to improve its products or models."
                ]
            ),
            Section(
                title: "Purchases, delivery, and refunds",
                paragraphs: [
                    "Paid whole-book translation, when available, is purchased through Apple for the identified book and target language. The exact price is shown before purchase.",
                    "If a paid translation cannot be completed, we retry or restore the reserved translation credit. Apple’s refund process and all mandatory consumer remedies remain available."
                ]
            ),
            Section(
                title: "Data and AI processing",
                paragraphs: [
                    "A book stays on your device unless you start a translation. Separate, provider-specific permission is requested before book text is sent to an external AI service. Declining that permission does not affect the offline reader.",
                    "The Privacy Policy identifies the controller, processors, purposes, retention, deletion, and your data-protection rights. You may withdraw permission for future AI processing; withdrawal does not undo processing already completed at your request."
                ]
            ),
            Section(
                title: "Acceptable use",
                paragraphs: [
                    "Do not use the service unlawfully, infringe another person’s rights, share translated files, overload or probe the service, or attempt to access another user’s data. We may restrict accounts used for abuse.",
                    "Do not resell the translation service, sublicense it, make it available to other people, or access it by automated means other than the app itself."
                ]
            ),
            Section(
                title: "User content and copyright",
                paragraphs: [
                    "By accepting these terms and starting a translation, you confirm that the book is DRM-free, that you lawfully acquired it, and that you have the permission or another lawful basis required to create the requested translation. Owning a copy does not necessarily grant translation rights.",
                    "You represent that uploading and processing the book, and your use of the result, do not infringe another person’s copyright or other intellectual-property right.",
                    "You are responsible for checking the legal basis for your use. NativRead does not conduct advance or retrospective legal review of books, and accepting an upload does not approve or certify its lawfulness.",
                    "The translation is made for you and we claim no ownership of it: whatever rights we hold in the machine output, we pass to you for your personal use. Because a translation is an adaptation of the original book, the author’s and publisher’s rights in that book continue to cover the translation — it gives you no right you did not already have.",
                    "The translation is supplied only for your personal, non-commercial reading. Except for copies reasonably necessary on devices or private storage you control, you must not reproduce, publish, sell, distribute, make available, or share it or any extract with another person.",
                    "To the extent permitted by applicable law, if your intentional or negligent breach of these promises causes a substantiated third-party claim, you are responsible for the documented direct loss reasonably resulting from that breach. This does not remove any mandatory consumer right or transfer a legal duty that the law places on NativRead.",
                    "After a credible rightsholder notice, we may suspend the disputed processing while we investigate. Repeated or serious infringement may lead to account restriction or termination."
                ]
            ),
            Section(
                title: "Liability",
                paragraphs: [
                    "AI translations can contain errors and are not a substitute for professional advice or a human literary translation. We do not promise uninterrupted availability.",
                    "Nothing in these terms excludes or limits liability, guarantees, remedies, or consumer rights that cannot lawfully be excluded or limited.",
                    "Beyond that, and where the law allows it, our total liability for the translation service is limited to what you paid for it in the twelve months before the claim arose. That limit never covers loss caused intentionally or by gross negligence, or harm to life, bodily integrity, or health."
                ]
            ),
            Section(
                title: "Changes and termination",
                paragraphs: [
                    "We may update the service and these terms. A material change requires renewed, active acceptance before a new translation; an unchecked box is never treated as acceptance.",
                    "You can stop using the translation service and delete your account. We may discontinue the service with reasonable notice, without affecting rights attached to completed purchases."
                ]
            ),
            Section(
                title: "What belongs to NativRead",
                paragraphs: [
                    "The app, its name, interface, design, and source code belong to the operator. These terms give you a personal licence to use the app; they transfer none of that to you, and they do not affect your ownership of your own books, translations, highlights, or notes."
                ]
            ),
            Section(
                title: "Law, operator, and contact",
                paragraphs: [
                    "Hungarian law applies without reducing mandatory consumer protection in your country of residence. You may use the courts or any competent consumer alternative-dispute-resolution forum available to you.",
                    "The current operator name, postal address, support contact, rightsholder-notice route, and the immutable archived copy of these terms are available on NativRead’s legal website linked from the app."
                ]
            )
        ],
        appleEULAExplanation: "Apple’s Standard EULA separately governs your license to the app unless a custom EULA is provided in the App Store.",
        appleEULALink: "Read Apple’s Standard EULA"
    )

    static let hungarian = TranslationTermsCopy(
        navigationTitle: "Felhasználási feltételek",
        title: "NativRead Felhasználási feltételek",
        version: "Fordítószolgáltatás · 1.3 verzió · Hatályos: 2026. augusztus 5.",
        introduction: "Ezek a feltételek a NativRead választható AI-fordítószolgáltatására vonatkoznak. Mielőtt egy könyvet fordításra feltöltesz, aktívan elfogadod az aktuális változatot. Az elfogadással és a fordítás elindításával a Felhasználói tartalom és szerzői jog szakasz szerint azt is megerősíted, hogy jogszerűen kérheted a fordítást.",
        draftNotice: "Terméktesztelési vázlat · kiadás előtt jogi átvizsgálás szükséges.",
        sections: [
            Section(
                title: "A szolgáltatás",
                paragraphs: [
                    "Az olvasó a saját, támogatott fájljaiddal offline működik. A fordítószolgáltatás a megfelelő EPUB-fájlt elküldi a fordítórendszernek, az eredményt pedig külön könyvként hozzáadja a könyvtáradhoz.",
                    "Az AI-fordítószolgáltatást csak 18 éven felüliek használhatják. Az első olvasmányfejezet könyvenként és fiókonként egyszer ingyenes. Ha elérhető fizetős teljeskönyv-fordítás, a pontos App Store-ár a vásárlás előtt látható."
                ]
            ),
            Section(
                title: "Fiók és jogosultság",
                paragraphs: [
                    "A fordítószolgáltatást csak 18 éven felüliek használhatják. Az Apple-lel történő bejelentkezés a fiókodhoz köti a fordítási hozzáférést és az esetleges vásárlást.",
                    "Óvd a fiókod hitelesítő adatait. Az általad jóváhagyott fióktevékenységért te felelsz; feltételezett jogosulatlan használat esetén értesíts bennünket."
                ]
            ),
            Section(
                title: "AI-fordítás",
                paragraphs: [
                    "A fordítást mesterséges intelligencia, nem emberi műfordító készíti. Előfordulhat benne hiba, döccenő megfogalmazás vagy következetlenség.",
                    "Egyes könyveket a fordítást végző szolgáltató tartalmi szabályai elutasíthatnak. Ha ez az ingyenes próbánál történik, a próbálkozás nem számít felhasználtnak.",
                    "A könyveidet, a fordításaidat és az olvasási adataidat nem használjuk AI-modellek betanítására, és az igénybe vett szolgáltató fizetős API-jának feltételei is tiltják, hogy a szövegedet termékei vagy modelljei fejlesztésére használja."
                ]
            ),
            Section(
                title: "Vásárlás, kézbesítés és visszatérítés",
                paragraphs: [
                    "A fizetős teljeskönyv-fordítás, amikor elérhető, az Apple rendszerén keresztül, a megjelölt könyvre és célnyelvre vásárolható meg. A pontos ár a vásárlás előtt látható.",
                    "Ha egy kifizetett fordítás nem fejezhető be, újrapróbáljuk vagy helyreállítjuk a lefoglalt fordítási keretet. Az Apple visszatérítési eljárása és minden kötelező fogyasztói jogorvoslat változatlanul elérhető."
                ]
            ),
            Section(
                title: "Adatok és AI-feldolgozás",
                paragraphs: [
                    "A könyv a készülékeden marad, amíg nem indítasz fordítást. Mielőtt a könyv szövege külső AI-szolgáltatóhoz kerül, külön, szolgáltatóspecifikus engedélyt kérünk. Az engedély elutasítása nem érinti az offline olvasót.",
                    "Az Adatkezelési tájékoztató megnevezi az adatkezelőt, az adatfeldolgozókat, a célokat, a megőrzést, a törlést és az adatvédelmi jogaidat. A jövőbeli AI-feldolgozáshoz adott engedélyedet visszavonhatod; ez a korábban, kérésedre már befejezett feldolgozást nem teszi semmissé."
                ]
            ),
            Section(
                title: "Rendeltetésszerű használat",
                paragraphs: [
                    "Tilos a szolgáltatást jogellenesen használni, más jogait megsérteni, fordított fájlt megosztani, a szolgáltatást túlterhelni vagy szondázni, illetve más felhasználó adataihoz hozzáférést kísérelni. A visszaélésre használt fiókokat korlátozhatjuk.",
                    "A fordítószolgáltatást nem értékesítheted tovább, nem adhatod tovább licencbe, nem teheted mások számára elérhetővé, és az alkalmazáson kívüli automatizált eszközzel nem férhetsz hozzá."
                ]
            ),
            Section(
                title: "Felhasználói tartalom és szerzői jog",
                paragraphs: [
                    "E feltételek elfogadásával és a fordítás elindításával megerősíted, hogy a könyv DRM-mentes, jogszerűen szerezted be, és kért fordításához rendelkezel a szükséges engedéllyel vagy más jogalappal. Egy könyvpéldány megszerzése önmagában nem feltétlenül ad fordítási jogot.",
                    "Kijelented, hogy a könyv feltöltése és feldolgozása, valamint az eredmény általad történő használata nem sérti más szerzői vagy egyéb szellemi tulajdonjogát.",
                    "A felhasználás jogalapjának ellenőrzése a te feladatod. A NativRead nem végez előzetes vagy utólagos jogi vizsgálatot a könyveken; a feltöltés elfogadása nem jelenti annak jóváhagyását vagy jogszerűségi tanúsítását.",
                    "A fordítás neked készül, és nem tartunk rá igényt: a gépi kimeneten fennálló jogainkat személyes használatra átengedjük. Mivel a fordítás az eredeti mű átdolgozása, a könyv szerzőjének és kiadójának jogai a fordításra is kiterjednek — a fordítás nem ad olyan jogot, amellyel korábban nem rendelkeztél.",
                    "A fordítást kizárólag saját, személyes, nem kereskedelmi olvasásra kapod. A saját ellenőrzésed alatt álló eszközökön vagy privát tárhelyen észszerűen szükséges példányokon túl nem másolhatod, nem teheted közzé, nem adhatod el, nem terjesztheted, nem teheted hozzáférhetővé és nem oszthatod meg mással a fordítást vagy annak részletét.",
                    "Az alkalmazandó jog által megengedett mértékben, ha e vállalások szándékos vagy gondatlan megszegése igazolt harmadik fél általi igényt okoz, az ebből észszerűen eredő, dokumentált közvetlen kárért felelsz. Ez nem von el kötelező fogyasztói jogot, és nem hárít át rád olyan jogi kötelezettséget, amelyet a jog a NativReadre telepít.",
                    "Hitelt érdemlő jogtulajdonosi bejelentés után a kifogásolt feldolgozást a vizsgálat idejére felfüggeszthetjük. Ismétlődő vagy súlyos jogsértés a fiók korlátozásához vagy megszüntetéséhez vezethet."
                ]
            ),
            Section(
                title: "Felelősség",
                paragraphs: [
                    "Az AI-fordítás hibákat tartalmazhat, és nem helyettesít szakmai tanácsot vagy emberi műfordítást. Megszakítás nélküli rendelkezésre állást nem ígérünk.",
                    "E feltételek nem zárnak ki és nem korlátoznak olyan felelősséget, kellékszavatosságot, jogorvoslatot vagy fogyasztói jogot, amely jogszerűen nem zárható ki vagy nem korlátozható.",
                    "Ezen túlmenően, ahol a jog megengedi, a fordítószolgáltatással kapcsolatos teljes felelősségünk az igény keletkezését megelőző tizenkét hónapban a szolgáltatásért fizetett összegre korlátozódik. A korlátozás soha nem terjed ki a szándékosan vagy súlyosan gondatlanul okozott kárra, sem az emberi életet, testi épséget vagy egészséget megkárosító szerződésszegésre."
                ]
            ),
            Section(
                title: "Módosítás és megszűnés",
                paragraphs: [
                    "A szolgáltatást és e feltételeket módosíthatjuk. Lényeges változás után egy új fordításhoz ismételt, aktív elfogadás kell; az üres vagy előre kijelölt jelölőnégyzetet soha nem tekintjük elfogadásnak.",
                    "A fordítószolgáltatás használatát abbahagyhatod és a fiókodat törölheted. A szolgáltatást észszerű értesítéssel megszüntethetjük, a teljesített vásárlásokhoz kapcsolódó jogaid sérelme nélkül."
                ]
            ),
            Section(
                title: "Ami a NativReadé",
                paragraphs: [
                    "Az alkalmazás, a neve, a felülete, a formaterve és a forráskódja az üzemeltetőé. E feltételek személyes használati engedélyt adnak az alkalmazásra; ezekből semmit nem ruháznak át rád, és nem érintik a saját könyveiden, fordításaidon, kiemeléseiden és jegyzeteiden fennálló jogaidat."
                ]
            ),
            Section(
                title: "Irányadó jog, üzemeltető és kapcsolat",
                paragraphs: [
                    "A magyar jog irányadó, a lakóhelyed szerinti kötelező fogyasztóvédelem sérelme nélkül. Igénybe veheted a bíróságokat és a számodra elérhető, hatáskörrel rendelkező fogyasztói alternatív vitarendezési fórumot.",
                    "Az aktuális üzemeltető neve, postai címe, támogatási elérhetősége, a jogtulajdonosi bejelentés útja és e feltételek változtathatatlan archivált példánya az appból megnyitható NativRead jogi weboldalon található."
                ]
            )
        ],
        appleEULAExplanation: "Az alkalmazás használati engedélyére külön az Apple általános végfelhasználói licencszerződése vonatkozik, kivéve, ha az App Store-ban egyedi EULA szerepel.",
        appleEULALink: "Az Apple általános EULA-jának megnyitása"
    )
}
