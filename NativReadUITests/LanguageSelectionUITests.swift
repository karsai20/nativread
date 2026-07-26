import XCTest

/// Verifies the language-aware first-run experience. The iPhone language is
/// suggested automatically, while English and Magyar remain visible directly
/// on the welcome screen so the user can confirm or change it immediately.
final class LanguageSelectionUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
        super.tearDown()
    }

    private var baseArguments: [String] {
        [
            "-resetLibrary", "-resetSettings", "-resetLanguage",
            "-forceOnboarding", "-seedSampleBook"
        ]
    }

    private func launchOnboarding(extraArguments: [String] = []) {
        app.launchArguments = baseArguments + extraArguments
        app.launch()
    }

    private func openTour(language: String? = nil) {
        if let language {
            let languageButton = app.buttons[
                "onboarding.welcome.language.\(language)"
            ]
            XCTAssertTrue(languageButton.waitForExistence(timeout: 10))
            languageButton.tap()
        }

        let start = app.buttons["onboarding.welcome.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        start.tap()
        XCTAssertTrue(
            app.buttons["onboarding.tour.next"].waitForExistence(timeout: 8)
        )
    }

    private func completeTour() {
        let next = app.buttons["onboarding.tour.next"]
        XCTAssertTrue(next.waitForExistence(timeout: 8))
        next.tap()

        let progress = app.staticTexts["onboarding.tour.progress"]
        expectation(
            for: NSPredicate(format: "label CONTAINS '2'"),
            evaluatedWith: progress
        )
        waitForExpectations(timeout: 4)
        next.tap()

        let finish = app.buttons["onboarding.tour.finish"]
        XCTAssertTrue(finish.waitForExistence(timeout: 5))
        finish.tap()
    }

    private func keepScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testLanguageChoiceIsEmbeddedInWelcome() {
        launchOnboarding(extraArguments: ["-forceLanguage", "en"])

        XCTAssertTrue(
            app.staticTexts["onboarding.welcome.title"]
                .waitForExistence(timeout: 10)
        )
        XCTAssertTrue(
            app.buttons["onboarding.welcome.language.en"].exists
        )
        XCTAssertTrue(
            app.buttons["onboarding.welcome.language.hu"].exists
        )
        XCTAssertFalse(
            app.buttons["onboarding.language.continue"].exists,
            "there must be no separate language screen"
        )

        app.buttons["onboarding.welcome.language.hu"].tap()
        let start = app.buttons["onboarding.welcome.start"]
        expectation(
            for: NSPredicate(format: "label == %@", "Mutasd, hogyan működik"),
            evaluatedWith: start
        )
        waitForExpectations(timeout: 5)
    }

    func testDeviceLanguageStartsWelcomeInHungarian() {
        launchOnboarding(extraArguments: [
            "-AppleLanguages", "(hu)",
            "-AppleLocale", "hu_HU"
        ])

        let title = app.staticTexts["onboarding.welcome.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertEqual(
            title.label,
            "A könyveid, mostantól a saját nyelveden."
        )
        XCTAssertEqual(
            app.buttons["onboarding.welcome.start"].label,
            "Mutasd, hogyan működik"
        )
        XCTAssertTrue(
            app.buttons["onboarding.welcome.language.hu"].exists
        )
    }

    func testOnlyFullyLocalizedLanguagesAreOffered() {
        launchOnboarding()

        for code in ["en", "hu"] {
            XCTAssertTrue(
                app.buttons["onboarding.welcome.language.\(code)"]
                    .waitForExistence(timeout: 10),
                "language choice for '\(code)' must be visible"
            )
        }
        for code in ["es", "de"] {
            XCTAssertFalse(
                app.buttons["onboarding.welcome.language.\(code)"].exists,
                "incomplete language '\(code)' must not be offered"
            )
        }
    }

    func testWalkthroughExplainsTheThreeCoreSteps() {
        launchOnboarding(extraArguments: ["-forceLanguage", "en"])
        openTour(language: "en")

        let title = app.staticTexts["onboarding.tour.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 8))
        XCTAssertEqual(title.label, "Choose a book from your iPhone")
        keepScreenshot("onboarding-01-add-book")

        app.buttons["onboarding.tour.next"].tap()
        expectation(
            for: NSPredicate(
                format: "label == %@",
                "Let NativRead bring it into your language"
            ),
            evaluatedWith: title
        )
        waitForExpectations(timeout: 5)
        keepScreenshot("onboarding-02-translate")

        app.buttons["onboarding.tour.next"].tap()
        expectation(
            for: NSPredicate(
                format: "label == %@",
                "Read in comfort, at your own pace"
            ),
            evaluatedWith: title
        )
        waitForExpectations(timeout: 5)
        keepScreenshot("onboarding-03-read")
        XCTAssertTrue(
            app.buttons["onboarding.tour.finish"].waitForExistence(timeout: 4)
        )
    }

    func testTourBackReturnsToLanguageAwareWelcome() {
        launchOnboarding(extraArguments: ["-forceLanguage", "en"])
        openTour(language: "hu")

        app.buttons["onboarding.tour.back"].tap()

        let title = app.staticTexts["onboarding.welcome.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 8))
        XCTAssertEqual(
            title.label,
            "A könyveid, mostantól a saját nyelveden."
        )
        XCTAssertTrue(
            app.buttons["onboarding.welcome.language.hu"].exists
        )
    }

    func testOnboardingRemainsUsableInLandscape() {
        launchOnboarding()
        XCUIDevice.shared.orientation = .landscapeLeft

        XCTAssertGreaterThan(app.frame.width, app.frame.height)
        XCTAssertTrue(
            app.buttons["onboarding.welcome.language.hu"]
                .waitForExistence(timeout: 10)
        )

        let start = app.buttons["onboarding.welcome.start"]
        XCTAssertTrue(start.isHittable)
        start.tap()

        let next = app.buttons["onboarding.tour.next"]
        XCTAssertTrue(next.waitForExistence(timeout: 8))
        let title = app.staticTexts["onboarding.tour.title"]
        XCTAssertTrue(title.exists)
        XCTAssertGreaterThan(
            title.frame.minX,
            app.frame.midX,
            "landscape should place the explanation beside the illustration"
        )
        XCTAssertTrue(next.isHittable)
    }

    func testOnboardingRemainsUsableWithAccessibilityText() {
        launchOnboarding(extraArguments: [
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXL"
        ])

        let hungarian = app.buttons["onboarding.welcome.language.hu"]
        XCTAssertTrue(hungarian.waitForExistence(timeout: 10))
        XCTAssertTrue(hungarian.isHittable)
        keepScreenshot("onboarding-accessibility-welcome")
        hungarian.tap()

        let start = app.buttons["onboarding.welcome.start"]
        XCTAssertTrue(start.isHittable)
        start.tap()

        let next = app.buttons["onboarding.tour.next"]
        XCTAssertTrue(next.waitForExistence(timeout: 8))
        XCTAssertTrue(next.isHittable)
        keepScreenshot("onboarding-accessibility-text")
    }

    func testSelectMagyarAndContinue() {
        launchOnboarding(extraArguments: ["-forceLanguage", "en"])
        openTour(language: "hu")
        completeTour()

        XCTAssertFalse(
            app.staticTexts["onboarding.wordmark"].exists,
            "welcome must be gone after onboarding completes"
        )
        XCTAssertTrue(
            app.buttons["library.book.The Lantern of Aldebaran"]
                .waitForExistence(timeout: 10),
            "library should be shown after onboarding completes"
        )
    }

    func testRelaunchWithoutForceSkipsOnboarding() {
        launchOnboarding()
        openTour()
        completeTour()

        XCTAssertTrue(
            app.buttons["library.book.The Lantern of Aldebaran"]
                .waitForExistence(timeout: 10)
        )
        app.terminate()

        app.launchArguments = ["-seedSampleBook"]
        app.launch()

        XCTAssertTrue(
            app.buttons["library.book.The Lantern of Aldebaran"]
                .waitForExistence(timeout: 10)
        )
        XCTAssertFalse(app.staticTexts["onboarding.wordmark"].exists)
        XCTAssertFalse(
            app.buttons["onboarding.welcome.language.hu"].exists
        )
    }

    func testForceLanguageHookDoesNotPersist() {
        app.launchArguments = [
            "-resetLibrary", "-skipOnboarding", "-resetLanguage",
            "-forceLanguage", "hu", "-seedSampleBook"
        ]
        app.launch()

        XCTAssertTrue(
            app.buttons["library.book.The Lantern of Aldebaran"]
                .waitForExistence(timeout: 10)
        )
        app.terminate()

        app.launchArguments = ["-skipOnboarding", "-seedSampleBook"]
        app.launch()
        XCTAssertTrue(
            app.buttons["library.book.The Lantern of Aldebaran"]
                .waitForExistence(timeout: 10)
        )
    }
}
