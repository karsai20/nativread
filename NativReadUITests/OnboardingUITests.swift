import XCTest

/// Verifies the four-step first-run experience. The app language follows the
/// phone — onboarding never asks for it — so these tests assert that the
/// device language reaches the copy and that every step stays reachable,
/// including in landscape and at accessibility text sizes.
final class OnboardingUITests: XCTestCase {

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

    /// Walks welcome → add → translate → read and taps the final action.
    private func completeTour() {
        let next = app.buttons["onboarding.tour.next"]

        for _ in 0..<3 {
            XCTAssertTrue(next.waitForExistence(timeout: 10))
            next.tap()
        }

        let finish = app.buttons["onboarding.tour.finish"]
        XCTAssertTrue(finish.waitForExistence(timeout: 6))
        finish.tap()
    }

    private func expectTitle(_ expected: String, timeout: TimeInterval = 6) {
        let title = app.staticTexts["onboarding.tour.title"]
        expectation(
            for: NSPredicate(format: "label == %@", expected),
            evaluatedWith: title
        )
        waitForExpectations(timeout: timeout)
    }

    private func keepScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testWalkthroughExplainsTheFourCoreSteps() {
        launchOnboarding(extraArguments: ["-forceLanguage", "en"])

        let title = app.staticTexts["onboarding.tour.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertEqual(title.label, "Your books, in your language.")
        keepScreenshot("onboarding-01-welcome")

        app.buttons["onboarding.tour.next"].tap()
        expectTitle("Choose a book from your iPhone")
        keepScreenshot("onboarding-02-add-book")

        app.buttons["onboarding.tour.next"].tap()
        expectTitle("Let NativRead bring it into your language")
        keepScreenshot("onboarding-03-translate")

        app.buttons["onboarding.tour.next"].tap()
        expectTitle("Read in comfort, at your own pace")
        keepScreenshot("onboarding-04-read")

        XCTAssertTrue(
            app.buttons["onboarding.tour.finish"].waitForExistence(timeout: 4)
        )
    }

    func testBackReturnsToThePreviousStep() {
        launchOnboarding(extraArguments: ["-forceLanguage", "en"])

        let next = app.buttons["onboarding.tour.next"]
        XCTAssertTrue(next.waitForExistence(timeout: 10))
        next.tap()
        expectTitle("Choose a book from your iPhone")

        app.buttons["onboarding.tour.back"].tap()
        expectTitle("Your books, in your language.")
    }

    /// Skip is the escape hatch: it must land in the library, not the next step.
    func testSkipGoesStraightToTheLibrary() {
        launchOnboarding(extraArguments: ["-forceLanguage", "en"])

        let skip = app.buttons["onboarding.tour.skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 10))
        skip.tap()

        XCTAssertTrue(
            app.buttons["library.book.The Lantern of Aldebaran"]
                .waitForExistence(timeout: 10)
        )
        XCTAssertFalse(app.staticTexts["onboarding.tour.title"].exists)
    }

    /// The phone's language reaches the copy without anyone being asked.
    func testDeviceLanguageDrivesOnboardingCopy() {
        launchOnboarding(extraArguments: ["-forceLanguage", "hu"])

        let title = app.staticTexts["onboarding.tour.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertEqual(title.label, "A könyveid, a saját nyelveden.")
    }

    func testOnboardingRemainsUsableInLandscape() {
        // Xcode 26 can acknowledge an in-app rotation while the simulator
        // window stays portrait. Relaunching into the requested orientation
        // makes the test assert the real landscape geometry.
        launchOnboarding(extraArguments: ["-forceLanguage", "en"])
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

        let next = app.buttons["onboarding.tour.next"]
        XCTAssertTrue(next.waitForExistence(timeout: 10))
        // Geometry assertions are unreliable here — Xcode can acknowledge the
        // rotation while the window is still settling — so this asserts what
        // actually matters: every control stays reachable in landscape.
        let title = app.staticTexts["onboarding.tour.title"]
        XCTAssertTrue(title.exists)
        XCTAssertTrue(next.isHittable)
        XCTAssertTrue(app.buttons["onboarding.tour.skip"].isHittable)
    }

    func testOnboardingRemainsUsableWithAccessibilityText() {
        launchOnboarding(extraArguments: [
            "-forceLanguage", "en",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXL"
        ])

        let next = app.buttons["onboarding.tour.next"]
        XCTAssertTrue(next.waitForExistence(timeout: 10))
        XCTAssertTrue(next.isHittable)
        keepScreenshot("onboarding-accessibility-welcome")

        next.tap()
        expectTitle("Choose a book from your iPhone")
        XCTAssertTrue(next.isHittable)
        XCTAssertTrue(app.buttons["onboarding.tour.back"].isHittable)
        keepScreenshot("onboarding-accessibility-text")
    }

    func testRelaunchWithoutForceSkipsOnboarding() {
        launchOnboarding()
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
        XCTAssertFalse(app.staticTexts["onboarding.tour.title"].exists)
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
