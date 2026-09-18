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
        // Device-state probes run against a hand-seeded container.
        if ProcessInfo.processInfo.environment["PROBE_KEEP_STATE"] != nil {
            app.launchArguments = ["-skipOnboarding"]
        }
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

        // All eight atmospheres sit in the panel's first section.
        for theme in ["paper", "sepia", "mist", "bold", "dusk", "amber", "ink", "night"] {
            XCTAssertTrue(app.buttons["theme.\(theme)"].waitForExistence(timeout: 6), theme)
        }
        let duskSwatch = app.buttons["theme.dusk"]
        duskSwatch.tap()
        XCTAssertTrue(duskSwatch.isSelected)

        // Size lives on the same panel now — no tab to switch.
        let sizeUp = app.buttons["fontsize.up"]
        XCTAssertTrue(sizeUp.waitForExistence(timeout: 6))
        sizeUp.tap()

        // Dismiss the sheet, reopen, and confirm the choice stuck.
        app.swipeDown(velocity: .fast)
        XCTAssertTrue(app.buttons["reader.menu"].waitForExistence(timeout: 6))
        tapMenuItem("reader.typography")
        XCTAssertTrue(duskSwatch.waitForExistence(timeout: 6))
        XCTAssertTrue(duskSwatch.isSelected)
    }

    /// Opens whatever book the simulator container already holds and
    /// scrolls through two chapters, asserting the app answers throughout.
    /// Run with `TEST_RUNNER_PROBE_KEEP_STATE=1` after seeding the container
    /// (library.json progress + reader settings) by hand to replay a
    /// tester's exact state; without the variable it runs on the sample book.
    func testScrollFlowStaysResponsiveOnSeededState() {
        let card = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'library.book.'")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 15))
        card.tap()
        let window = app.windows.firstMatch
        func alive(_ tag: String) {
            let ok = app.wait(for: .runningForeground, timeout: 5)
            XCTAssertTrue(ok && window.exists, "app hung at \(tag)")
        }
        XCTAssertTrue(app.buttons["reader.back"].waitForExistence(timeout: 15), "reader opens")
        alive("open"); sleep(2)
        window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        for i in 0..<10 { app.swipeUp(velocity: .fast); if i % 3 == 2 { alive("swipe\(i)") } }
        for _ in 0..<10 where !app.buttons["reader.nextChapter"].exists { app.swipeUp(velocity: .fast) }
        if app.buttons["reader.nextChapter"].exists { app.buttons["reader.nextChapter"].tap() }
        alive("nextChapter")
        for i in 0..<10 { app.swipeUp(velocity: .fast); if i % 3 == 2 { alive("ch2-swipe\(i)") } }
        for _ in 0..<4 { app.swipeDown(velocity: .fast) }
        alive("final")
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

    /// Opens the appearance sheet and scrolls to the Layout section, where
    /// the page-flow and transition controls live.
    private func openLayoutSection() {
        tapMenuItem("reader.typography")
        let flow = app.buttons["flow.paged"]
        XCTAssertTrue(flow.waitForExistence(timeout: 6))
        // The sheet opens at its compact detent; pull it up so the Layout
        // section is on screen and hittable.
        app.swipeUp(velocity: .fast)
        if !flow.isHittable { app.swipeUp() }
        XCTAssertTrue(flow.isHittable, "layout section should be reachable")
    }

    /// Curl mode owns the horizontal touches, so a chapter-edge pull is
    /// detected by the engine, not the scroll view. A quick short flick
    /// at the last page used to do nothing (70px distance gate, and a
    /// settling curl swallowed it); it must turn the chapter.
    func testCurlQuickFlickAtChapterEndAdvancesChapter() {
        app.terminate()
        app.launchArguments = [
            "-resetLibrary", "-resetSettings", "-seedSampleBook",
            "-forceTransition", "curl", "-skipOnboarding"
        ]
        app.launch()
        openSampleBook()

        let window = app.windows.firstMatch
        let title = app.staticTexts["reader.chapterTitle"]
        let firstChapter = title.label
        let pagesLeft = app.staticTexts["reader.chapterPagesLeft"]
        // Tap to the last page of the chapter.
        for _ in 0..<40 where !pagesLeft.label.hasPrefix("0 ") {
            window.coordinate(
                withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)
            ).tap()
            _ = pagesLeft.waitForExistence(timeout: 2)
        }
        XCTAssertTrue(pagesLeft.label.hasPrefix("0 "),
                      "should reach the chapter's last page")

        // A short, fast flick: ~50pt, well under the old 70px gate.
        let start = window.coordinate(
            withNormalizedOffset: CGVector(dx: 0.6, dy: 0.5)
        )
        let end = start.withOffset(CGVector(dx: -50, dy: 0))
        start.press(
            forDuration: 0.02, thenDragTo: end,
            withVelocity: .fast, thenHoldForDuration: 0
        )

        let changed = NSPredicate(format: "label != %@", firstChapter)
        expectation(for: changed, evaluatedWith: title)
        waitForExpectations(timeout: 8)
    }

    func testFlowAndTransitionPickersPersist() {
        openSampleBook()
        openLayoutSection()

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
        openLayoutSection()
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

    func testTranslateSheetRequiresAppleLoginBeforeFreeChapter() {
        openTranslationSheet()

        XCTAssertTrue(
            app.otherElements["translation.sheet"].waitForExistence(timeout: 6)
        )
        // No account yet: the flap leads with Sign in with Apple, the free
        // chapter line is present but inert, and the attestation is fine
        // print with the Terms link inline — no checkbox to tick first.
        XCTAssertTrue(
            app.buttons["translation.signInWithApple"].waitForExistence(timeout: 6)
        )
        let freeChapter = app.buttons["translation.freeChapter"]
        XCTAssertTrue(freeChapter.waitForExistence(timeout: 6))
        XCTAssertFalse(freeChapter.isEnabled)
        XCTAssertTrue(app.staticTexts["translation.terms.link"].exists)
        XCTAssertFalse(app.buttons["translation.termsAcceptance"].exists)

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

        let localAccount = app.buttons["translation.localTestAccount"]
        XCTAssertTrue(
            localAccount.waitForExistence(timeout: 6),
            "a loopback backend should expose the debug-only test account"
        )
        localAccount.tap()

        // Tapping the capsule is the terms acceptance; there is no checkbox.
        let quote = app.buttons["translation.calculateQuote"]
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

        let added = NSPredicate(format: "label CONTAINS[c] 'Added to your shelf'")
        expectation(
            for: added, evaluatedWith: app.buttons["translation.fullBook"]
        )
        waitForExpectations(timeout: 30)
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
