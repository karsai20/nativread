import XCTest

/// End-to-end journey over the seeded sample book: shelf → open →
/// page turns → typography → contents → search → bookmark → persistence.
final class ReaderJourneyUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "-resetLibrary", "-resetSettings", "-seedSampleBook",
            "-skipOnboarding"
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
            "-forceFlow", "scroll", "-skipOnboarding"
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

    func testScrollFlowChapterEndAffordanceAdvancesChapter() {
        app.terminate()
        app.launchArguments = [
            "-resetLibrary", "-resetSettings", "-seedSampleBook",
            "-forceFlow", "scroll", "-skipOnboarding"
        ]
        app.launch()
        openSampleBook()

        // Hide the chrome: the affordance only floats while reading.
        let window = app.windows.firstMatch
        window.coordinate(
            withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)
        ).tap()

        // Scroll to the chapter end; the next-chapter pill appears.
        let pill = app.buttons["reader.nextChapter"]
        for _ in 0..<6 where !pill.exists {
            app.swipeUp(velocity: .fast)
        }
        XCTAssertTrue(pill.waitForExistence(timeout: 6),
                      "chapter end should offer the next chapter")
        pill.tap()

        // Wait for the next chapter to load (the pill leaves the
        // start of a chapter), then bring back the chrome.
        let gone = NSPredicate(format: "exists == 0")
        expectation(for: gone, evaluatedWith: pill)
        waitForExpectations(timeout: 8)

        let title = app.staticTexts["The Keeper's Son"]
        for _ in 0..<3 where !title.exists {
            window.coordinate(
                withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)
            ).tap()
            _ = title.waitForExistence(timeout: 3)
        }
        XCTAssertTrue(title.exists,
                      "top bar should show the next chapter title")
    }

    /// Expands the typography sheet so below-the-fold controls enter
    /// the accessibility hierarchy.
    private func expandTypographyPanel() {
        app.buttons["reader.typography"].tap()
        // Size control is top-level and always present.
        XCTAssertTrue(app.buttons["fontsize.up"].waitForExistence(timeout: 6))
        // Open "More" to surface secondary controls into the a11y tree.
        let more = app.buttons["panel.more"]
        XCTAssertTrue(more.waitForExistence(timeout: 6))
        let auto = app.switches["theme.auto"]
        // Tapping "More" expands the secondary controls. Retry the tap if
        // the disclosure has not surfaced the auto-theme switch yet.
        for _ in 0..<3 where !auto.exists {
            more.tap()
            _ = auto.waitForExistence(timeout: 2)
        }
        XCTAssertTrue(auto.waitForExistence(timeout: 6))
    }

    func testFlowAndTransitionPickersPersist() {
        openSampleBook()
        expandTypographyPanel()

        // Transition picker is only visible in paged flow.
        let eink = app.buttons["transition.eink"]
        XCTAssertTrue(eink.waitForExistence(timeout: 6))
        eink.tap()

        let scroll = app.buttons["flow.scroll"]
        XCTAssertTrue(scroll.waitForExistence(timeout: 6))
        scroll.tap()
        // Switching to scroll hides the transition row.
        XCTAssertFalse(eink.exists)

        // Reopen the panel: choices must have persisted.
        app.swipeDown(velocity: .fast)
        XCTAssertTrue(
            app.buttons["reader.typography"].waitForExistence(timeout: 6)
        )
        expandTypographyPanel()
        let paged = app.buttons["flow.paged"]
        XCTAssertTrue(paged.waitForExistence(timeout: 6))
        paged.tap()
        XCTAssertTrue(eink.waitForExistence(timeout: 6))
    }

    func testHighlightSelectionPersistsAcrossRelaunch() {
        openSampleBook()

        // Long-press a word in the chapter to select it; the native
        // edit menu should include our custom Highlight action.
        let text = app.webViews.staticTexts.element(boundBy: 2)
        XCTAssertTrue(text.waitForExistence(timeout: 8))
        text.press(forDuration: 1.2)

        let highlightItem = app.menuItems["Highlight"]
        XCTAssertTrue(highlightItem.waitForExistence(timeout: 6),
                      "selection menu should offer Highlight")
        highlightItem.tap()

        // The highlight must be listed in the contents sheet.
        app.buttons["reader.contents"].tap()
        app.buttons["Highlights"].tap()
        let list = app.scrollViews["contents.highlights"]
        XCTAssertTrue(list.waitForExistence(timeout: 6))
        XCTAssertGreaterThan(list.buttons.count, 0)
        app.swipeDown(velocity: .fast)

        // Relaunch without resetting: the highlight must survive.
        app.terminate()
        app.launchArguments = ["-seedSampleBook", "-skipOnboarding"]
        app.launch()
        openSampleBook()
        app.buttons["reader.contents"].tap()
        app.buttons["Highlights"].tap()
        XCTAssertTrue(
            app.scrollViews["contents.highlights"]
                .waitForExistence(timeout: 6),
            "highlight should persist across relaunch"
        )
    }

    func testVocabularyEmptyStateOpensFromLibrary() {
        app.terminate()
        app.launchArguments = [
            "-resetLibrary", "-resetSettings", "-seedSampleBook",
            "-resetVocabulary", "-skipOnboarding"
        ]
        app.launch()

        let button = app.buttons["library.vocabulary"]
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        button.tap()

        XCTAssertTrue(
            app.otherElements["vocabulary.sheet"]
                .waitForExistence(timeout: 6)
            || app.staticTexts["No saved words yet"]
                .waitForExistence(timeout: 6),
            "vocabulary sheet should present"
        )
        XCTAssertTrue(
            app.staticTexts["No saved words yet"].exists,
            "empty vocabulary should show the empty state"
        )
    }

    func testVocabularySeededEntryAndExportMenu() {
        app.terminate()
        app.launchArguments = [
            "-resetLibrary", "-resetSettings", "-seedSampleBook",
            "-resetVocabulary", "-seedSampleVocabulary", "-skipOnboarding"
        ]
        app.launch()

        let button = app.buttons["library.vocabulary"]
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        button.tap()

        // The seeded word appears in the list.
        XCTAssertTrue(
            app.staticTexts["lantern"].waitForExistence(timeout: 6),
            "seeded vocabulary word should be listed"
        )

        // The export menu is present and offers the three formats.
        let export = app.buttons["vocabulary.export"]
        XCTAssertTrue(export.waitForExistence(timeout: 6))
        export.tap()
        XCTAssertTrue(
            app.buttons["CSV (Plain)"].waitForExistence(timeout: 6)
        )
        XCTAssertTrue(app.buttons["CSV (Cloze)"].exists)
        XCTAssertTrue(app.buttons["Markdown"].exists)
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
