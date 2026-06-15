import XCTest
import SQLite3
import ZIPFoundation
@testable import Quire

/// Round-trips a generated `.apkg`: unzips it, opens the SQLite collection,
/// and asserts the structural invariants Anki requires to import a deck
/// (a model, a deck, notes with a matching `mid`, cards with matching
/// `nid`/`did`). Opening the SQLite is the proxy for "Anki can parse it":
/// a malformed collection would fail to query.
final class AnkiPackageTests: XCTestCase {

    private var tempRoot: URL!

    override func setUpWithError() throws {
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("apkg-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: tempRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempRoot)
    }

    // MARK: - Fixtures

    private func sampleEntries() -> [VocabularyEntry] {
        [
            VocabularyEntry(
                word: "lantern",
                definition: "a portable light",
                contextSentence: "She raised the lantern high.",
                dictionarySource: "WordNet"
            ),
            VocabularyEntry(
                word: "ephemeral",
                definition: "lasting a very short time",
                contextSentence: nil,
                dictionarySource: "WordNet"
            ),
            VocabularyEntry(
                // special chars: quote, ampersand, comma, non-ASCII.
                word: "café",
                definition: "a coffee house, & a haunt",
                contextSentence: "He's in the café, reading <Proust>.",
                dictionarySource: "Larousse"
            )
        ]
    }

    private func buildAndUnzip(
        _ entries: [VocabularyEntry]
    ) throws -> URL {
        let pkg = try AnkiPackage.build(
            for: entries, directory: tempRoot)
        let unzipped = tempRoot.appendingPathComponent(
            "unzipped-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: unzipped, withIntermediateDirectories: true)
        try FileManager.default.unzipItem(at: pkg, to: unzipped)
        return unzipped
    }

    // MARK: - Archive shape

    func testPackageContainsCollectionAndEmptyMedia() throws {
        let unzipped = try buildAndUnzip(sampleEntries())

        let collection = unzipped
            .appendingPathComponent("collection.anki2")
        let media = unzipped.appendingPathComponent("media")

        XCTAssertTrue(
            FileManager.default.fileExists(atPath: collection.path))
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: media.path))

        let mediaContents = try String(
            contentsOf: media, encoding: .utf8)
        XCTAssertEqual(mediaContents, "{}")
    }

    // MARK: - SQLite round-trip

    func testCollectionRowHasModelAndDeckJSON() throws {
        let db = try openCollection(for: sampleEntries())
        defer { sqlite3_close(db) }

        let rows = queryRows(db, "SELECT models, decks FROM col;")
        XCTAssertEqual(rows.count, 1)
        let models = rows[0][0] ?? ""
        let decks = rows[0][1] ?? ""

        XCTAssertFalse(models.isEmpty)
        XCTAssertFalse(decks.isEmpty)
        // Our single model id is the key in the models map.
        XCTAssertTrue(models.contains("\(AnkiPackage.modelID)"))
        // The deck name appears in the decks JSON.
        XCTAssertTrue(decks.contains("Quire Vocabulary"))
    }

    func testNoteAndCardCountsMatchEntries() throws {
        let entries = sampleEntries()
        let db = try openCollection(for: entries)
        defer { sqlite3_close(db) }

        XCTAssertEqual(
            scalar(db, "SELECT COUNT(*) FROM notes;"), Int64(entries.count))
        XCTAssertEqual(
            scalar(db, "SELECT COUNT(*) FROM cards;"), Int64(entries.count))
    }

    func testNoteFieldsContainWordAndDefinition() throws {
        let db = try openCollection(for: sampleEntries())
        defer { sqlite3_close(db) }

        let flds = queryRows(db, "SELECT flds FROM notes;")
            .compactMap { $0[0] }
        let joined = flds.joined(separator: "\n")
        XCTAssertTrue(joined.contains("lantern"))
        XCTAssertTrue(joined.contains("a portable light"))
        XCTAssertTrue(joined.contains("She raised the lantern high."))
        // Special chars are HTML-escaped, not dropped.
        XCTAssertTrue(joined.contains("a coffee house, &amp; a haunt"))
        XCTAssertTrue(joined.contains("&lt;Proust&gt;"))
        // Non-ASCII survives the round-trip.
        XCTAssertTrue(joined.contains("café"))
    }

