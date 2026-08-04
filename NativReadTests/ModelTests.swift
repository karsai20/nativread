import SwiftUI
import XCTest
@testable import NativRead

final class ModelTests: XCTestCase {

    // MARK: - Book fraction math

    func testBookFractionWeightsChaptersBySize() {
        let weights = [100.0, 300.0, 100.0]

        XCTAssertEqual(
            Book.bookFraction(
                spineIndex: 0, pageFraction: 0, weights: weights
            ),
            0, accuracy: 0.0001
        )
        XCTAssertEqual(
            Book.bookFraction(
                spineIndex: 1, pageFraction: 0.5, weights: weights
            ),
            0.5, accuracy: 0.0001
        )
        XCTAssertEqual(
            Book.bookFraction(
                spineIndex: 2, pageFraction: 1, weights: weights
            ),
            1, accuracy: 0.0001
        )
    }

    // MARK: - Whole-book page estimate

    func testEstimatedBookPagesScalesChapterDensityToWholeBook() {
        // Chapter 1 (weight 2000 of 4000 total) measures 10 pages, so
        // the whole book is estimated at 20.
        XCTAssertEqual(
            Book.estimatedBookPages(
                chapterPageCount: 10, spineIndex: 1,
                weights: [1000, 2000, 1000]
            ),
            20
        )
    }

    func testEstimatedBookPagesFallsBackToChapterCount() {
        // No weights (TXT import edge) or a zero-weight chapter: the
        // only trustworthy number is the measured chapter itself.
        XCTAssertEqual(
            Book.estimatedBookPages(
                chapterPageCount: 7, spineIndex: 0, weights: []
            ),
            7
        )
        XCTAssertEqual(
            Book.estimatedBookPages(
                chapterPageCount: 7, spineIndex: 1, weights: [100, 0, 100]
            ),
            7
        )
        XCTAssertEqual(
            Book.estimatedBookPages(
                chapterPageCount: 7, spineIndex: 9, weights: [100, 100]
            ),
            7
        )
    }

    func testBookFractionHandlesDegenerateInput() {
        XCTAssertEqual(
            Book.bookFraction(spineIndex: 0, pageFraction: 0.5, weights: []),
            0
        )
        XCTAssertEqual(
            Book.bookFraction(
                spineIndex: 9, pageFraction: 0.5, weights: [1, 1]
            ),
            0
        )
    }

    func testPositionIsInverseOfBookFraction() {
        let weights = [120.0, 480.0, 200.0, 200.0]
        for fraction in stride(from: 0.0, through: 1.0, by: 0.05) {
            let position = Book.position(
                forBookFraction: fraction, weights: weights
            )
            let roundTrip = Book.bookFraction(
                spineIndex: position.spineIndex,
                pageFraction: position.pageFraction,
                weights: weights
            )
            XCTAssertEqual(roundTrip, fraction, accuracy: 0.0001,
                           "failed for fraction \(fraction)")
        }
    }

    func testPercentTextRounds() {
        var book = Book(
            title: "T", author: "A", fileName: "f.epub",
            spineWeights: [1]
        )
        book.progress.bookFraction = 0.337
        XCTAssertEqual(book.percentText, "34%")
        XCTAssertFalse(book.isFinished)
        book.progress.bookFraction = 0.999
        XCTAssertTrue(book.isFinished)
    }

    func testOnlyTranslatedEPUBCopiesAreExportTargets() {
        let original = Book(title: "T", author: "A", fileName: "f.epub")
        XCTAssertFalse(original.isTranslatedCopy)
        XCTAssertFalse(original.canExportTranslatedEPUB)

        let preview = Book(
            title: "T (Hungarian Preview)",
            author: "A",
            fileName: "preview.epub",
            variant: .translationPreview
        )
        XCTAssertTrue(preview.isTranslatedCopy)
        XCTAssertTrue(preview.canExportTranslatedEPUB)

        let full = Book(
            title: "T (Hungarian)",
            author: "A",
            fileName: "full.epub",
            variant: .fullTranslation
        )
        XCTAssertTrue(full.isTranslatedCopy)
        XCTAssertTrue(full.canExportTranslatedEPUB)

        let translatedPDF = Book(
            title: "PDF",
            author: "A",
            fileName: "pdf.pdf",
            format: .pdf,
            variant: .fullTranslation
        )
        XCTAssertFalse(translatedPDF.canExportTranslatedEPUB)
    }

