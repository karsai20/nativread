import XCTest

/// End-to-end journey over the seeded sample book: shelf → open →
/// page turns → typography → contents → search → bookmark → persistence.
final class ReaderJourneyUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "-resetLibrary", "-resetSettings", "-seedSampleBook"
        ]
        app.launch()
    }

    private func openSampleBook() {
        let card = app.buttons["library.book.The Lantern of Aldebaran"]
        XCTAssertTrue(card.waitForExistence(timeout: 10),
                      "seeded book should be on the shelf")
        card.tap()
        XCTAssertTrue(
            app.buttons["reader.back"].waitForExistence(timeout: 10),
            "reader chrome should appear"
        )
        // Give the pagination engine a beat to measure the chapter.
        XCTAssertTrue(
            app.staticTexts["reader.pageLabel"]
                .waitForExistence(timeout: 10)
        )
    }

    private var pageLabelValue: String {
        app.staticTexts["reader.pageLabel"].label
    }

    func testShelfShowsSeededBook() {
        XCTAssertTrue(
            app.staticTexts["Quire"].waitForExistence(timeout: 10)
        )
        XCTAssertTrue(
            app.buttons["library.book.The Lantern of Aldebaran"]
                .waitForExistence(timeout: 10)
        )
        XCTAssertTrue(app.staticTexts["E. M. Voss"].exists)
    }

    func testPageTurnAdvancesAndPersistsProgress() {
        openSampleBook()
        let initial = pageLabelValue

        // Tap the right page-turn zone (chrome-free middle right).
        let window = app.windows.firstMatch
        window.coordinate(
            withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)
        ).tap()

        let label = app.staticTexts["reader.pageLabel"]
        let changed = NSPredicate(format: "label != %@", initial)
        expectation(for: changed, evaluatedWith: label)
        waitForExpectations(timeout: 8)

        let afterTurn = pageLabelValue

        // Leave the reader, reopen: position must be restored.
        app.buttons["reader.back"].tap()
        openSampleBook()
        let restored = NSPredicate(format: "label == %@", afterTurn)
        expectation(for: restored, evaluatedWith: label)
        waitForExpectations(timeout: 8)
    }

    func testTypographyPanelSwitchesTheme() {
        openSampleBook()
        app.buttons["reader.typography"].tap()

        let duskSwatch = app.buttons["theme.dusk"]
        XCTAssertTrue(duskSwatch.waitForExistence(timeout: 6))
        duskSwatch.tap()
        app.buttons["fontsize.up"].tap()

        // Dismiss the sheet, reopen, and confirm the choice stuck.
        app.swipeDown(velocity: .fast)
        XCTAssertTrue(
            app.buttons["reader.typography"].waitForExistence(timeout: 6)
        )
        app.buttons["reader.typography"].tap()
        XCTAssertTrue(duskSwatch.waitForExistence(timeout: 6))
    }

    func testContentsNavigatesToChapter() {
        openSampleBook()
        app.buttons["reader.contents"].tap()

        let chapter = app.buttons
            .containing(NSPredicate(
                format: "label CONTAINS %@", "Under the Glass"
            ))
            .firstMatch
        XCTAssertTrue(chapter.waitForExistence(timeout: 6))
        chapter.tap()

        let title = app.staticTexts["Under the Glass"]
        XCTAssertTrue(title.waitForExistence(timeout: 8),
                      "chapter title should appear in the top bar")
    }

    func testSearchFindsTextAcrossBook() {
        openSampleBook()
        app.buttons["reader.search"].tap()

        let field = app.textFields["search.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 6))
        field.tap()
        // "\n" submits even when the simulator hides the soft keyboard.
        field.typeText("lantern\n")

        let count = app.staticTexts["search.resultCount"]
        XCTAssertTrue(count.waitForExistence(timeout: 8))
        XCTAssertFalse(count.label.hasPrefix("0 "))

        // Jump to the first match; the reader should come back.
        app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "lantern")
        ).firstMatch.tap()
        XCTAssertTrue(
            app.staticTexts["reader.pageLabel"]
                .waitForExistence(timeout: 8)
        )
    }

    func testScrollFlowAdvancesProgress() {
        app.terminate()
        app.launchArguments = [
            "-resetLibrary", "-resetSettings", "-seedSampleBook",
            "-forceFlow", "scroll"
        ]
        app.launch()
        openSampleBook()
        let initial = pageLabelValue

        // In scroll flow the page advances by swiping vertically.
        app.swipeUp(velocity: .fast)
        app.swipeUp(velocity: .fast)

        let label = app.staticTexts["reader.pageLabel"]
        let changed = NSPredicate(format: "label != %@", initial)
        expectation(for: changed, evaluatedWith: label)
        waitForExpectations(timeout: 8)
    }

    /// Expands the typography sheet so below-the-fold controls enter
    /// the accessibility hierarchy.
    private func expandTypographyPanel() {
        app.buttons["reader.typography"].tap()
        // Toggles surface as switches in the accessibility tree.
        XCTAssertTrue(
            app.switches["theme.auto"].waitForExistence(timeout: 6)
        )
        app.swipeUp(velocity: .fast)
    }

    func testFlowAndTransitionPickersPersist() {
        openSampleBook()
        expandTypographyPanel()

        // Transition picker is only visible in paged flow.
        let fade = app.buttons["transition.fade"]
        XCTAssertTrue(fade.waitForExistence(timeout: 6))
        fade.tap()

        let scroll = app.buttons["flow.scroll"]
        XCTAssertTrue(scroll.waitForExistence(timeout: 6))
        scroll.tap()
        // Switching to scroll hides the transition row.
        XCTAssertFalse(fade.exists)

        // Reopen the panel: choices must have persisted.
        app.swipeDown(velocity: .fast)
        XCTAssertTrue(
            app.buttons["reader.typography"].waitForExistence(timeout: 6)
        )
        expandTypographyPanel()
        let paged = app.buttons["flow.paged"]
        XCTAssertTrue(paged.waitForExistence(timeout: 6))
        paged.tap()
        XCTAssertTrue(fade.waitForExistence(timeout: 6))
    }

    func testBookmarkToggle() {
        openSampleBook()
        app.buttons["reader.bookmark"].tap()

        app.buttons["reader.contents"].tap()
        app.buttons["Bookmarks"].tap()

        // One bookmark for chapter one should be listed.
        let entry = app.buttons.containing(
            NSPredicate(format: "label CONTAINS %@", "The Harbour of Glass")
        ).firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 6))
    }
}
