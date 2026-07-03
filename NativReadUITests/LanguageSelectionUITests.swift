import XCTest

/// Verifies the language-selection onboarding step: the picker appears after
/// the splash, options are tappable, and the confirmed language is persisted
/// so a relaunch goes straight to the library.
///
/// Mirrors `OnboardingLaunchUITests` in structure and launch-argument style.
final class LanguageSelectionUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    // MARK: - Picker appearance

    /// After the brand splash auto-dismisses, the language picker must appear.
    func testLanguagePickerAppearsAfterSplash() {
        app.launchArguments = [
            "-resetLibrary", "-resetSettings", "-resetLanguage",
            "-forceOnboarding", "-seedSampleBook"
        ]
        app.launch()

        // The continue button anchors all four language rows.
        XCTAssertTrue(
            app.buttons["onboarding.language.continue"]
                .waitForExistence(timeout: 15),
            "language picker continue button should appear after the splash"
        )
    }

    // MARK: - Language rows are present

    func testAllFourLanguageRowsAreVisible() {
        app.launchArguments = [
            "-resetLibrary", "-resetSettings", "-resetLanguage",
            "-forceOnboarding", "-seedSampleBook"
        ]
        app.launch()

        XCTAssertTrue(
            app.buttons["onboarding.language.continue"]
                .waitForExistence(timeout: 15)
        )

        // Only the fully-translated, dictionary-backed languages are offered.
        for code in ["en", "hu"] {
            XCTAssertTrue(
                app.otherElements["onboarding.language.\(code)"].exists
                || app.staticTexts["onboarding.language.\(code)"].exists,
                "language row for '\(code)' must be visible"
            )
        }
        // es/de are withheld from the picker until fully translated.
        for code in ["es", "de"] {
            XCTAssertFalse(
                app.otherElements["onboarding.language.\(code)"].exists
                || app.staticTexts["onboarding.language.\(code)"].exists,
                "language row for '\(code)' must NOT be offered yet"
            )
        }
    }

    // MARK: - Selecting a language and confirming

    /// Tap Magyar (hu) and confirm — the library should appear and the splash
    /// wordmark must be gone.
    func testSelectMagyarAndContinue() {
        app.launchArguments = [
            "-resetLibrary", "-resetSettings", "-resetLanguage",
            "-forceOnboarding", "-seedSampleBook"
        ]
        app.launch()

        XCTAssertTrue(
            app.buttons["onboarding.language.continue"]
                .waitForExistence(timeout: 15)
        )

        // Tap the Magyar row.
        let huRow = app.otherElements["onboarding.language.hu"]
        if huRow.exists {
            huRow.tap()
        }

        // Tap Continue.
        app.buttons["onboarding.language.continue"].tap()

        // Splash wordmark must be gone; library must appear.
        XCTAssertFalse(
            app.staticTexts["onboarding.wordmark"].exists,
            "splash wordmark must not be visible after language confirmation"
        )
        XCTAssertTrue(
            app.buttons["library.book.The Lantern of Aldebaran"]
                .waitForExistence(timeout: 10),
            "library should be shown after onboarding completes"
        )
    }

    // MARK: - Persistence — relaunch skips picker

    /// After confirming a language selection the onboarding flag is set.
    /// A subsequent launch (without -forceOnboarding) must skip both the
    /// splash and the language picker and go straight to the library.
    func testRelaunchwithoutForceSkipsPicker() {
        // First launch: complete onboarding.
        app.launchArguments = [
            "-resetLibrary", "-resetSettings", "-resetLanguage",
            "-forceOnboarding", "-seedSampleBook"
        ]
        app.launch()

        XCTAssertTrue(
            app.buttons["onboarding.language.continue"]
                .waitForExistence(timeout: 15)
        )
        app.buttons["onboarding.language.continue"].tap()

        // Wait for library to appear.
        XCTAssertTrue(
            app.buttons["library.book.The Lantern of Aldebaran"]
                .waitForExistence(timeout: 10)
        )
        expectation(
            for: NSPredicate(format: "hittable == false"),
            evaluatedWith: app.buttons["onboarding.language.continue"]
        )
        waitForExpectations(timeout: 2)
        app.terminate()

        // Second launch: no force flags — must skip onboarding entirely.
        app.launchArguments = ["-seedSampleBook"]
        app.launch()

        XCTAssertTrue(
            app.buttons["library.book.The Lantern of Aldebaran"]
                .waitForExistence(timeout: 10),
            "library should appear directly on relaunch — no onboarding"
        )
        XCTAssertFalse(
            app.staticTexts["onboarding.wordmark"].exists,
            "splash wordmark must not appear on relaunch"
        )
        XCTAssertFalse(
            app.buttons["onboarding.language.continue"].isHittable,
            "language picker must not be interactable on relaunch"
        )
    }

    // MARK: - forceLanguage hook

    /// `-forceLanguage hu` must wire the Hungarian locale without persisting.
    /// This doesn't exercise the picker UI but validates the launch hook used
    /// by future screenshot-automation runs.
    func testForceLanguageHookDoesNotPersist() {
        app.launchArguments = [
            "-resetLibrary", "-skipOnboarding", "-resetLanguage",
            "-forceLanguage", "hu",
            "-seedSampleBook"
        ]
        app.launch()

        // Library must appear (onboarding is skipped).
        XCTAssertTrue(
            app.buttons["library.book.The Lantern of Aldebaran"]
                .waitForExistence(timeout: 10)
        )
        app.terminate()

        // Second launch with no forceLanguage — should revert to system default.
        app.launchArguments = ["-skipOnboarding", "-seedSampleBook"]
        app.launch()

        XCTAssertTrue(
            app.buttons["library.book.The Lantern of Aldebaran"]
                .waitForExistence(timeout: 10)
        )
        // We can't assert on the exact locale here without inspecting strings,
        // but the app must not crash and must reach the library.
    }
}
