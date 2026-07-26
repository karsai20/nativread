import XCTest
import ZIPFoundation
@testable import NativRead

final class EPUBArchiveValidatorTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: temporaryDirectory, withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: temporaryDirectory)
    }

    func testRelativePathValidationRejectsTraversalAndAbsolutePaths() {
        XCTAssertTrue(EPUBArchiveValidator.isSafeRelativePath("OEBPS/ch1.xhtml"))
        XCTAssertFalse(EPUBArchiveValidator.isSafeRelativePath("../escape"))
        XCTAssertFalse(EPUBArchiveValidator.isSafeRelativePath("OEBPS/../escape"))
        XCTAssertFalse(EPUBArchiveValidator.isSafeRelativePath("/etc/passwd"))
        XCTAssertFalse(EPUBArchiveValidator.isSafeRelativePath("C:/Windows/file"))
        XCTAssertFalse(EPUBArchiveValidator.isSafeRelativePath("OEBPS\\..\\escape"))
    }

    func testValidSmallArchivePasses() throws {
        let url = temporaryDirectory.appendingPathComponent("safe.epub")
        let archive = try Archive(url: url, accessMode: .create)
        let data = Data("application/epub+zip".utf8)
        try archive.addEntry(
            with: "mimetype", type: .file,
            uncompressedSize: Int64(data.count), compressionMethod: .none
        ) { position, size in
            data.subdata(in: Int(position)..<Int(position) + size)
        }
        XCTAssertNoThrow(try EPUBArchiveValidator.validate(at: url))
    }

    func testEmptyFileIsRejected() throws {
        let url = temporaryDirectory.appendingPathComponent("empty.epub")
        try Data().write(to: url)
        XCTAssertThrowsError(try EPUBArchiveValidator.validate(at: url))
    }
}
