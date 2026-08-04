import XCTest

/// Verifies the two-step welcome: the promise, then the reading-mode choice.
/// The app language follows the phone — welcome never asks for it — so these
/// tests assert that the device language reaches the copy and that both
/// actions stay reachable, including in landscape and at accessibility sizes.
final class OnboardingUITests: XCTestCase {

    private var app: XCUIApplication!

    private static let headline = "Read in any language."
    private static let hungarianHeadline = "Olvass bármilyen nyelven."

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

    private func launchWelcome(extraArguments: [String] = []) {
        app.launchArguments = baseArguments + extraArguments
        app.launch()
    }

    /// The continue button fades in as the last reveal stage, so wait for it
    /// to be hittable, not merely present.
    private func tapContinue() {
        let button = app.buttons["welcome.continue"]
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        let hittable = NSPredicate(format: "isHittable == true")
        expectation(for: hittable, evaluatedWith: button)
        waitForExpectations(timeout: 10)
        button.tap()
    }

    /// Walks both steps: promise -> reading mode -> shelf.
    private func completeWelcome() {
        tapContinue()
        let finish = app.buttons["welcome.finish"]
        XCTAssertTrue(finish.waitForExistence(timeout: 6))
        finish.tap()
    }

    private func keepScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testWelcomeShowsHeadlineAndValueLine() {
        launchWelcome(extraArguments: ["-forceLanguage", "en"])

        let title = app.staticTexts["welcome.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertEqual(title.label, Self.headline)
        XCTAssertTrue(
            app.staticTexts["welcome.subtitle"].waitForExistence(timeout: 6)
        )
        keepScreenshot("welcome")
    }

    func testContinueLandsInTheLibrary() {
        launchWelcome(extraArguments: ["-forceLanguage", "en"])
        completeWelcome()

        XCTAssertTrue(
            app.buttons["library.book.The Lantern of Aldebaran"]
                .waitForExistence(timeout: 10)
        )
        XCTAssertFalse(app.staticTexts["welcome.title"].exists)
    }

    /// The phone's language reaches the copy without anyone being asked.
    func testDeviceLanguageDrivesWelcomeCopy() {
        launchWelcome(extraArguments: ["-forceLanguage", "hu"])

        let title = app.staticTexts["welcome.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertEqual(title.label, Self.hungarianHeadline)
    }

    func testWelcomeRemainsUsableInLandscape() {
        // Xcode 26 can acknowledge an in-app rotation while the simulator
        // window stays portrait. Relaunching into the requested orientation
        // makes the test assert the real landscape geometry.
        launchWelcome(extraArguments: ["-forceLanguage", "en"])
        app.terminate()
        XCUIDevice.shared.orientation = .landscapeLeft
        app.launch()

        let window = app.windows.firstMatch
        let isLandscape = NSPredicate { object, _ in
            guard let element = object as? XCUIElement else { return false }
            return element.frame.width > element.frame.height
        }
        expectation(for: isLandscape, evaluatedWith: window)
        waitForExpectations(timeout: 10)

        let title = app.staticTexts["welcome.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        let button = app.buttons["welcome.continue"]
        let hittable = NSPredicate(format: "isHittable == true")
        expectation(for: hittable, evaluatedWith: button)
        waitForExpectations(timeout: 10)
    }

    /// At the largest text size the copy must stay clear of the bottom bar.
    func testCopyClearsTheContinueButtonAtAccessibilityText() {
        launchWelcome(extraArguments: [
            "-forceLanguage", "hu",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXL"
        ])

        let title = app.staticTexts["welcome.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))

        let button = app.buttons["welcome.continue"]
        let hittable = NSPredicate(format: "isHittable == true")
        expectation(for: hittable, evaluatedWith: button)
        waitForExpectations(timeout: 10)
        XCTAssertTrue(
            title.frame.maxY <= button.frame.minY,
            "the headline overlaps the continue button"
        )
        keepScreenshot("welcome-accessibility")
    }

    /// Step two is a real choice: picking Scroll must reach the reader's
    /// persisted settings, not merely decorate the welcome.
    func testReadingModeChoiceReachesTheReader() {
        launchWelcome(extraArguments: ["-forceLanguage", "en"])
        tapContinue()

        XCTAssertTrue(
            app.staticTexts["welcome.mode.title"].waitForExistence(timeout: 6)
        )
        let scroll = app.buttons["welcome.mode.scroll"]
        XCTAssertTrue(scroll.waitForExistence(timeout: 4))
        keepScreenshot("welcome-reading-mode")
        scroll.tap()
        app.buttons["welcome.finish"].tap()

        let book = app.buttons["library.book.The Lantern of Aldebaran"]
        XCTAssertTrue(book.waitForExistence(timeout: 10))
        book.tap()
        XCTAssertTrue(
            app.buttons["reader.position"].waitForExistence(timeout: 20)
        )

        let typography = app.buttons["reader.typography"]
        if !typography.isHittable { app.buttons["reader.menu"].tap() }
        XCTAssertTrue(typography.waitForExistence(timeout: 6))
        typography.tap()

        app.buttons["appearance.tab.layout"].tap()
        let scrollFlow = app.buttons["flow.scroll"]
        XCTAssertTrue(scrollFlow.waitForExistence(timeout: 6))
        XCTAssertTrue(
            scrollFlow.isSelected,
            "the welcome's Scroll choice should be the reader's page flow"
        )
    }

    /// Settings brings the welcome back without a relaunch.
    func testSettingsCanReplayTheWelcome() {
        app.launchArguments = [
            "-resetLibrary", "-resetSettings", "-resetLanguage",
            "-skipOnboarding", "-seedSampleBook", "-forceLanguage", "en"
        ]
        app.launch()

        XCTAssertTrue(
            app.buttons["library.book.The Lantern of Aldebaran"]
                .waitForExistence(timeout: 10)
        )
        app.tabButton(.settings).tap()

        let replay = app.buttons["settings.replayOnboarding"]
        XCTAssertTrue(replay.waitForExistence(timeout: 8))
        // The row sits at the bottom of a long sheet.
        for _ in 0..<6 where !replay.isHittable {
            app.swipeUp(velocity: .fast)
        }
        replay.tap()

        XCTAssertTrue(
            app.staticTexts["welcome.title"].waitForExistence(timeout: 6),
            "Show Welcome Again should re-present the flow in place"
        )
        completeWelcome()
        XCTAssertTrue(
            app.buttons["library.book.The Lantern of Aldebaran"]
                .waitForExistence(timeout: 10)
        )
    }

    func testRelaunchWithoutForceSkipsWelcome() {
        launchWelcome()
        completeWelcome()

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
        XCTAssertFalse(app.staticTexts["welcome.title"].exists)
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
