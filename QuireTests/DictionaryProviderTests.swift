import XCTest
import zlib
@testable import Quire

final class DictionaryProviderTests: XCTestCase {

    private var root: URL!

    override func setUp() async throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("dictprov-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: root, withIntermediateDirectories: true
        )
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: root)
    }

    // MARK: - gzip helper (test side)

    /// Compresses `data` into standard gzip using zlib's `deflate` with
    /// `windowBits = 31` (gzip wrapper). Used to build fixtures for `gunzip`.
    private func gzip(_ data: Data) throws -> Data {
        var stream = z_stream()
        let status = deflateInit2_(
            &stream, Z_DEFAULT_COMPRESSION, Z_DEFLATED,
            31, 8, Z_DEFAULT_STRATEGY,
            ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)
        )
        XCTAssertEqual(status, Z_OK)
        defer { deflateEnd(&stream) }

        var output = Data()
        let chunkSize = 64 * 1024
        var outBuffer = [UInt8](repeating: 0, count: chunkSize)
        var input = [UInt8](data)

        return input.withUnsafeMutableBufferPointer { inPtr -> Data in
            stream.next_in = inPtr.baseAddress
            stream.avail_in = uInt(inPtr.count)

            while true {
                let s: Int32 = outBuffer.withUnsafeMutableBufferPointer { outPtr in
                    stream.next_out = outPtr.baseAddress
                    stream.avail_out = uInt(chunkSize)
                    return deflate(&stream, Z_FINISH)
                }
                let produced = chunkSize - Int(stream.avail_out)
                if produced > 0 {
                    output.append(contentsOf: outBuffer[0..<produced])
                }
                if s == Z_STREAM_END { break }
            }
            return output
        }
    }

    // MARK: - gunzip round-trip

    func testGunzipRoundTripSmallString() throws {
        let original = Data("the quick brown fox jumps over the lazy dog".utf8)
        let compressed = try gzip(original)
        let restored = try gunzip(compressed)
        XCTAssertEqual(restored, original)
    }

    func testGunzipRoundTripWithBinaryBytes() throws {
        var original = Data()
        for i in 0..<512 { original.append(UInt8(i % 256)) }
        let restored = try gunzip(try gzip(original))
        XCTAssertEqual(restored, original)
    }

    func testGunzipRoundTripLargeBufferStreams() throws {
        // ~1 MB of semi-repetitive data to exercise multi-chunk streaming.
        var original = Data()
        original.reserveCapacity(1_048_576)
        var seed: UInt32 = 12345
        for _ in 0..<1_048_576 {
            seed = seed &* 1103515245 &+ 12345
            original.append(UInt8((seed >> 16) & 0xFF))
        }
        let restored = try gunzip(try gzip(original))
        XCTAssertEqual(restored.count, original.count)
        XCTAssertEqual(restored, original)
    }

    func testGunzipEmptyInputThrows() {
        XCTAssertThrowsError(try gunzip(Data())) { error in
            XCTAssertEqual(error as? GunzipError, .emptyInput)
        }
    }

    func testGunzipRejectsNonGzipData() {
        let garbage = Data([0x01, 0x02, 0x03, 0x04, 0x05])
        XCTAssertThrowsError(try gunzip(garbage))
    }

    // MARK: - Provider build from fixture

    /// Writes a synthetic `.ifo`/`.idx` plus a gzip-compressed `.dict.dz`
    /// fixture for `basename` under `root`, mirroring the engine's byte layout.
    private func writeFixture(
        folder: String,
        basename: String,
        bookname: String,
        pairs: [(headword: String, definition: String)]
    ) throws {
        let dir = root.appendingPathComponent(folder, isDirectory: true)
        try FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true
        )

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
        ifo += "sametypesequence=m\n"

        try Data(ifo.utf8).write(to: dir.appendingPathComponent("\(basename).ifo"))
        try idxData.write(to: dir.appendingPathComponent("\(basename).idx"))
        try gzip(dictData).write(
            to: dir.appendingPathComponent("\(basename).dict.dz")
        )
    }

    private func bigEndian(_ value: UInt32) -> [UInt8] {
        [
            UInt8((value >> 24) & 0xFF),
            UInt8((value >> 16) & 0xFF),
            UInt8((value >> 8) & 0xFF),
            UInt8(value & 0xFF)
        ]
    }

    private func loader(for dicts: [BundledDictionary]) -> DictionaryProvider.ResourceLoader {
        let base = root!
        return DictionaryProvider.ResourceLoader { dict in
            let dir = base.appendingPathComponent(dict.folder, isDirectory: true)
            return (
                ifo: dir.appendingPathComponent("\(dict.basename).ifo"),
                idx: dir.appendingPathComponent("\(dict.basename).idx"),
                dictDZ: dir.appendingPathComponent("\(dict.basename).dict.dz")
            )
        }
    }

    func testBuildServiceUnpacksAndLooksUp() throws {
        let dict = BundledDictionary(folder: "en", basename: "en")
        try writeFixture(
            folder: "en", basename: "en", bookname: "English",
            pairs: [
                ("book", "a written work"),
                ("tree", "a tall plant")
            ]
        )
        let support = root.appendingPathComponent("support", isDirectory: true)

        let service = DictionaryProvider.buildService(
            dictionaries: [dict],
            loader: loader(for: [dict]),
            supportDirectory: support
        )

        let results = try XCTUnwrap(service).lookup("book")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.bookname, "English")
        XCTAssertEqual(results.first?.entries.first?.definition, "a written work")

        // The plain .dict was actually written to Application Support.
        let unpacked = support.appendingPathComponent("en/en.dict")
        XCTAssertTrue(FileManager.default.fileExists(atPath: unpacked.path))
    }

    func testBuildServiceSkipsReUnpackWhenDictPresent() throws {
        let dict = BundledDictionary(folder: "en", basename: "en")
        try writeFixture(
            folder: "en", basename: "en", bookname: "English",
            pairs: [("book", "first version")]
        )
        let support = root.appendingPathComponent("support", isDirectory: true)

        _ = DictionaryProvider.buildService(
            dictionaries: [dict], loader: loader(for: [dict]),
            supportDirectory: support
        )

        // Overwrite the unpacked .dict; a re-prepare must NOT clobber it,
        // proving the existing-non-empty file is reused.
        let unpacked = support.appendingPathComponent("en/en.dict")
        try Data("sentinel".utf8).write(to: unpacked)

        let url = try DictionaryProvider.unpackedDictURL(
            for: dict,
            source: root.appendingPathComponent("en/en.dict.dz"),
            in: support
        )
        XCTAssertEqual(try Data(contentsOf: url), Data("sentinel".utf8))
    }

    func testBuildServiceWithMultipleDictionaries() throws {
        let en = BundledDictionary(folder: "en", basename: "en")
        let hu = BundledDictionary(folder: "hu", basename: "hu")
        try writeFixture(
            folder: "en", basename: "en", bookname: "English",
            pairs: [("book", "a written work")]
        )
        try writeFixture(
            folder: "hu", basename: "hu", bookname: "Hungarian",
            pairs: [("book", "könyv")]
        )
        let support = root.appendingPathComponent("support", isDirectory: true)

        let service = try XCTUnwrap(DictionaryProvider.buildService(
            dictionaries: [en, hu], loader: loader(for: [en, hu]),
            supportDirectory: support
        ))

        let results = service.lookup("book")
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].bookname, "English")
        XCTAssertEqual(results[1].bookname, "Hungarian")
        XCTAssertEqual(results[1].entries.first?.definition, "könyv")
    }

    func testBuildServiceReturnsNilWhenResourcesMissing() {
        let missing = BundledDictionary(folder: "ghost", basename: "ghost")
        let support = root.appendingPathComponent("support", isDirectory: true)

        let service = DictionaryProvider.buildService(
            dictionaries: [missing], loader: loader(for: [missing]),
            supportDirectory: support
        )
        XCTAssertNil(service)
    }

    @MainActor
    func testProviderPrepareExposesService() async throws {
        let dict = BundledDictionary(folder: "en", basename: "en")
        try writeFixture(
            folder: "en", basename: "en", bookname: "English",
            pairs: [("book", "a written work")]
        )
        let support = root.appendingPathComponent("support", isDirectory: true)

        let provider = DictionaryProvider(
            dictionaries: [dict],
            resourceLoader: loader(for: [dict]),
            supportDirectory: support
        )

        XCTAssertFalse(provider.isReady)
        XCTAssertTrue(provider.lookup("book").isEmpty)

        await provider.prepare()

        XCTAssertTrue(provider.isReady)
        let results = provider.lookup("book")
        XCTAssertEqual(results.first?.entries.first?.definition, "a written work")
    }
}