    // MARK: - Settings round-trip

    func testReaderSettingsCodableRoundTrip() throws {
        var settings = ReaderSettings()
        settings.theme = .dusk
        settings.font = .charter
        settings.fontSize = 21
        settings.isJustified = false

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(
            ReaderSettings.self, from: data
        )

        XCTAssertEqual(decoded, settings)
    }

    func testSettingsStorePersistsAcrossInstances() {
        let suiteName = "lumen-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = SettingsStore(defaults: defaults)
        store.update { current in
            var next = current
            next.theme = .ink
            next.fontSize = 22
            return next
        }

        let reloaded = SettingsStore(defaults: defaults)
        XCTAssertEqual(reloaded.settings.theme, .ink)
        XCTAssertEqual(reloaded.settings.fontSize, 22)
    }

    // MARK: - Reader CSS

    func testReaderStyleEmitsThemeAndTypography() {
        var settings = ReaderSettings()
        settings.theme = .sepia
        settings.font = .georgia
        settings.fontSize = 19
        settings.horizontalMargin = 30

        let css = ReaderStyle.css(
            settings: settings, pageWidth: 390, pageHeight: 844
        )

        XCTAssertTrue(css.contains(ReaderTheme.sepia.backgroundHex))
        XCTAssertTrue(css.contains(ReaderTheme.sepia.textHex))
        XCTAssertTrue(css.contains("font-size: 19.0px"))
        XCTAssertTrue(css.contains("Georgia"))
        // Column width must equal page width minus both margins so each
        // column is exactly one page.
        XCTAssertTrue(css.contains("column-width: 330.0px"))
        XCTAssertTrue(css.contains("column-gap: 60.0px"))
        XCTAssertTrue(css.contains("text-align: justify"))
    }

    func testReaderStyleLeftAlignsWhenJustificationOff() {
        var settings = ReaderSettings()
        settings.isJustified = false
        let css = ReaderStyle.css(
            settings: settings, pageWidth: 390, pageHeight: 844
        )
        XCTAssertTrue(css.contains("text-align: left"))
    }

    func testReaderStyleClearsLandscapeSafeAreas() {
        let css = ReaderStyle.css(
            settings: ReaderSettings(),
            pageWidth: 874,
            pageHeight: 402,
            safeAreaLeft: 59,
            safeAreaRight: 21
        )

        // Safe-area insets set the floor; the measure cap then widens both
        // margins equally, so 739pt of available width becomes a 612pt
        // column (34em at the 18pt default) with the surplus split evenly.
        XCTAssertTrue(css.contains("padding: 64.0px 127.5px 44.0px 134.5px"))
        XCTAssertTrue(css.contains("column-width: 612.0px"))
        XCTAssertTrue(css.contains("column-gap: 262.0px"))
        XCTAssertTrue(css.contains("max-height: 294.0px"))
    }

    func testReaderStyleKeepsHardwareSafeLandscapeMarginsWhenInsetsLag() {
        let css = ReaderStyle.css(
            settings: ReaderSettings(),
            pageWidth: 874,
            pageHeight: 402,
            safeAreaLeft: 0,
            safeAreaRight: 0
        )

        XCTAssertTrue(css.contains("padding: 64.0px 131.0px 44.0px 131.0px"))
        XCTAssertTrue(css.contains("column-width: 612.0px"))
    }

    func testReaderStyleCapsTheMeasureOnWideScreens() {
        // An 11-inch iPad in portrait: without a cap the column would run
        // the full 834pt, about 110 characters a line.
        let css = ReaderStyle.css(
            settings: ReaderSettings(), pageWidth: 834, pageHeight: 1194
        )

        let cap = ReaderSettings().fontSize * ReaderStyle.maximumMeasureEm
        XCTAssertTrue(css.contains("column-width: \(cap)px"))
        // Paged flow pages by whole viewports, so the column plus its gap
        // must still add up to the page width.
        XCTAssertTrue(css.contains("column-gap: \(834 - cap)px"))
    }

