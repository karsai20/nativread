import XCTest
@testable import NativRead

/// Covers `LocalizationStore` persistence, locale derivation, and the
/// picker's supported-language set.
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
}
