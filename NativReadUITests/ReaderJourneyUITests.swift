import UIKit
import XCTest

/// End-to-end journey over the seeded sample book: shelf → open →
/// page turns → typography → contents → search → bookmark → persistence.
final class ReaderJourneyUITests: XCTestCase {

    private var app: XCUIApplication!

    private func tab(_ tab: AppTab) -> XCUIElement {
        app.tabButton(tab)
    }

    override func setUp() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchArguments = [
            "-resetLibrary", "-resetSettings", "-seedSampleBook",
            "-skipOnboarding"
        ]
        app.launch()
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
        super.tearDown()
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

    func testEmptyShelfHasOneImportAction() {
        app.terminate()
        app.launchArguments = [
            "-resetLibrary", "-resetSettings", "-skipOnboarding"
        ]
        app.launch()

        XCTAssertTrue(
            app.buttons["library.import.empty"].waitForExistence(timeout: 10)
        )
        // Translation is its own destination now, so the empty shelf offers
        // exactly one action and never a second, competing import control.
        XCTAssertTrue(tab(.translate).exists)
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

    func testLandscapeRelayoutKeepsPageReadableAndSwipeable() {
        // Xcode 26 can acknowledge an in-app XCUIDevice rotation while the
        // simulator window remains portrait. Launching from the requested
        // orientation makes the test assert the real landscape geometry.
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
        openSampleBook()

        let position = app.buttons["reader.position"]
        XCTAssertTrue(position.waitForExistence(timeout: 10))
        let text = app.webViews.staticTexts.element(boundBy: 2)
        XCTAssertTrue(
            text.waitForExistence(timeout: 10),
            "chapter text should be repaginated and visible in landscape"
        )
        // Only a phone has a sensor housing to clear; an iPad's correct
        // landscape inset is the ordinary reading margin.
        if UIDevice.current.userInterfaceIdiom == .phone {
            // The viewport update is intentionally debounced while rotation
            // settles; wait for the new CSS rather than sampling the portrait
            // frame that can remain visible for the first animation frame.
            let clearsSensorHousing = NSPredicate { object, _ in
                guard let element = object as? XCUIElement else { return false }
                return element.frame.minX > 55
            }
            expectation(for: clearsSensorHousing, evaluatedWith: text)
            waitForExpectations(timeout: 10)
            XCTAssertGreaterThan(
                text.frame.minX, 55,
                "chapter text must clear the landscape sensor housing"
            )
        }

        // A swipe turns a page within the chapter on a phone, and advances
        // the chapter on a screen tall enough to hold this short chapter in
        // one page. The web view's own text cannot tell them apart — CSS
        // columns keep every paragraph in the DOM — so both chrome labels
        // are watched and either moving counts as the page having turned.
        let pagesLeft = app.staticTexts["reader.chapterPagesLeft"]
        let chapterTitle = app.staticTexts["reader.chapterTitle"]
        XCTAssertTrue(pagesLeft.waitForExistence(timeout: 4))
        let pagesLeftBefore = pagesLeft.label
        let chapterBefore = chapterTitle.label
        app.webViews.firstMatch.swipeLeft(velocity: .fast)

        let moved = expectation(description: "the swipe moves the reader")
        let deadline = Date().addingTimeInterval(10)
        DispatchQueue.global().async {
            while Date() < deadline {
                if pagesLeft.label != pagesLeftBefore
                    || chapterTitle.label != chapterBefore {
                    moved.fulfill()
                    return
                }
                Thread.sleep(forTimeInterval: 0.25)
            }
        }
        wait(for: [moved], timeout: 12)
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

        // On a phone the next chapter starts taller than the viewport, so the
        // pill leaves until the reader scrolls again. A short chapter on an
        // iPad-sized screen is legitimately visible end to end, which keeps
        // the affordance up — there, only the chapter change is asserted.
        if UIDevice.current.userInterfaceIdiom == .phone {
            let gone = NSPredicate(format: "exists == 0")
            expectation(for: gone, evaluatedWith: pill)
            waitForExpectations(timeout: 8)
        }

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

    func testNativeLookUpRemainsAvailable() {
        openSampleBook()

        let text = app.webViews.staticTexts.element(boundBy: 2)
        XCTAssertTrue(text.waitForExistence(timeout: 8))
        text.press(forDuration: 1.2)

        XCTAssertTrue(
            app.menuItems["Look Up"].waitForExistence(timeout: 6),
            "selection menu should preserve Apple's native Look Up action"
        )
    }

    /// Opens the translation sheet from the Translate destination, which
    /// lists every eligible book — the primary way in.
    private func openTranslationSheet(
        for title: String = "The Lantern of Aldebaran"
    ) {
        let translateTab = tab(.translate)
        XCTAssertTrue(translateTab.waitForExistence(timeout: 10))
        translateTab.tap()

        let readyBook = app.buttons["translate.ready.\(title)"]
        XCTAssertTrue(readyBook.waitForExistence(timeout: 8))
        readyBook.tap()
    }

    func testTranslateSheetRequiresTermsAndAppleLoginBeforeFreeChapter() {
        openTranslationSheet()

        XCTAssertTrue(
            app.otherElements["translation.sheet"].waitForExistence(timeout: 6)
        )
        let freeChapter = app.buttons["translation.freeChapter"]
        XCTAssertTrue(freeChapter.waitForExistence(timeout: 6))
        XCTAssertFalse(freeChapter.isEnabled)

        let termsAcceptance = app.buttons["translation.termsAcceptance"]
        XCTAssertTrue(termsAcceptance.waitForExistence(timeout: 6))
        XCTAssertTrue(app.buttons["translation.terms.link"].exists)
        XCTAssertFalse(app.buttons["translation.signInWithApple"].exists)
        termsAcceptance.tap()
        XCTAssertFalse(freeChapter.isEnabled)
        XCTAssertTrue(
            app.buttons["translation.signInWithApple"]
                .waitForExistence(timeout: 6)
        )

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "translation-sheet"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testLocalBackendTranslatesAndImportsTheWholeBook() {
        app.terminate()
        app.launchArguments = [
            "-resetLibrary", "-resetSettings", "-seedSampleBook",
            "-skipOnboarding", "-translationBackendURL",
            "http://127.0.0.1:48218"
        ]
        app.launch()

        openTranslationSheet()

        let termsAcceptance = app.buttons["translation.termsAcceptance"]
        XCTAssertTrue(termsAcceptance.waitForExistence(timeout: 6))
        termsAcceptance.tap()

        let localAccount = app.buttons["translation.localTestAccount"]
        XCTAssertTrue(
            localAccount.waitForExistence(timeout: 6),
            "a loopback backend should expose the debug-only test account"
        )
        localAccount.tap()

        let fullBookDisclosure =
            app.buttons["translation.fullBookDisclosure"]
        XCTAssertTrue(fullBookDisclosure.waitForExistence(timeout: 6))
        fullBookDisclosure.tap()

        let quote = app.buttons["translation.calculateQuote"]
        for _ in 0..<4 where !quote.exists {
            app.swipeUp(velocity: .fast)
        }
        XCTAssertTrue(quote.waitForExistence(timeout: 6))
        XCTAssertTrue(quote.isEnabled)
        quote.tap()

        let fullBook = app.buttons["translation.fullBook"]
        XCTAssertTrue(
            fullBook.waitForExistence(timeout: 20),
            "a backend that sells nothing should offer the quoted job directly"
        )
        fullBook.tap()

        let allowAI = app.buttons["translation.aiConsent.allow"]
        XCTAssertTrue(
            allowAI.waitForExistence(timeout: 6),
            "translation must request explicit AI processing permission"
        )
        XCTAssertTrue(app.buttons["translation.aiConsent.privacy"].exists)
        allowAI.tap()

        XCTAssertTrue(
            app.staticTexts["Added to your library."]
                .waitForExistence(timeout: 30),
            "the fake backend result should be consumed and imported by the app"
        )
    }

    func testHungarianAIPermissionCanBeDeclinedBeforeUpload() {
        app.terminate()
        app.launchArguments = [
            "-resetLibrary", "-resetSettings", "-seedSampleBook",
            "-skipOnboarding", "-forceLanguage", "hu",
            "-translationBackendURL", "http://127.0.0.1:48218"
        ]
        app.launch()

        XCTAssertTrue(
            tab(.translate).waitForExistence(timeout: 10)
        )
        tab(.translate).tap()
        app.buttons["translate.ready.The Lantern of Aldebaran"].tap()

        let terms = app.buttons["translation.termsAcceptance"]
        XCTAssertTrue(terms.waitForExistence(timeout: 6))
        terms.tap()

        let localAccount = app.buttons["translation.localTestAccount"]
        XCTAssertTrue(localAccount.waitForExistence(timeout: 6))
        localAccount.tap()

        let freeChapter = app.buttons["translation.freeChapter"]
        XCTAssertTrue(freeChapter.waitForExistence(timeout: 6))
        XCTAssertTrue(freeChapter.isEnabled)
        freeChapter.tap()

        XCTAssertTrue(
            app.buttons["translation.aiConsent.allow"]
                .waitForExistence(timeout: 6)
        )
        XCTAssertTrue(app.staticTexts["Mielőtt fordítunk"].exists)
        XCTAssertTrue(
            app.buttons["AI-fordítás engedélyezése"].exists
        )

        app.buttons["translation.aiConsent.cancel"].tap()
        XCTAssertTrue(
            app.otherElements["translation.sheet"]
                .waitForExistence(timeout: 6),
            "declining AI processing must keep the offline app usable"
        )
    }

    /// Tapping a highlighted passage in the page offers removal — the
    /// undo path for an accidental highlight.
    func testTappingAHighlightOffersRemoval() {
        app.terminate()
        app.launchArguments = [
            "-resetLibrary", "-resetSettings", "-skipOnboarding",
            "-seedShowcaseBooks", "-seedShowcaseState", "en",
            "-autoOpenFirstBook"
        ]
        app.launch()

        XCTAssertTrue(
            app.buttons["reader.position"].waitForExistence(timeout: 25)
        )

        // The book resumes pages past the seeded highlight, so jump to it
        // through the contents sheet first — the same locate path a reader
        // uses to revisit a highlight.
        let snippet = "Alice was beginning to get very tired"
        tapMenuItem("reader.contents")
        let contentsSegments = app.segmentedControls.firstMatch.buttons
        XCTAssertTrue(
            contentsSegments.element(boundBy: 2).waitForExistence(timeout: 8)
        )
        contentsSegments.element(boundBy: 2).tap()
        let row = app.scrollViews["contents.highlights"].staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", snippet)
        ).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 8))
        row.tap()

        // WebKit exposes the whole paragraph as one text run — the mark
        // gets no run of its own — so tap into the first line, which the
        // highlighted sentence fully covers.
        let paragraph = app.webViews.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", snippet)
        ).firstMatch
        XCTAssertTrue(paragraph.waitForExistence(timeout: 15))
        paragraph.coordinate(
            withNormalizedOffset: CGVector(dx: 0.3, dy: 0.07)
        ).tap()

        // Dialog action buttons do not carry SwiftUI accessibility
        // identifiers; address the action by its visible label. The dialog
        // exposes the label on two elements, so take the first.
        let remove = app.buttons["Remove highlight"].firstMatch
        XCTAssertTrue(remove.waitForExistence(timeout: 6))
        remove.tap()

        // The mark is gone: the contents sheet lists no highlights.
        tapMenuItem("reader.contents")
        XCTAssertTrue(
            contentsSegments.element(boundBy: 2).waitForExistence(timeout: 8)
        )
        contentsSegments.element(boundBy: 2).tap()
        XCTAssertTrue(
            app.staticTexts["No highlights yet"].waitForExistence(timeout: 6)
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
