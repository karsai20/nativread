import XCTest

/// Sheet-chrome contract: Settings closes with a single X button in its
/// in-content header.
final class SheetChromeUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    func testSettingsSheetShowsHeaderCloseButton() {
        app.launchArguments = [
            "-resetLibrary", "-resetSettings", "-skipOnboarding",
            "-seedSampleBook"
        ]
        app.launch()

        XCTAssertTrue(
            app.buttons["library.settings"].waitForExistence(timeout: 15)
        )
        app.buttons["library.settings"].tap()

        let close = app.buttons["settings.close"]
        XCTAssertTrue(
            close.waitForExistence(timeout: 10),
            "settings sheet must show the header close (X) button"
        )

        close.tap()
        XCTAssertTrue(
            app.buttons["library.settings"].waitForExistence(timeout: 5),
            "tapping X must dismiss the settings sheet"
        )
    }

    func testSettingsOpensPrivacyPolicy() {
        app.launchArguments = [
            "-resetLibrary", "-resetSettings", "-skipOnboarding",
            "-seedSampleBook"
        ]
        app.launch()

        XCTAssertTrue(
            app.buttons["library.settings"].waitForExistence(timeout: 15)
        )
        app.buttons["library.settings"].tap()

        let privacy = app.buttons["settings.privacy.link"]
        for _ in 0..<4 where !privacy.isHittable {
            app.swipeUp(velocity: .fast)
        }
        XCTAssertTrue(privacy.waitForExistence(timeout: 6))
        privacy.tap()
        XCTAssertTrue(
            app.scrollViews["privacy.screen"].waitForExistence(timeout: 6)
        )
    }

    func testSignedInAccountCanInitiateDeletionInSettings() {
        app.launchArguments = [
            "-resetLibrary", "-resetSettings", "-skipOnboarding",
            "-seedSampleBook", "-translationBackendURL",
            "https://backend.example", "-translationSessionToken",
            "ui-test-session"
        ]
        app.launch()

        XCTAssertTrue(
            app.buttons["library.settings"].waitForExistence(timeout: 15)
        )
        app.buttons["library.settings"].tap()

        let delete = app.buttons["settings.account.delete"]
        for _ in 0..<4 where !delete.isHittable {
            app.swipeUp(velocity: .fast)
        }
        XCTAssertTrue(delete.waitForExistence(timeout: 6))
        delete.tap()
        XCTAssertTrue(
            app.alerts["Delete account?"].waitForExistence(timeout: 6)
        )
        app.alerts.buttons["Delete Account"].tap()
        XCTAssertTrue(
            app.otherElements["settings.account.authorization"]
                .waitForExistence(timeout: 6)
        )
        XCTAssertTrue(app.buttons["settings.account.confirmWithApple"].exists)
        app.buttons["Cancel"].tap()
    }
}
