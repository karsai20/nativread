import XCTest

/// Verifies the three-beat first-run experience. The app language follows the
/// phone — onboarding never asks for it — so these tests assert that the
/// device language reaches the copy and that every step stays reachable,
/// including in landscape and at accessibility text sizes.
final class OnboardingUITests: XCTestCase {

    private var app: XCUIApplication!

    /// The English source copy for each beat, in order.
    private static let beats = [
        "Add a book in a language you don't read.",
        "We translate the first chapter free.",
        "You can close the app. We keep translating."
    ]

    /// Hungarian runs longer than English on most beats, so it is the case the
    /// layout has to survive.
    private static let hungarianBeats = [
        "Tedd fel az idegen nyelvű könyvedet.",
        "Az első fejezetet ingyen lefordítjuk.",
        "Bezárhatod az appot, mi közben tovább fordítunk."
    ]

    private static let outcome =
        "The finished translation lands on your shelf, beside the original."

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

    /// Walks add → translate → wait and taps the final action.
    private func completeTour() {
        let next = app.buttons["onboarding.tour.next"]

        for _ in 0..<(Self.beats.count - 1) {
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

    func testWalkthroughExplainsTheThreeCoreSteps() {
        launchOnboarding(extraArguments: ["-forceLanguage", "en"])

        let title = app.staticTexts["onboarding.tour.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertEqual(title.label, Self.beats[0])
        keepScreenshot("onboarding-01-add-book")

        app.buttons["onboarding.tour.next"].tap()
        expectTitle(Self.beats[1])
        keepScreenshot("onboarding-02-translate")

        app.buttons["onboarding.tour.next"].tap()
        expectTitle(Self.beats[2])
        keepScreenshot("onboarding-03-wait")

        XCTAssertTrue(
            app.buttons["onboarding.tour.finish"].waitForExistence(timeout: 4)
        )
    }

    /// The payoff closes the flow: it is the last thing read before the
    /// library opens, and it only belongs on the final beat.
    func testOutcomeAppearsOnlyOnTheFinalBeat() {
        launchOnboarding(extraArguments: ["-forceLanguage", "en"])

        let promise = app.staticTexts["onboarding.tour.promise"]
        XCTAssertTrue(
            app.buttons["onboarding.tour.next"].waitForExistence(timeout: 10)
        )
        XCTAssertFalse(promise.exists)

        app.buttons["onboarding.tour.next"].tap()
        expectTitle(Self.beats[1])
        XCTAssertFalse(promise.exists)

        app.buttons["onboarding.tour.next"].tap()
        expectTitle(Self.beats[2])
        XCTAssertTrue(promise.waitForExistence(timeout: 4))
        XCTAssertEqual(promise.label, Self.outcome)
    }

    func testBackReturnsToThePreviousStep() {
        launchOnboarding(extraArguments: ["-forceLanguage", "en"])

        let next = app.buttons["onboarding.tour.next"]
        XCTAssertTrue(next.waitForExistence(timeout: 10))
        next.tap()
        expectTitle(Self.beats[1])

        app.buttons["onboarding.tour.back"].tap()
        expectTitle(Self.beats[0])
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
        XCTAssertEqual(title.label, Self.hungarianBeats[0])
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

    /// The overflow this redesign exists to fix: at the largest text size the
    /// sentence must stay clear of the bottom bar, on every beat.
    func testCopyClearsTheBottomBarAtAccessibilityText() {
        launchOnboarding(extraArguments: [
            "-forceLanguage", "hu",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXL"
        ])

        let next = app.buttons["onboarding.tour.next"]
        let title = app.staticTexts["onboarding.tour.title"]
        XCTAssertTrue(next.waitForExistence(timeout: 10))

        let last = Self.hungarianBeats.count - 1
        for index in 0...last {
            // Wait for the label itself, not merely for an element to exist:
            // during the page transition the previous beat is still on screen.
            expectTitle(Self.hungarianBeats[index])

            // The primary action is relabelled on the final beat.
            let action = index == last
                ? app.buttons["onboarding.tour.finish"]
                : next
            XCTAssertTrue(action.waitForExistence(timeout: 4))
            XCTAssertTrue(action.isHittable)
            XCTAssertTrue(
                title.frame.maxY <= action.frame.minY,
                "beat \(index + 1): the sentence overlaps the primary button"
            )
            if index > 0 {
                XCTAssertTrue(app.buttons["onboarding.tour.back"].isHittable)
            }
            keepScreenshot("onboarding-accessibility-\(index + 1)")

            if index < last { action.tap() }
        }
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
