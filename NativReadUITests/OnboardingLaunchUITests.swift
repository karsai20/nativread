import XCTest

/// Verifies the first-launch welcome: it appears when forced and is
/// absent (library shown directly) when skipped.
final class OnboardingLaunchUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    func testLaunchSplashAppearsWhenForced() {
        // Welcome is deliberately user-paced, so an older reader has time to
        // absorb the promise before choosing to continue.
        app.launchArguments = [
            "-resetSettings", "-forceOnboarding",
            "-seedSampleBook"
        ]
        app.launch()

        XCTAssertTrue(
            app.staticTexts["onboarding.wordmark"].waitForExistence(timeout: 6),
            "the brand wordmark should appear on first launch"
        )
        XCTAssertTrue(
            app.buttons["onboarding.welcome.start"]
                .waitForExistence(timeout: 4),
            "welcome should wait for an explicit, clearly labelled action"
        )
        XCTAssertTrue(app.staticTexts["onboarding.welcome.title"].exists)
    }

    func testLaunchSplashSkipped() {
        app.launchArguments = ["-resetLibrary", "-skipOnboarding", "-seedSampleBook"]
        app.launch()

        // The library must be present immediately, with no welcome wordmark.
        XCTAssertTrue(
            app.buttons["library.book.The Lantern of Aldebaran"]
                .waitForExistence(timeout: 10),
            "library should show directly when onboarding is skipped"
        )
        XCTAssertFalse(
            app.staticTexts["onboarding.wordmark"].exists,
            "splash wordmark must not appear when skipped"
        )
    }
}
