import XCTest
@testable import NativRead

/// Covers the first-launch onboarding-seen flag persisted alongside (but
/// separate from) the codable reader settings.
final class SettingsStoreOnboardingTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "onboarding.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testOnboardingNotSeenByDefault() {
        let store = SettingsStore(defaults: defaults)
        XCTAssertFalse(store.hasSeenOnboarding)
    }

    func testMarkOnboardingSeenPersists() {
        let store = SettingsStore(defaults: defaults)
        store.markOnboardingSeen()
        XCTAssertTrue(store.hasSeenOnboarding)

        // A fresh store backed by the same defaults must still see it.
        let reloaded = SettingsStore(defaults: defaults)
        XCTAssertTrue(reloaded.hasSeenOnboarding)
    }

    func testResetPersistedClearsOnboarding() {
        let store = SettingsStore(defaults: defaults)
        store.markOnboardingSeen()
        XCTAssertTrue(store.hasSeenOnboarding)

        SettingsStore.resetPersisted(in: defaults)

        let reloaded = SettingsStore(defaults: defaults)
        XCTAssertFalse(reloaded.hasSeenOnboarding)
    }

    func testTranslationBackendURLPersistsAndTrimsWhitespace() {
        let store = SettingsStore(
            defaults: defaults,
            defaultTranslationBackendURLString: ""
        )
        store.setTranslationBackendURL("  http://127.0.0.1:48218  ")

        let reloaded = SettingsStore(
            defaults: defaults,
            defaultTranslationBackendURLString: ""
        )
        XCTAssertEqual(
            reloaded.translationBackendURLString,
            "http://127.0.0.1:48218"
        )
        XCTAssertEqual(
            reloaded.translationBackendURL?.absoluteString,
            "http://127.0.0.1:48218"
        )
    }

    func testResetPersistedClearsTranslationBackendURL() {
        let store = SettingsStore(
            defaults: defaults,
            defaultTranslationBackendURLString: ""
        )
        store.setTranslationBackendURL("http://127.0.0.1:48218")

        SettingsStore.resetPersisted(in: defaults)

        let reloaded = SettingsStore(
            defaults: defaults,
            defaultTranslationBackendURLString: ""
        )
        XCTAssertEqual(reloaded.translationBackendURLString, "")
        XCTAssertNil(reloaded.translationBackendURL)
    }

    func testTranslationBackendURLUsesConfiguredDefault() {
        let store = SettingsStore(
            defaults: defaults,
            defaultTranslationBackendURLString: "  http://127.0.0.1:48218  "
        )

        XCTAssertEqual(
            store.translationBackendURLString,
            "http://127.0.0.1:48218"
        )
        XCTAssertEqual(
            store.translationBackendURL?.absoluteString,
            "http://127.0.0.1:48218"
        )
    }
}