    func testReaderStyleLeavesNarrowScreensUncapped() {
        // A phone is nowhere near the cap: margins stay exactly as set.
        var settings = ReaderSettings()
        settings.horizontalMargin = 20
        let css = ReaderStyle.css(
            settings: settings, pageWidth: 390, pageHeight: 844
        )

        XCTAssertTrue(css.contains("column-width: 350.0px"))
        XCTAssertTrue(css.contains("column-gap: 40.0px"))
    }

    func testReaderStyleNeutralizesPublisherMediaSizing() {
        // Real EPUBs (e.g. calibre) pin images to fixed pt sizes that
        // break column pagination; our reset must force them to fit one
        // column with !important so a publisher rule can't win.
        let css = ReaderStyle.css(
            settings: ReaderSettings(), pageWidth: 390, pageHeight: 844
        )
        XCTAssertTrue(css.contains("object-fit: contain !important"))
        XCTAssertTrue(css.contains("max-height: 676.0px !important"))
        XCTAssertTrue(css.contains("height: auto !important"))
        // Common calibre image classes are explicitly targeted.
        XCTAssertTrue(css.contains(".calibre1"))
        XCTAssertTrue(css.contains(".calibre2"))
    }

    // MARK: - Bundled reader fonts

    func testBundledFontStacksNameTheirFamily() {
        XCTAssertTrue(ReaderFont.crimson.cssFamily.contains("Crimson Pro"))
        XCTAssertTrue(
            ReaderFont.cormorant.cssFamily.contains("Cormorant Garamond"))
        // Bundled fonts declare which .ttf must be embedded; system
        // fonts declare none.
        XCTAssertNotNil(ReaderFont.crimson.bundledFontFile)
        XCTAssertNotNil(ReaderFont.cormorant.bundledFontFile)
        XCTAssertNil(ReaderFont.newYork.bundledFontFile)
        XCTAssertNil(ReaderFont.georgia.bundledFontFile)
    }

    func testSystemFontEmitsNoFontFace() {
        var settings = ReaderSettings()
        settings.font = .georgia
        let css = ReaderStyle.css(
            settings: settings, pageWidth: 390, pageHeight: 844
        )
        XCTAssertFalse(css.contains("@font-face"))
    }

    func testBundledFontEmbedsDataURIWhenResourcePresent() {
        // The .ttf ships in the app bundle, so the reader CSS must carry
        // an @font-face with an inline base64 data: src — the WKWebView
        // does not inherit app-registered fonts.
        var settings = ReaderSettings()
        settings.font = .crimson
        let css = ReaderStyle.css(
            settings: settings, pageWidth: 390, pageHeight: 844
        )
        XCTAssertTrue(css.contains("@font-face"))
        XCTAssertTrue(css.contains("font-family: 'Crimson Pro'"))
        XCTAssertTrue(css.contains("src: url(data:font/ttf;base64,"))
        XCTAssertTrue(css.contains("format('truetype')"))
    }

    // MARK: - Hex blending

    func testBlendHexZeroAmountReturnsBase() {
        XCTAssertEqual(
            Color.blendHex("#FAF6EE", toward: "#FFAE5C", amount: 0),
            "#FAF6EE"
        )
    }

    func testBlendHexFullAmountReturnsTarget() {
        XCTAssertEqual(
            Color.blendHex("#000000", toward: "#FFAE5C", amount: 1),
            "#FFAE5C"
        )
    }

    func testBlendHexMidpoint() {
        XCTAssertEqual(
            Color.blendHex("#000000", toward: "#FFFFFF", amount: 0.5),
            "#808080"
        )
    }

    func testBlendHexClampsAmount() {
        XCTAssertEqual(
            Color.blendHex("#102030", toward: "#FFFFFF", amount: -1),
            "#102030"
        )
        XCTAssertEqual(
            Color.blendHex("#102030", toward: "#FFFFFF", amount: 2),
            "#FFFFFF"
        )
    }

    // MARK: - Theme resolution & warmth

