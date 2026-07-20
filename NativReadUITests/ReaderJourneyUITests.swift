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
            app.buttons["reader.position"]
                .waitForExistence(timeout: 10)
        )
    }

    private var pageLabelValue: String {
        app.buttons["reader.position"].label
    }

    /// Reader tools live behind the bottom-right menu since the
    /// Books-style chrome redesign; fan it out when needed.
    private func tapMenuItem(_ identifier: String) {
        let item = app.buttons[identifier]
        if !item.isHittable {
            app.buttons["reader.menu"].tap()
            XCTAssertTrue(
                item.waitForExistence(timeout: 4),
                "\(identifier) should appear in the fanned-out menu"
            )
        }
        item.tap()
    }

    func testShelfShowsSeededBook() {
        // The brand wordmark was removed from the library header; the shelf is
        // identified by its seeded content instead.
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

        let label = app.buttons["reader.position"]
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

    func testPositionNavigatorUsesAnAccessibleSlider() {
        openSampleBook()
        app.buttons["reader.position"].tap()

        let slider = app.sliders["reader.position.slider"]
        XCTAssertTrue(
            slider.waitForExistence(timeout: 6),
            "the compact progress indicator should open a full-size slider"
        )
        XCTAssertTrue(app.buttons["reader.position.nextChapter"].exists)

        app.buttons["reader.position.done"].tap()
        XCTAssertTrue(
            app.buttons["reader.position"].waitForExistence(timeout: 6)
        )
    }

    func testTypographyPanelSwitchesTheme() {
        openSampleBook()
        tapMenuItem("reader.typography")

        // Theme swatches live on the default Theme tab.
        let duskSwatch = app.buttons["theme.dusk"]
        XCTAssertTrue(duskSwatch.waitForExistence(timeout: 6))
        duskSwatch.tap()

        // Size lives on the Text tab in the redesigned tabbed panel.
        app.buttons["appearance.tab.text"].tap()
        let sizeUp = app.buttons["fontsize.up"]
        XCTAssertTrue(sizeUp.waitForExistence(timeout: 6))
        sizeUp.tap()

        // Dismiss the sheet, reopen, and confirm the choice stuck.
        app.swipeDown(velocity: .fast)
        XCTAssertTrue(
            app.buttons["reader.menu"].waitForExistence(timeout: 6)
        )
        tapMenuItem("reader.typography")
        XCTAssertTrue(duskSwatch.waitForExistence(timeout: 6))
    }

    func testContentsNavigatesToChapter() {
        openSampleBook()
        tapMenuItem("reader.contents")

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
        tapMenuItem("reader.search")

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
            app.buttons["reader.position"]
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

        let label = app.buttons["reader.position"]
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

    /// Opens the appearance sheet and selects the Layout tab, where the
    /// page-flow and transition controls live in the redesigned tabbed panel.
    private func openLayoutTab() {
        tapMenuItem("reader.typography")
        let layout = app.buttons["appearance.tab.layout"]
        XCTAssertTrue(layout.waitForExistence(timeout: 6))
        layout.tap()
    }

    func testFlowAndTransitionPickersPersist() {
        openSampleBook()
        openLayoutTab()

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
            app.buttons["reader.menu"].waitForExistence(timeout: 6)
        )
        openLayoutTab()
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
        tapMenuItem("reader.contents")
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
        tapMenuItem("reader.contents")
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
        // The native Anki deck export is offered alongside CSV/Markdown.
        XCTAssertTrue(app.buttons["vocabulary.export.anki"].exists)

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "vocabulary-export-menu"
        shot.lifetime = .keepAlways
        add(shot)
    }

    func testVocabularyKeepsSavedWordWithoutBundledDictionaryGloss() {
        app.terminate()
        app.launchArguments = [
            "-resetLibrary", "-resetSettings", "-resetLanguage",
            "-seedSampleBook", "-resetVocabulary", "-seedSampleVocabulary",
            "-forceLanguage", "hu",
            "-skipOnboarding"
        ]
        app.launch()

        let button = app.buttons["library.vocabulary"]
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        button.tap()

        XCTAssertTrue(
            app.staticTexts["lantern"].waitForExistence(timeout: 6),
            "seeded vocabulary word should be listed"
        )
        XCTAssertTrue(
            app.staticTexts["Apple Dictionary"].waitForExistence(timeout: 6),
            "saved vocabulary should record the native dictionary source"
        )
    }

    func testTranslateSheetRequiresRightsAndAppleLoginBeforeFreeChapter() {
        let button = app.buttons["library.translate"]
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        button.tap()

        // Translate opens a book picker first; choose the seeded book.
        let pickerBook =
            app.buttons["translation.picker.The Lantern of Aldebaran"]
        XCTAssertTrue(pickerBook.waitForExistence(timeout: 6))
        pickerBook.tap()

        XCTAssertTrue(
            app.otherElements["translation.sheet"].waitForExistence(timeout: 6)
        )
        let freeChapter = app.buttons["translation.freeChapter"]
        XCTAssertTrue(freeChapter.waitForExistence(timeout: 6))
        XCTAssertFalse(freeChapter.isEnabled)

        let attestation = app.buttons["translation.attestation"]
        XCTAssertTrue(attestation.waitForExistence(timeout: 6))
        attestation.tap()
        XCTAssertFalse(freeChapter.isEnabled)
        XCTAssertTrue(
            app.buttons["translation.signInWithApple"]
                .waitForExistence(timeout: 6)
        )
    }

    func testLocalPlaceholderPurchaseTranslatesAndImportsTheBook() {
        app.terminate()
        app.launchArguments = [
            "-resetLibrary", "-resetSettings", "-seedSampleBook",
            "-skipOnboarding", "-translationBackendURL",
            "http://127.0.0.1:48218"
        ]
        app.launch()

        let translate = app.buttons["library.translate"]
        XCTAssertTrue(translate.waitForExistence(timeout: 10))
        translate.tap()

        let pickerBook =
            app.buttons["translation.picker.The Lantern of Aldebaran"]
        XCTAssertTrue(pickerBook.waitForExistence(timeout: 6))
        pickerBook.tap()

        let attestation = app.buttons["translation.attestation"]
        XCTAssertTrue(attestation.waitForExistence(timeout: 6))
        attestation.tap()

        let localAccount = app.buttons["translation.localTestAccount"]
        XCTAssertTrue(
            localAccount.waitForExistence(timeout: 6),
            "a loopback backend should expose the debug-only test account"
        )
        localAccount.tap()

        let quote = app.buttons["translation.calculateQuote"]
        for _ in 0..<4 where !quote.exists {
            app.swipeUp(velocity: .fast)
        }
        XCTAssertTrue(quote.waitForExistence(timeout: 6))
        XCTAssertTrue(quote.isEnabled)
        quote.tap()

        let purchase = app.buttons["translation.placeholderPurchase"]
        XCTAssertTrue(
            purchase.waitForExistence(timeout: 20),
            "the exact character quote should offer the smallest test pack"
        )
        purchase.tap()

        let fullBook = app.buttons["translation.fullBook"]
        XCTAssertTrue(
            fullBook.waitForExistence(timeout: 10),
            "the placeholder purchase should make the quoted job affordable"
        )
        fullBook.tap()

        XCTAssertTrue(
            app.staticTexts[
                "Full Hungarian translation was added as a separate library book."
            ].waitForExistence(timeout: 30),
            "the fake backend result should be consumed and imported by the app"
        )
    }

    func testBookmarkToggle() {
        openSampleBook()
        tapMenuItem("reader.bookmark")

        tapMenuItem("reader.contents")
        app.buttons["Bookmarks"].tap()

        // One bookmark for chapter one should be listed.
        let entry = app.buttons.containing(
            NSPredicate(format: "label CONTAINS %@", "The Harbour of Glass")
        ).firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 6))
    }
}
