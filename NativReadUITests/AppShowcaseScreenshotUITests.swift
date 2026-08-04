import XCTest

/// Produces the complete bilingual product screenshot set in
/// `docs/screenshots/showcase/<language>`. The journeys use real imported,
/// DRM-free showcase EPUBs rather than hand-built shelf models.
final class AppShowcaseScreenshotUITests: XCTestCase {

    private struct LocaleSpec {
        let code: String
        let appleLocale: String
        let primaryTitle: String
        let searchTerm: String

        static let english = LocaleSpec(
            code: "en",
            appleLocale: "en_US",
            primaryTitle: "Alice’s Adventures in Wonderland",
            searchTerm: "Alice"
        )

        static let hungarian = LocaleSpec(
            code: "hu",
            appleLocale: "hu_HU",
            primaryTitle: "A Pál-utcai fiúk: Regény kis diákok számára",
            searchTerm: "Nemecsek"
        )
    }

    private var app: XCUIApplication!

    private func tab(_ tab: AppTab) -> XCUIElement {
        app.tabButton(tab)
    }

    override func setUp() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    override func tearDown() {
        app?.terminate()
        XCUIDevice.shared.orientation = .portrait
        super.tearDown()
    }

    func testEnglishCompleteShowcase() {
        runCompleteShowcase(LocaleSpec.english)
    }

    func testHungarianCompleteShowcase() {
        runCompleteShowcase(LocaleSpec.hungarian)
    }

    private func runCompleteShowcase(_ locale: LocaleSpec) {
        captureOnboarding(locale)
        captureLibraryAndEPUBReader(locale)
        captureTranslation(locale)
        captureSettingsAndLegal(locale)
        capturePDFReader(locale)
    }

    // MARK: - Onboarding

    private func captureOnboarding(_ locale: LocaleSpec) {
        launch(locale, [
            "-resetLibrary", "-resetSettings", "-resetLanguage",
            "-forceOnboarding", "-seedShowcaseBooks"
        ])

        XCTAssertTrue(
            app.staticTexts["welcome.title"]
                .waitForExistence(timeout: 25)
        )
        // The continue button is the last reveal stage; once it is hittable
        // the screen is fully composed and worth photographing.
        let continueButton = app.buttons["welcome.continue"]
        let hittable = NSPredicate(format: "isHittable == true")
        expectation(for: hittable, evaluatedWith: continueButton)
        waitForExpectations(timeout: 10)
        capture(locale, 1, "onboarding-welcome")

        continueButton.tap()
        XCTAssertTrue(
            app.staticTexts["welcome.mode.title"].waitForExistence(timeout: 8)
        )
        capture(locale, 2, "onboarding-reading-mode")
    }

    // MARK: - Library + EPUB reader