    func testEffectiveThemeManualIgnoresSystemAppearance() {
        var settings = ReaderSettings()
        settings.theme = .paper
        settings.themeMode = .manual
        XCTAssertEqual(settings.effectiveTheme(systemDark: true), .paper)
    }

    func testEffectiveThemeSystemModeSwitchesToDarkTheme() {
        var settings = ReaderSettings()
        settings.theme = .paper
        settings.darkTheme = .ink
        settings.themeMode = .system
        XCTAssertEqual(settings.effectiveTheme(systemDark: false), .paper)
        XCTAssertEqual(settings.effectiveTheme(systemDark: true), .ink)
    }

    func testPaletteWithoutWarmthMatchesTheme() {
        let settings = ReaderSettings()
        let palette = settings.palette(systemDark: false)
        XCTAssertEqual(palette.backgroundHex, ReaderTheme.paper.backgroundHex)
        XCTAssertEqual(palette.textHex, ReaderTheme.paper.textHex)
        XCTAssertEqual(palette.isDark, ReaderTheme.paper.isDark)
    }

    func testPaletteWarmthShiftsBackgroundTowardAmber() {
        var settings = ReaderSettings()
        settings.warmth = 1
        let palette = settings.palette(systemDark: false)
        XCTAssertNotEqual(
            palette.backgroundHex, ReaderTheme.paper.backgroundHex
        )
        // Warm shift must keep accent identity for chrome consistency.
        XCTAssertEqual(palette.accentHex, ReaderTheme.paper.accentHex)
    }

    func testReaderStyleEmitsWarmedBackground() {
        var settings = ReaderSettings()
        settings.warmth = 1
        let warmedBackground = settings.palette(systemDark: false)
            .backgroundHex
        let css = ReaderStyle.css(
            settings: settings, pageWidth: 390, pageHeight: 844
        )
        XCTAssertTrue(css.contains(warmedBackground))
        XCTAssertFalse(css.contains(ReaderTheme.paper.backgroundHex))
    }

    func testReaderStyleSystemDarkUsesDarkTheme() {
        var settings = ReaderSettings()
        settings.themeMode = .system
        settings.darkTheme = .ink
        let css = ReaderStyle.css(
            settings: settings, pageWidth: 390, pageHeight: 844,
            systemDark: true
        )
        XCTAssertTrue(css.contains(ReaderTheme.ink.backgroundHex))
    }

    // MARK: - Settings migration

    func testSettingsDecodeFromLegacyJSONUsesDefaults() throws {
        // Stored settings written before warmth/themeMode/darkTheme
        // existed must decode with safe defaults, not fail.
        let legacyJSON = """
        {"theme":"sepia","font":"georgia","fontSize":20,
         "lineHeight":1.6,"horizontalMargin":30,"isJustified":false}
        """
        let decoded = try JSONDecoder().decode(
            ReaderSettings.self, from: Data(legacyJSON.utf8)
        )
        XCTAssertEqual(decoded.theme, .sepia)
        XCTAssertEqual(decoded.fontSize, 20)
        XCTAssertEqual(decoded.warmth, 0)
        XCTAssertEqual(decoded.themeMode, .system)
        XCTAssertEqual(decoded.darkTheme, .ink)
        XCTAssertEqual(decoded.pageFlow, .paged)
        XCTAssertEqual(decoded.pageTransition, .slide)
    }

    func testRemovedAcademiaThemeFallsBackToDefault() throws {
        // "academia" was removed as a theme. A user who saved it must not
        // have their whole settings decode fail; the removed raw value
        // falls back to the default theme.
        let json = """
        {"theme":"academia","fontSize":18}
        """
        let decoded = try JSONDecoder().decode(
            ReaderSettings.self, from: Data(json.utf8)
        )
        XCTAssertEqual(decoded.theme, ReaderSettings().theme)
        XCTAssertEqual(decoded.fontSize, 18)
    }

    func testSettingsDecodeFromRemovedTransitionFallsBackToDefault() throws {
        // "fade" was removed as a transition. A user who saved it must
        // not have their whole settings decode fail; the removed raw
        // value falls back to the default transition.
        let json = """
        {"theme":"paper","pageTransition":"fade","fontSize":18}
        """
        let decoded = try JSONDecoder().decode(
            ReaderSettings.self, from: Data(json.utf8)
        )
        XCTAssertEqual(decoded.pageTransition, .slide)
        XCTAssertEqual(decoded.theme, .paper)
        XCTAssertFalse(
            PageTransition.allCases.contains { $0.rawValue == "fade" }
        )
    }

