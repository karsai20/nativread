import XCTest
import ZIPFoundation
@testable import NativRead

/// The free chapter uploads only what it needs: the book up to its first real
/// chapter, and nothing after it.
final class SampleEPUBBuilderTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = try EPUBFixtures.makeTempDirectory()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func words(_ count: Int) -> String {
        Array(repeating: "lantern", count: count).joined(separator: " ")
    }

    /// A four-part book whose parts carry the given bodies, zipped.
    private func makeBook(_ bodies: [String]) throws -> URL {
        let root = directory.appendingPathComponent("book")
        try EPUBFixtures.writeEPUB3(to: root, chapterCount: bodies.count)
        for (index, body) in bodies.enumerated() {
            try EPUBFixtures.chapterXHTML(title: "Part \(index + 1)", body: body).write(
                to: root.appendingPathComponent("OEBPS/ch\(index + 1).xhtml"),
                atomically: true, encoding: .utf8
            )
        }
        let epub = directory.appendingPathComponent("book.epub")
        try EPUBFixtures.zipEPUB(directory: root, to: epub)
        return epub
    }

    private func buildSample(from epub: URL, named name: String = "sample.epub") throws -> URL {
        let sample = directory.appendingPathComponent(name)
        try SampleEPUBBuilder.build(from: epub, to: sample)
        return sample
    }

    private func paths(in epub: URL) throws -> [String] {
        try Archive(url: epub, accessMode: .read).map(\.path)
    }

    func testKeepsTheBookUpToItsFirstRealChapterAndNothingAfter() throws {
        let epub = try makeBook(["A title page.", words(400), words(400), words(400)])

        let kept = try paths(in: buildSample(from: epub))

        XCTAssertEqual(kept.first, "mimetype")
        for path in ["OEBPS/content.opf", "OEBPS/nav.xhtml", "OEBPS/ch1.xhtml", "OEBPS/ch2.xhtml"] {
            XCTAssertTrue(kept.contains(path), "\(path) should be in the sample")
        }
        XCTAssertFalse(kept.contains("OEBPS/ch3.xhtml"))
        XCTAssertFalse(kept.contains("OEBPS/ch4.xhtml"))
    }

    func testTheMimetypeStaysFirstAndUncompressed() throws {
        let sample = try buildSample(from: makeBook([words(400), words(400)]))

        let archive = try Archive(url: sample, accessMode: .read)
        let first = try XCTUnwrap(archive.first { _ in true })
        XCTAssertEqual(first.path, "mimetype")
        XCTAssertFalse(first.isCompressed)
    }

    func testAContentsPageIsNotTakenForTheFirstChapter() throws {
        let links = (1...120).map { "<a href=\"ch\($0).xhtml\">Chapter number \($0)</a>" }
            .joined(separator: " ")
        let epub = try makeBook([links, words(400), words(400)])

        let kept = try paths(in: buildSample(from: epub))

        XCTAssertTrue(kept.contains("OEBPS/ch2.xhtml"))
        XCTAssertFalse(kept.contains("OEBPS/ch3.xhtml"))
    }

    func testTheSameBookAlwaysCutsToTheSameBytes() throws {
        let epub = try makeBook(["Title.", words(400), words(400)])

        let first = try buildSample(from: epub, named: "one.epub")
        let second = try buildSample(from: epub, named: "two.epub")

        XCTAssertEqual(
            LibraryStore.sourceHash(ofFileAt: first),
            LibraryStore.sourceHash(ofFileAt: second)
        )
    }

    func testTheSampleStillOpensAsABookEndingAfterTheChapter() throws {
        let sample = try buildSample(from: makeBook(["Title.", words(400), words(400)]))
        let unpacked = directory.appendingPathComponent("unpacked")
        try FileManager.default.unzipItem(at: sample, to: unpacked)

        let parsed = try EPUBParser.parse(extractedRoot: unpacked)

        XCTAssertEqual(parsed.spineURLs.map(\.lastPathComponent), ["ch1.xhtml", "ch2.xhtml"])
    }

    func testOnlyTheCoverAndImagesTheKeptChaptersUseGoAlong() throws {
        let epub = try makeBookWithImages()

        let kept = try paths(in: buildSample(from: epub))

        XCTAssertTrue(kept.contains("OEBPS/cover.png"), "the cover names the book")
        XCTAssertTrue(kept.contains("OEBPS/images/early.png"), "a kept chapter shows it")
        XCTAssertFalse(kept.contains("OEBPS/images/late.png"), "only a cut chapter shows it")
    }

    /// Part 2 is the first real chapter and shows early.png; part 3 shows late.png.
    private func makeBookWithImages() throws -> URL {
        let root = directory.appendingPathComponent("book")
        try EPUBFixtures.writeEPUB3(to: root, chapterCount: 3)
        let images = root.appendingPathComponent("OEBPS/images")
        try FileManager.default.createDirectory(at: images, withIntermediateDirectories: true)
        for name in ["early", "late"] {
            try Data([0x89, 0x50, 0x4E, 0x47]).write(to: images.appendingPathComponent("\(name).png"))
        }
        let bodies = ["Title.", "\(words(400)) <img src=\"images/early.png\" alt=\"\"/>", "\(words(400)) <img src=\"images/late.png\" alt=\"\"/>"]
        for (index, body) in bodies.enumerated() {
            try EPUBFixtures.chapterXHTML(title: "Part \(index + 1)", body: body).write(
                to: root.appendingPathComponent("OEBPS/ch\(index + 1).xhtml"),
                atomically: true, encoding: .utf8
            )
        }
        let opf = root.appendingPathComponent("OEBPS/content.opf")
        let manifest = try String(contentsOf: opf, encoding: .utf8).replacingOccurrences(
            of: "</manifest>",
            with: """
            <item id="early" href="images/early.png" media-type="image/png"/>
            <item id="late" href="images/late.png" media-type="image/png"/>
            </manifest>
            """
        )
        try manifest.write(to: opf, atomically: true, encoding: .utf8)
        let epub = directory.appendingPathComponent("book.epub")
        try EPUBFixtures.zipEPUB(directory: root, to: epub)
        return epub
    }

    func testAShortBookWithNoRealChapterIsSentWhole() throws {
        let epub = try makeBook(["Title.", "A short note.", "Another short note."])

        let kept = try paths(in: buildSample(from: epub))

        XCTAssertTrue(kept.contains("OEBPS/ch3.xhtml"))
    }
}