    private func captureLibraryAndEPUBReader(_ locale: LocaleSpec) {
        launch(locale, [
            "-resetLibrary", "-resetSettings", "-resetLanguage",
            "-skipOnboarding"
        ])
        XCTAssertTrue(
            app.buttons["library.import.empty"].waitForExistence(timeout: 15)
        )
        capture(locale, 5, "library-empty")

        launchShowcaseLibrary(locale)
        let book = primaryBook(locale)
        XCTAssertTrue(book.waitForExistence(timeout: 30))
        capture(locale, 6, "library-showcase-books")

        book.tap()
        XCTAssertTrue(
            app.buttons["reader.back"].waitForExistence(timeout: 20)
        )
        XCTAssertTrue(
            app.buttons["reader.position"].waitForExistence(timeout: 20)
        )
        capture(locale, 7, "epub-reader")

        app.buttons["reader.menu"].tap()
        let rotationLock = app.buttons["reader.rotationLock"]
        XCTAssertTrue(rotationLock.waitForExistence(timeout: 8))
        rotationLock.tap()
        capture(locale, 8, "epub-reader-menu-active-lock")

        app.buttons["reader.position"].tap()
        XCTAssertTrue(
            app.sliders["reader.position.slider"].waitForExistence(timeout: 8)
        )
        capture(locale, 9, "epub-position")
        app.buttons["reader.position.done"].tap()

        tapReaderMenuItem("reader.typography")
        XCTAssertTrue(
            app.buttons["appearance.tab.theme"].waitForExistence(timeout: 8)
        )
        capture(locale, 10, "epub-appearance-theme")

        app.buttons["appearance.tab.text"].tap()
        capture(locale, 11, "epub-appearance-text")

        app.buttons["appearance.tab.layout"].tap()
        capture(locale, 12, "epub-appearance-layout")
        dismissReaderSheet()

        tapReaderMenuItem("reader.contents")
        XCTAssertTrue(
            app.scrollViews["contents.toc"].waitForExistence(timeout: 10)
        )
        capture(locale, 13, "epub-contents")

        let contentsSegments = app.segmentedControls.firstMatch.buttons
        XCTAssertGreaterThanOrEqual(contentsSegments.count, 3)
        contentsSegments.element(boundBy: 1).tap()
        capture(locale, 14, "epub-bookmarks")

        contentsSegments.element(boundBy: 2).tap()
        XCTAssertTrue(
            app.scrollViews["contents.highlights"]
                .waitForExistence(timeout: 8)
        )
        capture(locale, 15, "epub-highlights")
        dismissReaderSheet()

        tapReaderMenuItem("reader.search")
        let field = app.textFields["search.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 8))
        field.tap()
        field.typeText("\(locale.searchTerm)\n")
        XCTAssertTrue(
            app.staticTexts["search.resultCount"].waitForExistence(timeout: 25)
        )
        capture(locale, 16, "epub-search")
    }

    // MARK: - Translation

    private func captureTranslation(_ locale: LocaleSpec) {
        launchShowcaseLibrary(
            locale,
            extraArguments: [
                "-translationBackendURL", "http://127.0.0.1:48218"
            ]
        )

        XCTAssertTrue(
            tab(.translate).waitForExistence(timeout: 30)
        )
        tab(.translate).tap()

        let pickerBook =
            app.buttons["translate.ready.\(locale.primaryTitle)"]
        XCTAssertTrue(pickerBook.waitForExistence(timeout: 12))
        capture(locale, 17, "translation-book-picker")
        pickerBook.tap()

        XCTAssertTrue(
            app.otherElements["translation.sheet"].waitForExistence(timeout: 12)
        )
        capture(locale, 18, "translation-overview")

        app.buttons["translation.termsAcceptance"].tap()
        let localAccount = app.buttons["translation.localTestAccount"]
        XCTAssertTrue(localAccount.waitForExistence(timeout: 10))
        localAccount.tap()

        let disclosure = app.buttons["translation.fullBookDisclosure"]
        scrollUntilHittable(disclosure, direction: .up, attempts: 6)
        XCTAssertTrue(disclosure.isHittable)
        disclosure.tap()
        capture(locale, 20, "translation-whole-book-options")

        let freeChapter = app.buttons["translation.freeChapter"]
        scrollUntilHittable(freeChapter, direction: .down, attempts: 7)
        XCTAssertTrue(freeChapter.isHittable)
        freeChapter.tap()

        XCTAssertTrue(
            app.buttons["translation.aiConsent.allow"]
                .waitForExistence(timeout: 10)
        )
        capture(locale, 21, "translation-ai-consent")
    }

    // MARK: - Settings + legal

    private func captureSettingsAndLegal(_ locale: LocaleSpec) {
        launchShowcaseLibrary(
            locale,
            extraArguments: [
                "-translationBackendURL", "https://backend.example",
                "-translationSessionToken", "showcase-session"
            ]
        )
        XCTAssertTrue(
            tab(.settings).waitForExistence(timeout: 30)
        )
        tab(.settings).tap()
        XCTAssertTrue(
            app.otherElements["settings.sheet"].waitForExistence(timeout: 10)
        )
        capture(locale, 22, "settings-top")

        let deleteAccount = app.buttons["settings.account.delete"]
        scrollUntilHittable(deleteAccount, direction: .up, attempts: 5)
        XCTAssertTrue(deleteAccount.isHittable)
        capture(locale, 23, "settings-privacy-account")

        let privacyLink = app.buttons["settings.privacy.link"]
        scrollUntilHittable(privacyLink, direction: .up, attempts: 6)
        XCTAssertTrue(privacyLink.isHittable)
        capture(locale, 24, "settings-about")

        privacyLink.tap()
        XCTAssertTrue(
            app.scrollViews["privacy.screen"].waitForExistence(timeout: 10)
        )
        capture(locale, 25, "privacy-policy-top")
        app.swipeUp(velocity: .fast)
        app.swipeUp(velocity: .fast)
        capture(locale, 26, "privacy-policy-more")
        navigateBack()

        let termsLink = app.buttons["settings.terms.link"]
        scrollUntilHittable(termsLink, direction: .up, attempts: 3)
        XCTAssertTrue(termsLink.isHittable)
        termsLink.tap()
        XCTAssertTrue(
            app.scrollViews["terms.screen"].waitForExistence(timeout: 10)
        )
        capture(locale, 27, "terms-of-use-top")
        app.swipeUp(velocity: .fast)
        app.swipeUp(velocity: .fast)
        capture(locale, 28, "terms-of-use-more")
        navigateBack()

        let licensesLink = app.buttons["settings.licenses.link"]
        scrollUntilHittable(licensesLink, direction: .up, attempts: 3)
        XCTAssertTrue(licensesLink.isHittable)
        licensesLink.tap()
        XCTAssertTrue(
            app.scrollViews["settings.licenses"].waitForExistence(timeout: 10)
        )
        capture(locale, 29, "licenses")
        navigateBack()

        scrollUntilHittable(deleteAccount, direction: .down, attempts: 7)
        XCTAssertTrue(deleteAccount.isHittable)
        deleteAccount.tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 8))
        capture(locale, 30, "delete-account-confirmation")