    // MARK: - Page flow

    func testReaderStyleScrollModeOmitsColumnsAndAllowsFlow() {
        var settings = ReaderSettings()
        settings.pageFlow = .scroll
        let css = ReaderStyle.css(
            settings: settings, pageWidth: 390, pageHeight: 844
        )
        XCTAssertFalse(css.contains("column-width"))
        XCTAssertFalse(css.contains("overflow: hidden"))
        XCTAssertTrue(css.contains(ReaderTheme.paper.backgroundHex))
    }

    func testReaderStylePagedModeKeepsColumns() {
        let css = ReaderStyle.css(
            settings: ReaderSettings(), pageWidth: 390, pageHeight: 844
        )
        XCTAssertTrue(css.contains("column-width"))
    }

    func testEngineScriptCarriesFlowAndTransition() {
        let paged = ReaderScripts.engine(
            pageWidth: 390, flow: .paged, transition: .fade
        )
        XCTAssertTrue(paged.contains("\"paged\""))
        // Fade's persisted rawValue is the legacy "eink".
        XCTAssertTrue(paged.contains("\"eink\""))

        let scroll = ReaderScripts.engine(
            pageWidth: 390, flow: .scroll, transition: .slide
        )
        XCTAssertTrue(scroll.contains("\"scroll\""))
    }

    func testCurlAndInstantTransitionsRoundTrip() throws {
        XCTAssertEqual(PageTransition.curl.rawValue, "curl")
        XCTAssertEqual(PageTransition.instant.rawValue, "instant")

        var settings = ReaderSettings()
        settings.pageTransition = .curl
        let decoded = try JSONDecoder().decode(
            ReaderSettings.self, from: JSONEncoder().encode(settings)
        )
        XCTAssertEqual(decoded.pageTransition, .curl)

        // Curl must ride the engine's animated-scroll branch (Swift picks
        // the choreography); the engine carries the raw transition value.
        let curl = ReaderScripts.engine(
            pageWidth: 390, flow: .paged, transition: .curl
        )
        XCTAssertTrue(curl.contains("transition: \"curl\""))
        XCTAssertTrue(curl.contains("=== \"curl\""))
    }

    // MARK: - Highlights

    func testBookDecodesLegacyJSONWithoutHighlights() throws {
        // Library indexes written before highlights existed must load.
        let legacyJSON = """
        {"id":"\(UUID().uuidString)","title":"T","author":"A",
         "fileName":"f.epub","addedAt":700000000,
         "progress":{"spineIndex":0,"pageFraction":0,"bookFraction":0},
         "bookmarks":[],"spineWeights":[1]}
        """
        let decoded = try JSONDecoder().decode(
            Book.self, from: Data(legacyJSON.utf8)
        )
        XCTAssertEqual(decoded.title, "T")
        XCTAssertTrue(decoded.highlights.isEmpty)
    }

    func testHighlightCodableRoundTrip() throws {
        let highlight = Highlight(
            spineIndex: 2, text: "a soft amber pulse",
            occurrence: 1, chapterTitle: "Under the Glass"
        )
        let data = try JSONEncoder().encode(highlight)
        let decoded = try JSONDecoder().decode(Highlight.self, from: data)
        XCTAssertEqual(decoded, highlight)
    }

    func testHighlightWithoutNoteKeyDecodesAsNil() throws {
        // Highlights persisted before notes existed have no `note` key;
        // synthesized Codable must tolerate that and yield nil.
        let legacyJSON = """
        {"id":"\(UUID().uuidString)","spineIndex":0,"text":"t",
         "occurrence":0,"chapterTitle":"C","createdAt":700000000}
        """
        let decoded = try JSONDecoder().decode(
            Highlight.self, from: Data(legacyJSON.utf8)
        )
        XCTAssertNil(decoded.note)
    }

