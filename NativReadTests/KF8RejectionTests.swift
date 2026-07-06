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
        skeletonIndex: Int = 101
    ) -> Data {
        var record = Data(count: 0x110)
        writeBE16(compression, at: 0, in: &record)
        writeBE16(textRecordCount, at: 8, in: &record)
        writeBE16(encryption, at: 12, in: &record)
        record.replaceSubrange(16 ..< 20, with: Data("MOBI".utf8))
        writeBE32(0xF8, at: 20, in: &record)
        writeBE32(version, at: 36, in: &record)
        writeBE32(0, at: 0x6C, in: &record)
        writeBE32(0, at: 0x80, in: &record)
        writeBE32(fdstIndex, at: 0xC0, in: &record)
        writeBE32(fdstCount, at: 0xC4, in: &record)
        writeBE32(fragmentIndex, at: 0xF8, in: &record)
        writeBE32(skeletonIndex, at: 0xFC, in: &record)
        return record
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

    func testMakeBookRejectsLegacyMOBIVersion() {
        let data = makeDatabase(records: [
            makeMOBIRecord0(version: 7),
            Data("text".utf8),
        ])

        assertThrowsUnsupported(
            try KF8Converter.makeBook(from: data),
            containing: "only KF8"
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
}
