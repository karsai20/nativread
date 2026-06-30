import XCTest

/// Verifies the first-launch brand splash: it appears when forced and is
/// absent (library shown directly) when skipped.
final class OnboardingLaunchUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    func testLaunchSplashAppearsWhenForced() {
        // `-onboardingHold` keeps the splash on screen so the assertion can't
        // race the auto-dismiss crossfade (which fires as soon as the bundled
        // dictionaries are ready — often instantly on a warm simulator).
        app.launchArguments = [
            "-resetSettings", "-forceOnboarding", "-onboardingHold",
            "-seedSampleBook"
        ]
        app.launch()

        XCTAssertTrue(
            app.staticTexts["onboarding.wordmark"].waitForExistence(timeout: 6),
            "the brand wordmark should appear on first launch"
        )
    }

    func testLaunchSplashSkipped() {
        app.launchArguments = ["-resetLibrary", "-skipOnboarding", "-seedSampleBook"]
        app.launch()

        // The library must be present immediately, with no splash wordmark.
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