        let deleteLabel = locale.code == "hu"
            ? "Fiók törlése"
            : "Delete Account"
        app.alerts.firstMatch.buttons[deleteLabel].tap()
        XCTAssertTrue(
            app.otherElements["settings.account.authorization"]
                .waitForExistence(timeout: 10)
        )
        capture(locale, 31, "delete-account-apple-confirmation")
        app.buttons[locale.code == "hu" ? "Mégse" : "Cancel"].tap()

        let darkAppearance = app.buttons["settings.appearance.dark"]
        scrollUntilHittable(darkAppearance, direction: .down, attempts: 8)
        XCTAssertTrue(darkAppearance.isHittable)
        darkAppearance.tap()
        capture(locale, 32, "settings-dark")
        tab(.library).tap()
        XCTAssertTrue(
            app.staticTexts["library.grid.heading"]
                .waitForExistence(timeout: 8)
        )
        capture(locale, 33, "library-dark")
    }

    // MARK: - PDF reader

    private func capturePDFReader(_ locale: LocaleSpec) {
        launch(locale, [
            "-resetLibrary", "-resetSettings", "-resetLanguage",
            "-skipOnboarding", "-seedShowcaseBooks", "-seedSamplePDF",
            "-seedShowcaseState", locale.code
        ])

        let pdfTitle = locale.code == "hu" ? "Minta PDF" : "Sample PDF"
        let pdf = app.buttons["library.book.\(pdfTitle)"]
        XCTAssertTrue(pdf.waitForExistence(timeout: 30))
        pdf.tap()
        XCTAssertTrue(
            app.buttons["reader.position"].waitForExistence(timeout: 20)
        )
        capture(locale, 34, "pdf-reader")

        app.buttons["reader.bookmark"].tap()
        app.buttons["reader.contents"].tap()
        XCTAssertTrue(
            app.segmentedControls.firstMatch.waitForExistence(timeout: 8)
        )
        capture(locale, 35, "pdf-contents")
        app.segmentedControls.firstMatch.buttons.element(boundBy: 1).tap()
        capture(locale, 36, "pdf-bookmarks")
        dismissReaderSheet()

        app.buttons["reader.position"].tap()
        XCTAssertTrue(
            app.sliders["reader.position.slider"].waitForExistence(timeout: 8)
        )
        capture(locale, 37, "pdf-position")
        app.buttons["reader.position.done"].tap()

        app.buttons["reader.appearance"].tap()
        let darkMode = app.buttons["appearance.mode.Dark"]
        XCTAssertTrue(darkMode.waitForExistence(timeout: 8))
        capture(locale, 38, "pdf-appearance")
        darkMode.tap()
        app.windows.firstMatch.coordinate(
            withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)
        ).tap()
        XCTAssertTrue(
            waitForDisappearance(app.staticTexts["Appearance"], timeout: 8)
        )
        capture(locale, 39, "pdf-reader-night")

        app.buttons["reader.search"].tap()
        let field = app.textFields["search.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 8))
        field.tap()
        let searchTerm = locale.code == "hu" ? "minta" : "sample"
        field.typeText("\(searchTerm)\n")
        let pageLabel = locale.code == "hu" ? "oldal" : "Page 1"
        XCTAssertTrue(
            app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS[c] %@", pageLabel)
            ).firstMatch.waitForExistence(timeout: 15)
        )
        capture(locale, 40, "pdf-search")
    }

    // MARK: - Helpers

    private func launchShowcaseLibrary(
        _ locale: LocaleSpec,
        extraArguments: [String] = []
    ) {
        launch(locale, [
            "-resetLibrary", "-resetSettings", "-resetLanguage",
            "-skipOnboarding", "-seedShowcaseBooks",
            "-seedShowcaseState", locale.code
        ] + extraArguments)
    }

    private func launch(
        _ locale: LocaleSpec,
        _ arguments: [String]
    ) {
        app?.terminate()
        app = XCUIApplication()
        app.launchArguments = [
            "-forceLanguage", locale.code,
            "-AppleLanguages", "(\(locale.code))",
            "-AppleLocale", locale.appleLocale,
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryL"
        ] + arguments
        app.launch()
    }

    private func primaryBook(_ locale: LocaleSpec) -> XCUIElement {
        app.buttons["library.book.\(locale.primaryTitle)"]
    }

    private func tapReaderMenuItem(_ identifier: String) {
        let item = app.buttons[identifier]
        if !item.isHittable {
            app.buttons["reader.menu"].tap()
            XCTAssertTrue(item.waitForExistence(timeout: 8))
        }
        item.tap()
    }

    private func dismissReaderSheet() {
        app.swipeDown(velocity: .fast)
        if app.buttons["reader.menu"].waitForExistence(timeout: 3) {
            return
        }
        app.swipeDown(velocity: .fast)
        XCTAssertTrue(
            app.buttons["reader.menu"].waitForExistence(timeout: 5)
                || app.buttons["reader.appearance"].waitForExistence(timeout: 1)
        )
    }

    private enum ScrollDirection {
        case up
        case down
    }

    private func scrollUntilHittable(
        _ element: XCUIElement,
        direction: ScrollDirection,
        attempts: Int
    ) {
        for _ in 0..<attempts where !element.isHittable {
            switch direction {
            case .up:
                app.swipeUp(velocity: .fast)
            case .down:
                app.swipeDown(velocity: .fast)
            }
        }
    }

    private func navigateBack() {
        let back = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        back.tap()
    }

    private func waitForDisappearance(
        _ element: XCUIElement,
        timeout: TimeInterval
    ) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(
            predicate: predicate,
            object: element
        )
        return XCTWaiter.wait(
            for: [expectation],
            timeout: timeout
        ) == .completed
    }

    private func capture(
        _ locale: LocaleSpec,
        _ number: Int,
        _ slug: String
    ) {
        Thread.sleep(forTimeInterval: 0.65)
        let screenshot = app.screenshot()
        let fileName = String(
            format: "%02d-%@.png",
            number,
            slug
        )
        let directory = workspaceRoot
            .appendingPathComponent("docs/screenshots/showcase")
            .appendingPathComponent(locale.code)
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            try screenshot.pngRepresentation.write(
                to: directory.appendingPathComponent(fileName),
                options: .atomic
            )
        } catch {
            XCTFail("Could not write \(fileName): \(error)")
        }

        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "\(locale.code)-\(fileName)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private var workspaceRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
