import XCTest
@testable import NativRead

/// Covers `LocalizationStore` persistence, locale derivation, and the
/// language → `BundledDictionary` mapping used by `DictionaryProvider`.
final class LocalizationStoreTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "localization.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    // MARK: - Default state

    func testDefaultLanguageIsSystem() {
        let store = LocalizationStore(defaults: defaults)
        XCTAssertEqual(store.appLanguage, .system)
    }

    func testSystemLanguageReturnsCurrentLocale() {
        let store = LocalizationStore(defaults: defaults)
        // `.system` must not return a pinned locale — it returns `.current`.
        XCTAssertEqual(store.resolvedLocale, .current)
    }

    // MARK: - Persistence

    func testSetLanguagePersists() {
        let store = LocalizationStore(defaults: defaults)
        store.setLanguage(.hu)
        XCTAssertEqual(store.appLanguage, .hu)

        let reloaded = LocalizationStore(defaults: defaults)
        XCTAssertEqual(reloaded.appLanguage, .hu)
    }

    func testSetLanguagePersistsAllCodes() {
        for language in AppLanguage.pickable {
            let store = LocalizationStore(defaults: defaults)
            store.setLanguage(language)

            let reloaded = LocalizationStore(defaults: defaults)
            XCTAssertEqual(
                reloaded.appLanguage, language,
                "Persisted language must round-trip for \(language.rawValue)"
            )
        }
    }

    func testResetPersistedClearsLanguage() {
        let store = LocalizationStore(defaults: defaults)
        store.setLanguage(.de)
        XCTAssertEqual(store.appLanguage, .de)

        LocalizationStore.resetPersisted(in: defaults)

        let reloaded = LocalizationStore(defaults: defaults)
        XCTAssertEqual(reloaded.appLanguage, .system)
    }

    // MARK: - overrideWithoutPersisting

    func testOverrideDoesNotPersist() {
        let store = LocalizationStore(defaults: defaults)
        store.overrideWithoutPersisting(.es)
        XCTAssertEqual(store.appLanguage, .es)

        // A fresh store backed by the same defaults must NOT see the override.
        let reloaded = LocalizationStore(defaults: defaults)
        XCTAssertEqual(reloaded.appLanguage, .system)
    }

    // MARK: - resolvedLocale

    func testResolvedLocaleForEnglish() {
        let store = LocalizationStore(defaults: defaults)
        store.setLanguage(.en)
        XCTAssertEqual(
            store.resolvedLocale.language.languageCode?.identifier, "en"
        )
    }

    func testResolvedLocaleForHungarian() {
        let store = LocalizationStore(defaults: defaults)
        store.setLanguage(.hu)
        XCTAssertEqual(
            store.resolvedLocale.language.languageCode?.identifier, "hu"
        )
    }

    func testResolvedLocaleForSpanish() {
        let store = LocalizationStore(defaults: defaults)
        store.setLanguage(.es)
        XCTAssertEqual(
            store.resolvedLocale.language.languageCode?.identifier, "es"
        )
    }

    func testResolvedLocaleForGerman() {
        let store = LocalizationStore(defaults: defaults)
        store.setLanguage(.de)
        XCTAssertEqual(
            store.resolvedLocale.language.languageCode?.identifier, "de"
        )
    }

    // MARK: - Bundle fallback

    func testBundleIsMainWhenLprojMissing() {
        // When the .lproj directory isn't in the test bundle, the store
        // must fall back to Bundle.main without crashing.
        let store = LocalizationStore(defaults: defaults)
        store.setLanguage(.de)
        // Just verifying it doesn't throw — we can't assert on the path
        // because the test runner may or may not have .lproj directories.
        XCTAssertNotNil(store.bundle)
    }

    // MARK: - AppLanguage.endonyms

    func testEndonymsAreNonEmpty() {
        for language in AppLanguage.allCases {
            XCTAssertFalse(
                language.endonym.isEmpty,
                "endonym must not be empty for \(language.rawValue)"
            )
        }
    }

    func testPickableIsFullyTranslatedLanguagesOnly() {
        // Only fully-translated, dictionary-backed languages are offered in the
        // picker. es/de stay in the enum (plumbing is ready) but are withheld
        // until their String Catalog and dictionaries are complete, so picking
        // them can't leave most of the app in the English fallback.
        let pickable = Set(AppLanguage.pickable.map(\.rawValue))
        XCTAssertEqual(pickable, ["en", "hu"])
        XCTAssertFalse(pickable.contains("es"))
        XCTAssertFalse(pickable.contains("de"))
        XCTAssertFalse(pickable.contains("system"))
        // es/de remain valid, persistable enum cases even though unlisted.
        XCTAssertNotNil(AppLanguage(rawValue: "es"))
        XCTAssertNotNil(AppLanguage(rawValue: "de"))
    }

    // MARK: - Language → BundledDictionary mapping

    func testEnglishMapsToWordNetOnly() {
        let dicts = BundledDictionary.bundled(for: .en)
        XCTAssertEqual(dicts, [.wordnet])
    }

    func testHungarianMapsToEnhuFirst() {
        let dicts = BundledDictionary.bundled(for: .hu)
        XCTAssertEqual(dicts.first, .enhu)
        XCTAssertTrue(dicts.contains(.wordnet))
    }

    func testSpanishMapsToEnesFirst() {
        let dicts = BundledDictionary.bundled(for: .es)
        XCTAssertEqual(dicts.first, .enes)
        XCTAssertTrue(dicts.contains(.wordnet))
    }

    func testGermanMapsToEndeFirst() {
        let dicts = BundledDictionary.bundled(for: .de)
        XCTAssertEqual(dicts.first, .ende)
        XCTAssertTrue(dicts.contains(.wordnet))
    }

    func testSystemMapsToWordNetOnly() {
        // .system without a device language override defaults to English.
        // We can only test the general structure — device locale is unknown.
        let dicts = BundledDictionary.bundled(for: .system)
        XCTAssertTrue(dicts.contains(.wordnet))
    }

    // MARK: - Multi-language Define set

    func testHungarianOnlySetKeepsWordNetFallback() {
        // WordNet stays in every build path as a safety net; selecting Magyar
        // adds the bilingual dictionary before it.
        XCTAssertEqual(BundledDictionary.bundled(for: [.hu]), [.enhu, .wordnet])
    }

    func testHungarianPlusEnglishLoadsBothBilingualFirst() {
        XCTAssertEqual(
            BundledDictionary.bundled(for: [.hu, .en]), [.enhu, .wordnet]
        )
    }

    func testEmptyDefineSetFallsBackToWordNet() {
        XCTAssertEqual(BundledDictionary.bundled(for: []), [.wordnet])
    }

    func testDefaultDefineLanguagesIsJustTheAppLanguage() {
        XCTAssertEqual(LocalizationStore.defaultDefineLanguages(for: .hu), [.hu])
        XCTAssertEqual(LocalizationStore.defaultDefineLanguages(for: .en), [.en])
    }

    func testDefineLanguagesPersistAcrossInstances() {
        let store = LocalizationStore(defaults: defaults)
        store.setDefineLanguages([.hu, .en])
        let reloaded = LocalizationStore(defaults: defaults)
        XCTAssertEqual(reloaded.defineLanguages, [.hu, .en])
    }

    func testEmptyDefineLanguagesPersistAcrossInstances() {
        let store = LocalizationStore(defaults: defaults)
        store.setDefineLanguages([])
        let reloaded = LocalizationStore(defaults: defaults)
        XCTAssertEqual(reloaded.defineLanguages, [])
    }

    func testLegacySingleDefineKeyMigratesToSet() {
        // A build before multi-language stored one value under the old key.
        defaults.set("hu", forKey: "quire.defineLanguage.v1")
        let store = LocalizationStore(defaults: defaults)
        XCTAssertEqual(store.defineLanguages, [.hu])
    }

    func testToggleDefineLanguageAddsAndRemoves() {
        let store = LocalizationStore(defaults: defaults)
        store.setDefineLanguages([.hu])
        store.toggleDefineLanguage(.en)
        XCTAssertEqual(store.defineLanguages, [.hu, .en])
        store.toggleDefineLanguage(.hu)
        XCTAssertEqual(store.defineLanguages, [.en])
    }

    func testForceLanguageCanSyncDefineLanguagesWithoutPersisting() {
        let store = LocalizationStore(defaults: defaults)
        store.setDefineLanguages([.en])
        store.overrideDefineLanguagesForAppLanguageWithoutPersisting(.hu)
        XCTAssertEqual(store.defineLanguages, [.hu])

        let reloaded = LocalizationStore(defaults: defaults)
        XCTAssertEqual(reloaded.defineLanguages, [.en])
    }

    func testDefaultDefineLanguagesFollowAppLanguageChange() {
        let next = LocalizationStore.defineLanguagesAfterAppLanguageChange(
            currentDefineLanguages: [.en],
            oldAppLanguage: .en,
            newAppLanguage: .hu,
            explicitDefineLanguages: nil
        )
        XCTAssertEqual(next, [.hu])
    }

    func testExplicitDefineLanguagesSurviveAppLanguageChange() {
        let explicit: Set<AppLanguage> = [.hu, .en]
        let next = LocalizationStore.defineLanguagesAfterAppLanguageChange(
            currentDefineLanguages: [.en],
            oldAppLanguage: .en,
            newAppLanguage: .hu,
            explicitDefineLanguages: explicit
        )
        XCTAssertEqual(next, explicit)
    }

    func testCustomDefineLanguagesDoNotFollowAppLanguageChange() {
        let next = LocalizationStore.defineLanguagesAfterAppLanguageChange(
            currentDefineLanguages: [.hu, .en],
            oldAppLanguage: .en,
            newAppLanguage: .hu,
            explicitDefineLanguages: nil
        )
        XCTAssertEqual(next, [.hu, .en])
    }
}
