import XCTest

/// Drives the real PDF import + reader: opens the seeded sample PDF,
/// turns a page, exercises the appearance (night), contents and search
/// sheets, and confirms the synthesized-TXT path opens the reflow reader.
/// Screenshots are attached for the PR.
final class PDFReaderUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(_ extraArguments: [String]) {
        app = XCUIApplication()
        app.launchArguments = [
            "-resetLibrary", "-resetSettings", "-skipOnboarding"
        ] + extraArguments
        app.launch()
    }

    private func snapshot(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func openPDF() {
        let card = app.buttons["library.book.Sample PDF"]
        XCTAssertTrue(card.waitForExistence(timeout: 15),
                      "seeded PDF should be on the shelf")
        snapshot("01-shelf-with-pdf")
        card.tap()
        XCTAssertTrue(
            app.buttons["reader.back"].waitForExistence(timeout: 15),
            "PDF reader chrome should appear"
        )
        XCTAssertTrue(
            app.buttons["reader.position"].waitForExistence(timeout: 15)
        )
    }

    func testPDFOpensPagesAndAppearance() {
        launch(["-seedSamplePDF"])
        openPDF()
        snapshot("02-pdf-reader-light")

        // Turn the page via the right tap zone; the page label must advance.
        let initial = app.buttons["reader.position"].label
        app.windows.firstMatch.coordinate(
            withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)
        ).tap()
        let advanced = NSPredicate(format: "label != %@", initial)
        expectation(
            for: advanced,
            evaluatedWith: app.buttons["reader.position"]
        )
        waitForExpectations(timeout: 10)
        snapshot("03-pdf-page-advanced")

        // Appearance → Dark engages the hue-preserving night invert.
        app.buttons["reader.appearance"].tap()
        let dark = app.buttons["appearance.mode.Dark"]
        XCTAssertTrue(dark.waitForExistence(timeout: 10))
        dark.tap()
        snapshot("04-pdf-appearance-dark")
        // Dismiss the sheet by tapping the dimmed area above it, then wait
        // for it to leave the hierarchy so the night page is captured clean.
        app.windows.firstMatch.coordinate(
            withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)
        ).tap()
        let appearanceGone = NSPredicate(format: "exists == false")
        expectation(for: appearanceGone, evaluatedWith: app.staticTexts["Appearance"])
        waitForExpectations(timeout: 10)
        snapshot("05-pdf-reader-night")
    }

    func testPDFPositionNavigatorUsesAccessibleSlider() {
        launch(["-seedSamplePDF"])
        openPDF()
        app.buttons["reader.position"].tap()

        XCTAssertTrue(
            app.sliders["reader.position.slider"].waitForExistence(timeout: 10)
        )
        XCTAssertTrue(app.buttons["reader.position.nextPage"].exists)
        app.buttons["reader.position.done"].tap()
    }

    func testPDFContentsAndSearch() {
        launch(["-seedSamplePDF"])
        openPDF()

        app.buttons["reader.contents"].tap()
        XCTAssertTrue(
            app.staticTexts["Contents"].waitForExistence(timeout: 10)
                || app.buttons["Contents"].waitForExistence(timeout: 1)
        )
        snapshot("06-pdf-contents")
        app.swipeDown(velocity: .fast)

        app.buttons["reader.search"].tap()
        let field = app.textFields["search.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        // The trailing newline fires the field's onSubmit → runSearch,
        // avoiding a brittle dependency on the return-key's localized label.
        field.typeText("sample\n")
        // A result row carries the page eyebrow "Page 1".
        XCTAssertTrue(
            app.staticTexts["PAGE 1"].waitForExistence(timeout: 10)
                || app.staticTexts["Page 1"].waitForExistence(timeout: 1),
            "search should surface a page hit"
        )
        snapshot("07-pdf-search-results")
    }

    func testTextFileOpensReflowReader() {
        launch(["-seedSampleText"])
        let card = app.buttons["library.book.Sample Text Document"]
        XCTAssertTrue(card.waitForExistence(timeout: 15),
                      "seeded TXT should be on the shelf, titled by first line")
        snapshot("08-shelf-with-txt")
        card.tap()
        // TXT uses the reflow reader; its chrome + page label appear.
        XCTAssertTrue(
            app.buttons["reader.back"].waitForExistence(timeout: 15)
        )
        XCTAssertTrue(
            app.buttons["reader.position"].waitForExistence(timeout: 15)
        )
        snapshot("09-txt-reflow-reader")
    }
}