    func testCardsReferenceTheirNotesAndDeck() throws {
        let db = try openCollection(for: sampleEntries())
        defer { sqlite3_close(db) }

        // Every card points at an existing note (nid join) ...
        let orphanCards = scalar(
            db,
            """
            SELECT COUNT(*) FROM cards
            WHERE nid NOT IN (SELECT id FROM notes);
            """)
        XCTAssertEqual(orphanCards, 0)

        // ... lives in our deck, and is ord 0.
        XCTAssertEqual(
            scalar(
                db,
                "SELECT COUNT(*) FROM cards WHERE did = \(AnkiPackage.deckID);"),
            Int64(sampleEntries().count))
        XCTAssertEqual(
            scalar(db, "SELECT COUNT(*) FROM cards WHERE ord != 0;"), 0)
    }

    func testNotesReferenceTheModel() throws {
        let db = try openCollection(for: sampleEntries())
        defer { sqlite3_close(db) }

        XCTAssertEqual(
            scalar(
                db,
                "SELECT COUNT(*) FROM notes WHERE mid = \(AnkiPackage.modelID);"),
            Int64(sampleEntries().count))
    }

    func testGravesAndRevlogAreEmpty() throws {
        let db = try openCollection(for: sampleEntries())
        defer { sqlite3_close(db) }

        XCTAssertEqual(scalar(db, "SELECT COUNT(*) FROM graves;"), 0)
        XCTAssertEqual(scalar(db, "SELECT COUNT(*) FROM revlog;"), 0)
    }

    func testCollectionVersionIs11() throws {
        let db = try openCollection(for: sampleEntries())
        defer { sqlite3_close(db) }

        XCTAssertEqual(scalar(db, "SELECT ver FROM col;"), 11)
    }

    // MARK: - Determinism (stable re-import)

    func testGuidsAreStableAcrossBuilds() throws {
        let entries = sampleEntries()

        let firstGuids = try guids(for: entries)
        // A second build at a different time must yield identical guids,
        // so Anki updates rather than duplicates on re-import.
        Thread.sleep(forTimeInterval: 0.01)
        let secondGuids = try guids(for: entries)

        XCTAssertEqual(firstGuids, secondGuids)
        XCTAssertEqual(Set(firstGuids).count, entries.count) // unique
    }

    func testGuidDependsOnlyOnWordCaseInsensitively() {
        let lower = VocabularyEntry(
            word: "lantern", definition: "x", dictionarySource: "s")
        let upper = VocabularyEntry(
            word: "Lantern", definition: "different def",
            dictionarySource: "other")
        XCTAssertEqual(
            AnkiPackage.guid(for: lower), AnkiPackage.guid(for: upper))
    }

    func testEmptyEntriesProduceValidEmptyDeck() throws {
        let db = try openCollection(for: [])
        defer { sqlite3_close(db) }

        XCTAssertEqual(scalar(db, "SELECT COUNT(*) FROM notes;"), 0)
        XCTAssertEqual(scalar(db, "SELECT COUNT(*) FROM cards;"), 0)
        // Model and deck still exist so the deck imports cleanly.
        let rows = queryRows(db, "SELECT models, decks FROM col;")
        XCTAssertTrue((rows.first?[1] ?? "").contains("Quire Vocabulary"))
    }

    // MARK: - SQLite helpers

    private func guids(
        for entries: [VocabularyEntry]
    ) throws -> [String] {
        let db = try openCollection(for: entries)
        defer { sqlite3_close(db) }
        return queryRows(db, "SELECT guid FROM notes ORDER BY id;")
            .compactMap { $0[0] }
    }

    private func openCollection(
        for entries: [VocabularyEntry]
    ) throws -> OpaquePointer? {
        let unzipped = try buildAndUnzip(entries)
        let collection = unzipped
            .appendingPathComponent("collection.anki2")
        var db: OpaquePointer?
        XCTAssertEqual(
            sqlite3_open(collection.path, &db), SQLITE_OK,
            "collection.anki2 must open as a SQLite database")
        return db
    }

    private func scalar(_ db: OpaquePointer?, _ sql: String) -> Int64 {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            XCTFail("prepare failed: \(sql)")
            return -1
        }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else { return -1 }
        return sqlite3_column_int64(stmt, 0)
    }

    private func queryRows(
        _ db: OpaquePointer?, _ sql: String
    ) -> [[String?]] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            XCTFail("prepare failed: \(sql)")
            return []
        }
        defer { sqlite3_finalize(stmt) }

        var rows: [[String?]] = []
        let columns = sqlite3_column_count(stmt)
        while sqlite3_step(stmt) == SQLITE_ROW {
            var row: [String?] = []
            for col in 0..<columns {
                if let cString = sqlite3_column_text(stmt, col) {
                    row.append(String(cString: cString))
                } else {
                    row.append(nil)
                }
            }
            rows.append(row)
        }
        return rows
    }
}
