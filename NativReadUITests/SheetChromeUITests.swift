import XCTest

/// Settings is a tab destination, not a sheet: it is reached from the tab bar
/// and its pushed screens (privacy, account deletion) open from there.
final class SheetChromeUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    /// UIKit's tab bar does not carry the SwiftUI identifier set on a
    /// `tabItem`, and the labels are localised, so tabs are addressed by their
    /// fixed position: 0 Library, 1 Translate, 2 Settings.
    private enum Tab: Int {
        case library, translate, settings
    }

    private func tab(_ tab: Tab) -> XCUIElement {
        app.tabBars.buttons.element(boundBy: tab.rawValue)
    }

    /// Opens the Settings tab and returns once its content is on screen.
    private func openSettings() {
        let settings = tab(.settings)
        XCTAssertTrue(
            settings.waitForExistence(timeout: 15),
            "the tab bar must offer a Settings destination"
        )
        settings.tap()
        XCTAssertTrue(
            app.otherElements["settings.sheet"].waitForExistence(timeout: 10)
        )
    }

    func testSettingsIsReachableFromTheTabBar() {
        app.launchArguments = [
            "-resetLibrary", "-resetSettings", "-skipOnboarding",
            "-seedSampleBook", "-forceLanguage", "en"
        ]
        app.launch()

        openSettings()

        // Returning to the shelf is a tab switch, not a dismissal.
        tab(.library).tap()
        XCTAssertTrue(
            app.buttons["library.book.The Lantern of Aldebaran"]
                .waitForExistence(timeout: 10)
        )
    }

    func testSettingsOpensPrivacyPolicy() {
        app.launchArguments = [
            "-resetLibrary", "-resetSettings", "-skipOnboarding",
            "-seedSampleBook", "-forceLanguage", "en"
        ]
        app.launch()

        openSettings()

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
            "-seedSampleBook", "-forceLanguage", "en", "-translationBackendURL",
            "https://backend.example", "-translationSessionToken",
            "ui-test-session"
        ]
        app.launch()

        openSettings()

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
