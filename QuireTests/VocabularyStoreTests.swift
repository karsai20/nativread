import XCTest
@testable import NativRead

@MainActor
final class VocabularyStoreTests: XCTestCase {

    private var root: URL!

    override func setUp() async throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: root, withIntermediateDirectories: true
        )
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func makeStore() -> VocabularyStore {
        VocabularyStore(rootDirectory: root)
    }

    private func entry(
        word: String, source: String = "WordNet"
    ) -> VocabularyEntry {
        VocabularyEntry(
            word: word, definition: "def of \(word)",
            dictionarySource: source
        )
    }

    func testAddInsertsNewestFirst() {
        let store = makeStore()
        store.addEntry(entry(word: "alpha"))
        store.addEntry(entry(word: "beta"))

        XCTAssertEqual(store.entries.map(\.word), ["beta", "alpha"])
    }

    func testAddDedupesCaseInsensitively() {
        let store = makeStore()
        store.addEntry(entry(word: "Lantern"))
        store.addEntry(entry(word: "lantern"))
        store.addEntry(entry(word: "  LANTERN  "))

        XCTAssertEqual(store.entries.count, 1)
        XCTAssertEqual(store.entries.first?.word, "Lantern")
    }

    func testContainsReflectsSavedState() {
        let store = makeStore()
        XCTAssertFalse(store.contains(word: "lantern"))
        store.addEntry(entry(word: "lantern"))
        XCTAssertTrue(store.contains(word: "LANTERN"))
        XCTAssertFalse(store.contains(word: "   "))
    }

    func testRemove() {
        let store = makeStore()
        store.addEntry(entry(word: "alpha"))
        let id = store.entries.first!.id
        store.removeEntry(id)

        XCTAssertTrue(store.entries.isEmpty)
    }

    func testSetNoteRoundTripAndClear() {
        let store = makeStore()
        store.addEntry(entry(word: "alpha"))
        let id = store.entries.first!.id

        store.setNote(entryID: id, note: "  remember this  ")
        XCTAssertEqual(store.entries.first?.note, "remember this")

        // Blank note clears to nil, never an empty string.
        store.setNote(entryID: id, note: "   ")
        XCTAssertNil(store.entries.first?.note)
    }

    func testPersistsAcrossInstances() {
        let store = makeStore()
        store.addEntry(entry(word: "alpha"))
        store.flushPendingSave()

        let reloaded = makeStore()
        XCTAssertEqual(reloaded.entries.map(\.word), ["alpha"])
    }

    func testTolerantDecodeOfMissingOptionalFields() throws {
        // An older-shape JSON with only the required keys must decode,
        // leaving the optional fields nil.
        let json = """
        [{
          "id": "\(UUID().uuidString)",
          "word": "legacy",
          "definition": "an old saved word",
          "dictionarySource": "WordNet",
          "createdAt": 0
        }]
        """
        let url = root.appendingPathComponent("vocabulary.json")
        try json.data(using: .utf8)!.write(to: url)

        let store = makeStore()
        XCTAssertEqual(store.entries.count, 1)
        let only = store.entries.first
        XCTAssertEqual(only?.word, "legacy")
        XCTAssertNil(only?.contextSentence)
        XCTAssertNil(only?.note)
        XCTAssertNil(only?.bookID)
        XCTAssertNil(only?.chapterTitle)
    }
}
