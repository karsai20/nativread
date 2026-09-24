import XCTest
@testable import NativRead

final class KF8RejectionTests: XCTestCase {

    private func makeDatabase(
        records: [Data],
        type: String = "BOOK",
        creator: String = "MOBI"
    ) -> Data {
        var data = Data(count: 78)
        data.replaceSubrange(60 ..< 64, with: Data(type.utf8))
        data.replaceSubrange(64 ..< 68, with: Data(creator.utf8))
        writeBE16(records.count, at: 76, in: &data)

        let listSize = records.count * 8
        var offset = 78 + listSize
        for record in records {
            var entry = Data(count: 8)
            writeBE32(offset, at: 0, in: &entry)
            data.append(entry)
            offset += record.count
        }
        for record in records {
            data.append(record)
        }
        return data
    }

    private func makeMOBIRecord0(
        compression: Int = 2,
        encryption: Int = 0,
        textRecordCount: Int = 1,
        version: Int = 8,
        fdstIndex: Int = 99,
        fdstCount: Int = 0,
        fragmentIndex: Int = 100,
        skeletonIndex: Int = 101,
        kf8Boundary: Int? = nil
    ) -> Data {
        let headerLength = 0xF8
        var record = Data(count: 0x110)
        writeBE16(compression, at: 0, in: &record)
        writeBE16(textRecordCount, at: 8, in: &record)
        writeBE16(encryption, at: 12, in: &record)
        record.replaceSubrange(16 ..< 20, with: Data("MOBI".utf8))
        writeBE32(headerLength, at: 20, in: &record)
        writeBE32(version, at: 36, in: &record)
        writeBE32(0, at: 0x6C, in: &record)
        writeBE32(kf8Boundary == nil ? 0 : 0x40, at: 0x80, in: &record)
        writeBE32(fdstIndex, at: 0xC0, in: &record)
        writeBE32(fdstCount, at: 0xC4, in: &record)
        writeBE32(fragmentIndex, at: 0xF8, in: &record)
        writeBE32(skeletonIndex, at: 0xFC, in: &record)

        guard let kf8Boundary else { return record }
        // A one-entry EXTH block (type 121) placed where the parser expects
        // it: immediately after the fixed MOBI header.
        var exth = Data(count: 24)
        exth.replaceSubrange(0 ..< 4, with: Data("EXTH".utf8))
        writeBE32(24, at: 4, in: &exth)
        writeBE32(1, at: 8, in: &exth)
        writeBE32(MOBIHeader.exthKF8Boundary, at: 12, in: &exth)
        writeBE32(12, at: 16, in: &exth)
        writeBE32(kf8Boundary, at: 20, in: &exth)
        return record.prefix(16 + headerLength) + exth
    }

    private func writeBE16(_ value: Int, at offset: Int, in data: inout Data) {
        data[offset] = UInt8((value >> 8) & 0xFF)
        data[offset + 1] = UInt8(value & 0xFF)
    }

    private func writeBE32(_ value: Int, at offset: Int, in data: inout Data) {
        data[offset] = UInt8((value >> 24) & 0xFF)
        data[offset + 1] = UInt8((value >> 16) & 0xFF)
        data[offset + 2] = UInt8((value >> 8) & 0xFF)
        data[offset + 3] = UInt8(value & 0xFF)
    }

