import XCTest
@testable import NativRead

final class DictionaryServiceTests: XCTestCase {

    private var root: URL!

    override func setUp() async throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("dict-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: root, withIntermediateDirectories: true
        )
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: root)
    }

    // MARK: - Fixture builder

    /// One headword -> definition pair to write into a dictionary.
    private struct Pair {
        let headword: String
        let definition: String
    }

    private func bigEndian(_ value: UInt32) -> [UInt8] {
        [
            UInt8((value >> 24) & 0xFF),
            UInt8((value >> 16) & 0xFF),
            UInt8((value >> 8) & 0xFF),
            UInt8(value & 0xFF)
        ]
    }

    /// Writes a synthetic `.ifo`/`.idx`/`.dict` trio, returning the base URLs.
    /// `pairs` are concatenated into `.dict` and indexed in order, exercising
    /// the real byte-level parser (UTF-8 headword + 0x00 + BE offset + BE size).
    private func writeDictionary(
        base: String,
        bookname: String,
        sameTypeSequence: Character?,
        pairs: [Pair]
    ) throws -> (ifo: URL, idx: URL, dict: URL) {
        var dictData = Data()
        var idxData = Data()

        for pair in pairs {
            let defBytes = Data(pair.definition.utf8)
            let offset = UInt32(dictData.count)
            let size = UInt32(defBytes.count)
            dictData.append(defBytes)

            idxData.append(Data(pair.headword.utf8))
            idxData.append(0x00)
            idxData.append(contentsOf: bigEndian(offset))
            idxData.append(contentsOf: bigEndian(size))
        }

        var ifo = "StarDict's dict ifo file\n"
        ifo += "version=3.0.0\n"
        ifo += "bookname=\(bookname)\n"
        ifo += "wordcount=\(pairs.count)\n"
        ifo += "idxfilesize=\(idxData.count)\n"
        if let seq = sameTypeSequence {
            ifo += "sametypesequence=\(seq)\n"
        }

        let ifoURL = root.appendingPathComponent("\(base).ifo")
        let idxURL = root.appendingPathComponent("\(base).idx")
        let dictURL = root.appendingPathComponent("\(base).dict")
        try Data(ifo.utf8).write(to: ifoURL)
        try idxData.write(to: idxURL)
        try dictData.write(to: dictURL)
        return (ifoURL, idxURL, dictURL)
    }

    private func makeDictionary(
        base: String,
        bookname: String,
        sameTypeSequence: Character? = "m",
        pairs: [Pair]
    ) throws -> StarDictionary {
        let urls = try writeDictionary(
            base: base, bookname: bookname,
            sameTypeSequence: sameTypeSequence, pairs: pairs
        )
        return try StarDictionary(
            ifoURL: urls.ifo, idxURL: urls.idx, dictURL: urls.dict
        )
    }

    // MARK: - Lookup behavior

    func testKnownWordReturnsExactDefinition() throws {
        let dict = try makeDictionary(
            base: "en", bookname: "English",
            pairs: [
                Pair(headword: "book", definition: "a written work"),
                Pair(headword: "tree", definition: "a tall plant")
            ]
        )

        let entries = dict.lookup("book")

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.headword, "book")
        XCTAssertEqual(entries.first?.definition, "a written work")
    }

    func testLookupIsCaseInsensitive() throws {
        let dict = try makeDictionary(
            base: "en", bookname: "English",
            pairs: [Pair(headword: "Book", definition: "a written work")]
        )

        for query in ["Book", "book", "BOOK", "bOoK"] {
            let entries = dict.lookup(query)
            XCTAssertEqual(entries.count, 1, "query: \(query)")
            // Original-case headword preserved.
            XCTAssertEqual(entries.first?.headword, "Book")
            XCTAssertEqual(entries.first?.definition, "a written work")
        }
    }

    func testHeadwordWithTwoEntriesReturnsBothInOrder() throws {
        let dict = try makeDictionary(
            base: "en", bookname: "English",
            pairs: [
                Pair(headword: "bank", definition: "river bank"),
                Pair(headword: "bank", definition: "money bank")
            ]
        )

        let entries = dict.lookup("bank")

        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].definition, "river bank")
        XCTAssertEqual(entries[1].definition, "money bank")
    }

    func testMissingWordReturnsEmpty() throws {
        let dict = try makeDictionary(
            base: "en", bookname: "English",
            pairs: [Pair(headword: "book", definition: "a written work")]
        )

        XCTAssertEqual(dict.lookup("absent").count, 0)
    }

    // MARK: - sametypesequence type reporting

    func testHTMLTypeIsReported() throws {
        let dict = try makeDictionary(
            base: "html", bookname: "HTML Dict",
            sameTypeSequence: "h",
            pairs: [Pair(headword: "book", definition: "<b>a written work</b>")]
        )

        let entries = dict.lookup("book")
        XCTAssertEqual(entries.first?.type, "h")
        XCTAssertEqual(entries.first?.definition, "<b>a written work</b>")
    }

    func testPlainTypeIsReported() throws {
        let dict = try makeDictionary(
            base: "plain", bookname: "Plain Dict",
            sameTypeSequence: "m",
            pairs: [Pair(headword: "book", definition: "a written work")]
        )

        XCTAssertEqual(dict.lookup("book").first?.type, "m")
    }

    func testAbsentSameTypeSequenceDefaultsToPlain() throws {
        let dict = try makeDictionary(
            base: "notype", bookname: "No Type",
            sameTypeSequence: nil,
            pairs: [Pair(headword: "book", definition: "a written work")]
        )

        let entries = dict.lookup("book")
        XCTAssertEqual(entries.first?.type, "m")
        XCTAssertEqual(entries.first?.definition, "a written work")
    }

    // MARK: - DictionaryService

    func testServiceMergesResultsAcrossDictionaries() throws {
        let english = try makeDictionary(
            base: "en", bookname: "English",
            pairs: [Pair(headword: "book", definition: "a written work")]
        )
        let hungarian = try makeDictionary(
            base: "hu", bookname: "Hungarian",
            pairs: [Pair(headword: "book", definition: "könyv")]
        )
        let service = DictionaryService(dictionaries: [english, hungarian])

        let results = service.lookup("book")

        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].bookname, "English")
        XCTAssertEqual(results[0].entries.first?.definition, "a written work")
        XCTAssertEqual(results[1].bookname, "Hungarian")
        XCTAssertEqual(results[1].entries.first?.definition, "könyv")
    }

    func testServiceSkipsDictionaryWithNoMatch() throws {
        let english = try makeDictionary(
            base: "en", bookname: "English",
            pairs: [Pair(headword: "book", definition: "a written work")]
        )
        let hungarian = try makeDictionary(
            base: "hu", bookname: "Hungarian",
            pairs: [Pair(headword: "fa", definition: "tree")]
        )
        let service = DictionaryService()
        service.add(english)
        service.add(hungarian)

        let results = service.lookup("book")

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.bookname, "English")
    }

    func testServiceReturnsEmptyWhenNoDictionaryMatches() throws {
        let english = try makeDictionary(
            base: "en", bookname: "English",
            pairs: [Pair(headword: "book", definition: "a written work")]
        )
        let service = DictionaryService(dictionaries: [english])

        XCTAssertTrue(service.lookup("absent").isEmpty)
    }

    // MARK: - Robustness

    func testMalformedIfoMissingMagicThrows() throws {
        let ifoURL = root.appendingPathComponent("bad.ifo")
        let idxURL = root.appendingPathComponent("bad.idx")
        let dictURL = root.appendingPathComponent("bad.dict")
        try Data("not a stardict file\nbookname=Bad\n".utf8).write(to: ifoURL)
        try Data().write(to: idxURL)
        try Data().write(to: dictURL)

        XCTAssertThrowsError(
            try StarDictionary(
                ifoURL: ifoURL, idxURL: idxURL, dictURL: dictURL
            )
        ) { error in
            XCTAssertEqual(error as? DictionaryError, .invalidIfoMagic)
        }
    }

    func testMissingBooknameThrows() throws {
        let ifoURL = root.appendingPathComponent("nobook.ifo")
        let idxURL = root.appendingPathComponent("nobook.idx")
        let dictURL = root.appendingPathComponent("nobook.dict")
        try Data("StarDict's dict ifo file\nversion=3.0.0\n".utf8)
            .write(to: ifoURL)
        try Data().write(to: idxURL)
        try Data().write(to: dictURL)

        XCTAssertThrowsError(
            try StarDictionary(
                ifoURL: ifoURL, idxURL: idxURL, dictURL: dictURL
            )
        ) { error in
            XCTAssertEqual(
                error as? DictionaryError, .missingIfoField("bookname")
            )
        }
    }

    func testTruncatedIdxDoesNotCrash() throws {
        // Build a valid dictionary, then chop the .idx mid-record.
        let urls = try writeDictionary(
            base: "trunc", bookname: "Truncated",
            sameTypeSequence: "m",
            pairs: [
                Pair(headword: "book", definition: "a written work"),
                Pair(headword: "tree", definition: "a tall plant")
            ]
        )
        let fullIdx = try Data(contentsOf: urls.idx)
        // Keep the first complete record plus a partial second record.
        let truncated = fullIdx.prefix(fullIdx.count - 3)
        try truncated.write(to: urls.idx)

        let dict = try StarDictionary(
            ifoURL: urls.ifo, idxURL: urls.idx, dictURL: urls.dict
        )

        // First record still resolves; truncated tail is simply dropped.
        XCTAssertEqual(dict.lookup("book").first?.definition, "a written work")
        XCTAssertTrue(dict.lookup("tree").isEmpty)
    }

    func testTrailingNulTerminatorIsTrimmed() throws {
        // Definition stored with a trailing 0x00, as real dictionaries do.
        var dictData = Data("a written work".utf8)
        dictData.append(0x00)
        let size = UInt32(dictData.count)

        var idxData = Data("book".utf8)
        idxData.append(0x00)
        idxData.append(contentsOf: bigEndian(0))
        idxData.append(contentsOf: bigEndian(size))

        let ifo = "StarDict's dict ifo file\nbookname=Term\nsametypesequence=m\n"
        let ifoURL = root.appendingPathComponent("term.ifo")
        let idxURL = root.appendingPathComponent("term.idx")
        let dictURL = root.appendingPathComponent("term.dict")
        try Data(ifo.utf8).write(to: ifoURL)
        try idxData.write(to: idxURL)
        try dictData.write(to: dictURL)

        let dict = try StarDictionary(
            ifoURL: ifoURL, idxURL: idxURL, dictURL: dictURL
        )
        XCTAssertEqual(dict.lookup("book").first?.definition, "a written work")
    }
}