    func testBookHighlightsWithoutNoteKeyDecodeAsNil() throws {
        // A whole Book index written before notes must load with nil notes.
        let legacyJSON = """
        {"id":"\(UUID().uuidString)","title":"T","author":"A",
         "fileName":"f.epub","addedAt":700000000,
         "progress":{"spineIndex":0,"pageFraction":0,"bookFraction":0},
         "bookmarks":[],"spineWeights":[1],
         "highlights":[{"id":"\(UUID().uuidString)","spineIndex":0,
           "text":"t","occurrence":0,"chapterTitle":"C",
           "createdAt":700000000}]}
        """
        let decoded = try JSONDecoder().decode(
            Book.self, from: Data(legacyJSON.utf8)
        )
        XCTAssertEqual(decoded.highlights.count, 1)
        XCTAssertNil(decoded.highlights.first?.note)
    }

    func testHighlightNoteRoundTrips() throws {
        let highlight = Highlight(
            spineIndex: 2, text: "a soft amber pulse",
            occurrence: 1, chapterTitle: "Under the Glass",
            note: "translation: lágy borostyán lüktetés"
        )
        let data = try JSONEncoder().encode(highlight)
        let decoded = try JSONDecoder().decode(Highlight.self, from: data)
        XCTAssertEqual(decoded.note, highlight.note)
        XCTAssertEqual(decoded, highlight)
    }

    func testFadeTransitionShipsVeilOverlay() {
        let script = ReaderScripts.engine(
            pageWidth: 390, flow: .paged, transition: .fade
        )
        XCTAssertTrue(script.contains("fadeSwap"))

        let css = ReaderStyle.css(
            settings: ReaderSettings(), pageWidth: 390, pageHeight: 844
        )
        XCTAssertTrue(css.contains("#lumen-fade"))
    }

    func testFadeVeilIsPageBackgroundNeverInk() {
        // The fade must wash through blank paper — never black or the
        // text colour — in every theme (the ink flash was e-paper only).
        var dark = ReaderSettings()
        dark.theme = .dusk
        let darkCSS = ReaderStyle.css(
            settings: dark, pageWidth: 390, pageHeight: 844
        )
        XCTAssertFalse(darkCSS.contains("background: #000000"))
        XCTAssertFalse(
            darkCSS.contains("background: \(ReaderTheme.dusk.textHex)")
        )

        let lightCSS = ReaderStyle.css(
            settings: ReaderSettings(), pageWidth: 390, pageHeight: 844
        )
        XCTAssertFalse(
            lightCSS.contains("background: \(ReaderTheme.paper.textHex)")
        )
        XCTAssertTrue(
            lightCSS.contains("background: \(ReaderTheme.paper.backgroundHex)")
        )
    }

    func testEngineRevealsAtDOMContentLoadedWithFallback() {
        // Waiting for the full load event leaves the page blank while
        // a slow or missing image loads; the engine must start at
        // DOMContentLoaded and keep a timeout safety net.
        let script = ReaderScripts.engine(
            pageWidth: 390, flow: .paged, transition: .slide
        )
        XCTAssertTrue(script.contains("DOMContentLoaded"))
        XCTAssertTrue(script.contains("setTimeout(start"))
    }

    func testEngineScriptContainsSelectionAndHighlightAPI() {
        let script = ReaderScripts.engine(
            pageWidth: 390, flow: .paged, transition: .slide
        )
        XCTAssertTrue(script.contains("selectionLocator"))
        XCTAssertTrue(script.contains("applyHighlights"))
    }

    func testHighlightLocatorJSONIsValidJS() throws {
        // Book text can contain quotes/backslashes; the payload passed
        // to applyHighlights must stay valid JSON.
        let tricky = Highlight(
            spineIndex: 0, text: "she said \"wait\" \\ twice",
            occurrence: 0, chapterTitle: "C"
        )
        let json = ReaderScripts.highlightsJSON([tricky])
        let parsed = try JSONSerialization.jsonObject(
            with: Data(json.utf8)
        ) as? [[String: Any]]
        XCTAssertEqual(parsed?.first?["text"] as? String, tricky.text)
        XCTAssertEqual(parsed?.first?["occurrence"] as? Int, 0)
    }
}