    private func assertThrowsMOBIError(
        _ expected: MOBIError,
        _ expression: @autoclosure () throws -> Any,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try expression(), file: file, line: line) { error in
            switch (error, expected) {
            case (MOBIError.notPalmDB, .notPalmDB),
                 (MOBIError.notMOBI, .notMOBI):
                break
            default:
                XCTFail("unexpected error \(error)", file: file, line: line)
            }
        }
    }

    private func assertThrowsUnsupported(
        _ expression: @autoclosure () throws -> Any,
        containing expected: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try expression(), file: file, line: line) { error in
            guard case MOBIError.unsupported(let reason) = error else {
                return XCTFail("unexpected error \(error)", file: file, line: line)
            }
            XCTAssertTrue(
                reason.contains(expected),
                "expected unsupported reason to contain \(expected), got \(reason)",
                file: file,
                line: line
            )
        }
    }

    func testPalmDatabaseOutOfRangeRecordsReturnEmptyData() throws {
        let db = try PalmDatabase(data: makeDatabase(records: [
            Data("hello".utf8),
            Data("world".utf8),
        ]))

        XCTAssertEqual(db.recordCount, 2)
        XCTAssertEqual(db.record(99), Data())
        XCTAssertEqual(db.record(-1), Data())
    }

    func testPalmDatabaseRejectsRecordInfoListOverflow() {
        var data = Data(count: 78)
        data.replaceSubrange(60 ..< 64, with: Data("BOOK".utf8))
        data.replaceSubrange(64 ..< 68, with: Data("MOBI".utf8))
        writeBE16(3, at: 76, in: &data)

        assertThrowsMOBIError(.notPalmDB, try PalmDatabase(data: data))
    }

    func testMOBIHeaderRejectsRecordShorterThanPalmDocHeader() {
        assertThrowsMOBIError(.notMOBI, try MOBIHeader(record0: Data(count: 15)))
    }

    func testMOBIHeaderRejectsMissingMOBIMagic() {
        var record0 = Data(count: 40)
        writeBE16(2, at: 0, in: &record0)
        writeBE16(1, at: 8, in: &record0)

        assertThrowsMOBIError(.notMOBI, try MOBIHeader(record0: record0))
    }

    func testMakeBookRejectsDRMProtectedMOBI() {
        let data = makeDatabase(records: [
            makeMOBIRecord0(encryption: 1),
            Data("text".utf8),
        ])

        assertThrowsUnsupported(
            try KF8Converter.makeBook(from: data),
            containing: "DRM-protected"
        )
    }

    func testMakeBookRejectsUnsupportedCompression() {
        let data = makeDatabase(records: [
            makeMOBIRecord0(compression: 1),
            Data("text".utf8),
        ])

        assertThrowsUnsupported(
            try KF8Converter.makeBook(from: data),
            containing: "compression"
        )
    }

    func testMakeBookConvertsLegacyMOBI6() throws {
        let data = makeDatabase(records: [
            makeMOBIRecord0(version: 6),
            Data("<html><body><p>Chapter one</p></body></html>".utf8),
        ])

        let book = try KF8Converter.makeBook(from: data)

        XCTAssertEqual(book.parts.count, 1)
        XCTAssertTrue(book.parts[0].xhtml.contains("<p>Chapter one</p>"))
        // The wrapper replaces the blob's own document tags with one clean set.
        XCTAssertEqual(
            book.parts[0].xhtml.components(separatedBy: "<body>").count - 1, 1
        )
    }

    func testMOBI6SplitsChaptersOnPagebreaksAndResolvesFileposLinks() throws {
        // A filepos is a byte offset into the blob; point it at the byte where
        // the second chapter starts. The placeholder keeps the offset stable
        // because the real value is written back at the same width.
        let placeholder = "0000000000"
        let prefix = "<html><body><a filepos=\(placeholder)>Go</a>"
        let separator = "<mbp:pagebreak/>"
        let target = prefix.utf8.count + separator.utf8.count
        let html = prefix.replacingOccurrences(
            of: placeholder, with: String(format: "%010d", target)
        ) + separator + "<p>Two</p></body></html>"

        let book = try KF8Converter.makeBook(from: makeDatabase(records: [
            makeMOBIRecord0(version: 6),
            Data(html.utf8),
        ]))

        let anchor = String(format: "filepos%010d", target)
        XCTAssertEqual(book.parts.count, 2)
        XCTAssertTrue(
            book.parts[0].xhtml.contains(#"href="part0001.html#\#(anchor)""#),
            "cross-chapter filepos link should resolve, got \(book.parts[0].xhtml)"
        )
        XCTAssertTrue(
            book.parts[1].xhtml.contains(#"<a id="\#(anchor)"></a>"#),
            "the target chapter should carry the anchor, got \(book.parts[1].xhtml)"
        )
        XCTAssertFalse(book.parts.contains { $0.xhtml.contains("mbp:") },
            "Kindle-private tags must not survive")
    }

    func testMOBI6RejectsBlobWithoutText() {
        let data = makeDatabase(records: [
            makeMOBIRecord0(textRecordCount: 0, version: 6),
            Data("<html><body></body></html>".utf8),
        ])

        assertThrowsUnsupported(
            try KF8Converter.makeBook(from: data),
            containing: "no readable text"
        )
    }

    func testMOBIHeaderToleratesRecordTruncatedBeforeKF8Offsets() throws {
        // MOBI magic present but the record ends before the fixed KF8 field
        // offsets (0x6C…0xFC): reads must degrade to 0, not trap out of bounds.
        var record0 = Data(count: 44)
        writeBE16(2, at: 0, in: &record0)
        writeBE16(1, at: 8, in: &record0)
        record0.replaceSubrange(16 ..< 20, with: Data("MOBI".utf8))

        let header = try MOBIHeader(record0: record0)
        XCTAssertEqual(header.fdstIndex, 0)
        XCTAssertEqual(header.skeletonIndex, 0)
    }

    func testMakeBookRejectsZeroTextRecords() {
        // textRecordCount == 0 must reject gracefully, not trap on 1...0.
        let data = makeDatabase(records: [
            makeMOBIRecord0(textRecordCount: 0),
            Data("<html><body>Text</body></html>".utf8),
        ])

        assertThrowsUnsupported(
            try KF8Converter.makeBook(from: data),
            containing: "no readable text"
        )
    }

    func testMOBIIndexStopsOnOverstatedDataRecordCount() {
        // A header claiming ~2 billion data records over an empty supplier
        // must return promptly instead of spinning through the whole range.
        var header = Data(count: 0x1C)
        header.replaceSubrange(0 ..< 4, with: Data("INDX".utf8))
        writeBE32(0x7FFF_FFFF, at: 0x18, in: &header)
        var tagx = Data("TAGX".utf8)
        var meta = Data(count: 8)
        writeBE32(16, at: 0, in: &meta)  // firstEntryOffset
        writeBE32(1, at: 4, in: &meta)   // controlByteCount
        tagx.append(meta)
        tagx.append(contentsOf: [0x01, 0x01, 0x01, 0x00])  // one TagDef
        header.append(tagx)

        let entries = MOBIIndex.parse(headerIndex: 0) { index in
            index == 0 ? header : Data()
        }
        XCTAssertEqual(entries.count, 0)
    }

    func testMakeBookFollowsTheKF8BoundaryOfAHybridMOBI() {
        // A KindleGen .mobi: MOBI6 record 0 with EXTH 121 pointing at the KF8
        // boundary. Getting past the version guard (to the later no-text
        // failure of these synthetic indices) proves the boundary was followed.
        let data = makeDatabase(records: [
            makeMOBIRecord0(version: 6, kf8Boundary: 2),
            Data("mobi6 text".utf8),
            makeMOBIRecord0(version: 8),
            Data("<html><body>Text</body></html>".utf8),
        ])

        assertThrowsUnsupported(
            try KF8Converter.makeBook(from: data),
            containing: "no readable text"
        )
    }

    func testMakeBookFallsBackToMOBI6WhenTheBoundaryIsOutOfRange() throws {
        // A corrupt EXTH 121 must fall back to the MOBI6 header and its own
        // text, not index past the end of the record list.
        let book = try KF8Converter.makeBook(from: makeDatabase(records: [
            makeMOBIRecord0(version: 6, kf8Boundary: 99),
            Data("<html><body><p>Legacy</p></body></html>".utf8),
        ]))

        XCTAssertEqual(book.parts.count, 1)
        XCTAssertTrue(book.parts[0].xhtml.contains("Legacy"))
    }

    func testRebasedDatabaseRenumbersRecordsFromTheBoundary() throws {
        let db = try PalmDatabase(data: makeDatabase(records: [
            Data("zero".utf8),
            Data("one".utf8),
            Data("two".utf8),
        ]))

        let rebased = try XCTUnwrap(db.rebased(at: 1))
        XCTAssertEqual(rebased.recordCount, 2)
        XCTAssertEqual(rebased.record(0), Data("one".utf8))
        XCTAssertEqual(rebased.record(1), Data("two".utf8))
        XCTAssertEqual(rebased.record(2), Data())
        XCTAssertNil(db.rebased(at: 3), "out-of-range boundary must not rebase")
    }

    func testMakeBookRejectsBogusKF8IndexRecordsWithoutReadableText() {
        let data = makeDatabase(records: [
            makeMOBIRecord0(
                fdstIndex: 50,
                fragmentIndex: 51,
                skeletonIndex: 52
            ),
            Data("<html><body>Text</body></html>".utf8),
        ])

        assertThrowsUnsupported(
            try KF8Converter.makeBook(from: data),
            containing: "no readable text"
        )
    }

    func testMOBI6StripsControlBytesAndShipsTolerantHTML() throws {
        // A NUL between text runs is what made the strict XML parser abandon
        // the document ("error on line 5 ... char 0x0").
        let html = "<html><body><p>Chapter\u{0}\u{1} one</p><br></body></html>"
        let book = try KF8Converter.makeBook(from: makeDatabase(records: [
            makeMOBIRecord0(version: 6),
            Data(html.utf8),
        ]))

        let part = book.parts[0]
        XCTAssertEqual(part.name, "part0000.html",
            "MOBI6 output must be parsed as HTML, not XHTML")
        XCTAssertTrue(part.xhtml.contains("<p>Chapter one</p>"))
        XCTAssertFalse(part.xhtml.unicodeScalars.contains { $0.value == 0 },
            "no NUL may survive into a chapter")
        // Tabs and newlines are real whitespace and must not be stripped.
        XCTAssertTrue(
            try XCTUnwrap(
                KF8Converter.makeBook(from: makeDatabase(records: [
                    makeMOBIRecord0(version: 6),
                    Data("<html><body><p>a\tb\nc</p></body></html>".utf8),
                ])).parts.first
            ).xhtml.contains("a\tb\nc")
        )
    }
}
