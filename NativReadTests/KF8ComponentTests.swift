import XCTest
@testable import NativRead

/// Focused unit tests for the low-level KF8 building blocks, using
/// hand-constructed byte sequences per the PalmDOC and PalmDB specs.
final class PalmDocDecompressorTests: XCTestCase {

    private func decompress(_ bytes: [UInt8]) -> String {
        String(decoding: PalmDocDecompressor.decompress(Data(bytes)), as: UTF8.self)
    }

    func testLiteralAsciiPassesThrough() {
        XCTAssertEqual(decompress([0x41, 0x42, 0x43]), "ABC")
    }

    func testLiteralRunCopiesNextBytes() {
        // 0x03 = copy the next 3 bytes verbatim.
        XCTAssertEqual(decompress([0x03, 0x61, 0x62, 0x63]), "abc")
    }

    func testHighBytesExpandToSpacePlusChar() {
        // 0xC1 = space + (0xC1 XOR 0x80) = space + 'A'.
        XCTAssertEqual(decompress([0xC1]), " A")
    }

    func testLZ77BackReferenceRepeatsEarlierText() {
        // "abc" literal, then a back-reference: distance 3, length 3 → "abcabc".
        // pair = (3 << 3) | (3 - 3) = 0x18, byte0 = 0x80 | (0x18 >> 8) = 0x80.
        XCTAssertEqual(decompress([0x61, 0x62, 0x63, 0x80, 0x18]), "abcabc")
    }

    func testNulLiteral() {
        XCTAssertEqual(PalmDocDecompressor.decompress(Data([0x00])), Data([0x00]))
    }
}

final class PalmDatabaseTests: XCTestCase {

    /// Builds a minimal two-record Palm database in memory.
    private func makeDatabase() -> Data {
        var data = Data(count: 78)
        data.replaceSubrange(60 ..< 64, with: Data("BOOK".utf8))
        data.replaceSubrange(64 ..< 68, with: Data("MOBI".utf8))
        data[76] = 0x00
        data[77] = 0x02 // numRecords = 2

        let record0 = Data("hello".utf8)
        let record1 = Data("world!!".utf8)
        let listSize = 8 * 2
        let record0Offset = 78 + listSize      // 94
        let record1Offset = record0Offset + record0.count

        func offsetEntry(_ offset: Int) -> Data {
            var entry = Data(count: 8)
            entry[0] = UInt8((offset >> 24) & 0xFF)
            entry[1] = UInt8((offset >> 16) & 0xFF)
            entry[2] = UInt8((offset >> 8) & 0xFF)
            entry[3] = UInt8(offset & 0xFF)
            return entry
        }
        data.append(offsetEntry(record0Offset))
        data.append(offsetEntry(record1Offset))
        data.append(record0)
        data.append(record1)
        return data
    }

    func testParsesTypeCreatorAndRecords() throws {
        let db = try PalmDatabase(data: makeDatabase())

        XCTAssertEqual(db.type, "BOOK")
        XCTAssertEqual(db.creator, "MOBI")
        XCTAssertEqual(db.recordCount, 2)
        XCTAssertEqual(String(decoding: db.record(0), as: UTF8.self), "hello")
        XCTAssertEqual(String(decoding: db.record(1), as: UTF8.self), "world!!")
    }

    func testRejectsTruncatedHeader() {
        XCTAssertThrowsError(try PalmDatabase(data: Data(count: 10)))
    }
}
