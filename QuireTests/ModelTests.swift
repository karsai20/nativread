import SwiftUI
import XCTest
@testable import Quire

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
        XCTAssertEqual(decoded.themeMode, .manual)
        XCTAssertEqual(decoded.darkTheme, .dusk)
        XCTAssertEqual(decoded.pageFlow, .paged)
        XCTAssertEqual(decoded.pageTransition, .slide)
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
        XCTAssertTrue(paged.contains("\"fade\""))

        let scroll = ReaderScripts.engine(
            pageWidth: 390, flow: .scroll, transition: .slide
        )
        XCTAssertTrue(scroll.contains("\"scroll\""))
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

    func testEinkTransitionShipsFlashOverlay() {
        let script = ReaderScripts.engine(
            pageWidth: 390, flow: .paged, transition: .eink
        )
        XCTAssertTrue(script.contains("einkFlash"))

        let css = ReaderStyle.css(
            settings: ReaderSettings(), pageWidth: 390, pageHeight: 844
        )
        XCTAssertTrue(css.contains("#lumen-eink"))
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
