import XCTest
@testable import LumenRead

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
}
