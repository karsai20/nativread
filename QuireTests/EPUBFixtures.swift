import Foundation
import ZIPFoundation
@testable import Quire

/// Builds throwaway EPUB directory trees (and zipped .epub files) in a
/// temp directory so parser tests never depend on bundled resources.
enum EPUBFixtures {

    static func makeTempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumen-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: url, withIntermediateDirectories: true
        )
        return url
    }

    static func chapterXHTML(title: String, body: String) -> String {
        """
        <?xml version="1.0" encoding="utf-8"?>
        <!DOCTYPE html>
        <html xmlns="http://www.w3.org/1999/xhtml">
        <head><title>\(title)</title></head>
        <body><h1>\(title)</h1><p>\(body)</p></body>
        </html>
        """
    }

    /// Writes an unpacked EPUB 3 (nav + NCX + cover) and returns its root.
    @discardableResult
    static func writeEPUB3(
        to root: URL,
        title: String = "Fixture Book",
        author: String = "Test Author",
        chapterCount: Int = 3
    ) throws -> URL {
        let fileManager = FileManager.default
        let oebps = root.appendingPathComponent("OEBPS")
        try fileManager.createDirectory(
            at: root.appendingPathComponent("META-INF"),
            withIntermediateDirectories: true
        )
        try fileManager.createDirectory(
            at: oebps, withIntermediateDirectories: true
        )

        try """
        <?xml version="1.0" encoding="utf-8"?>
        <container version="1.0" \
        xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
          <rootfiles>
            <rootfile full-path="OEBPS/content.opf" \
        media-type="application/oebps-package+xml"/>
          </rootfiles>
        </container>
        """.write(
            to: root.appendingPathComponent("META-INF/container.xml"),
            atomically: true, encoding: .utf8
        )

        var manifest = """
            <item id="nav" href="nav.xhtml" \
        media-type="application/xhtml+xml" properties="nav"/>
            <item id="ncx" href="toc.ncx" \
        media-type="application/x-dtbncx+xml"/>
            <item id="cover-image" href="cover.png" \
        media-type="image/png" properties="cover-image"/>
        """
        var spine = ""
        var navItems = ""
        var navPoints = ""
        for index in 1...chapterCount {
            let name = "ch\(index).xhtml"
            manifest += """

                <item id="ch\(index)" href="\(name)" \
            media-type="application/xhtml+xml"/>
            """
            spine += "\n    <itemref idref=\"ch\(index)\"/>"
            navItems += "\n      <li><a href=\"\(name)\">Part \(index)</a></li>"
            navPoints += """

                <navPoint id="np\(index)" playOrder="\(index)">
                  <navLabel><text>Part \(index)</text></navLabel>
                  <content src="\(name)"/>
                </navPoint>
            """
            try chapterXHTML(
                title: "Part \(index)",
                body: String(
                    repeating: "The lantern burned amber over the bay. ",
                    count: 40
                )
            ).write(
                to: oebps.appendingPathComponent(name),
                atomically: true, encoding: .utf8
            )
        }

        try """
        <?xml version="1.0" encoding="utf-8"?>
        <package xmlns="http://www.idpf.org/2007/opf" version="3.0" \
        unique-identifier="uid">
          <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
            <dc:identifier id="uid">urn:uuid:test</dc:identifier>
            <dc:title>\(title)</dc:title>
            <dc:creator>\(author)</dc:creator>
            <dc:language>en</dc:language>
          </metadata>
          <manifest>
        \(manifest)
          </manifest>
          <spine toc="ncx">\(spine)
          </spine>
        </package>
        """.write(
            to: oebps.appendingPathComponent("content.opf"),
            atomically: true, encoding: .utf8
        )

        try """
        <?xml version="1.0" encoding="utf-8"?>
        <!DOCTYPE html>
        <html xmlns="http://www.w3.org/1999/xhtml" \
        xmlns:epub="http://www.idpf.org/2007/ops">
        <head><title>Contents</title></head>
        <body>
          <nav epub:type="toc">
            <ol>\(navItems)
            </ol>
          </nav>
        </body>
        </html>
        """.write(
            to: oebps.appendingPathComponent("nav.xhtml"),
            atomically: true, encoding: .utf8
        )

        try """
        <?xml version="1.0" encoding="utf-8"?>
        <ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
          <head><meta name="dtb:uid" content="urn:uuid:test"/></head>
          <docTitle><text>\(title)</text></docTitle>
          <navMap>\(navPoints)
          </navMap>
        </ncx>
        """.write(
            to: oebps.appendingPathComponent("toc.ncx"),
            atomically: true, encoding: .utf8
        )

        // 1×1 transparent-ish PNG, hard-coded bytes.
        let pngBase64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ"
            + "AAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
        try Data(base64Encoded: pngBase64)!.write(
            to: oebps.appendingPathComponent("cover.png")
        )

        return root
    }

    /// Writes an unpacked EPUB 2 (NCX only, meta cover) and returns root.
    @discardableResult
    static func writeEPUB2(to root: URL) throws -> URL {
        let fileManager = FileManager.default
        let oebps = root.appendingPathComponent("content")
        try fileManager.createDirectory(
            at: root.appendingPathComponent("META-INF"),
            withIntermediateDirectories: true
        )
        try fileManager.createDirectory(
            at: oebps, withIntermediateDirectories: true
        )

        try """
        <?xml version="1.0" encoding="utf-8"?>
        <container version="1.0" \
        xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
          <rootfiles>
            <rootfile full-path="content/book.opf" \
        media-type="application/oebps-package+xml"/>
          </rootfiles>
        </container>
        """.write(
            to: root.appendingPathComponent("META-INF/container.xml"),
            atomically: true, encoding: .utf8
        )

        for index in 1...2 {
            try chapterXHTML(
                title: "Old Part \(index)", body: "Vintage prose."
            ).write(
                to: oebps.appendingPathComponent("old\(index).xhtml"),
                atomically: true, encoding: .utf8
            )
        }
        let pngBase64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ"
            + "AAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
        try Data(base64Encoded: pngBase64)!.write(
            to: oebps.appendingPathComponent("art.png")
        )

        try """
        <?xml version="1.0" encoding="utf-8"?>
        <package xmlns="http://www.idpf.org/2007/opf" version="2.0" \
        unique-identifier="uid">
          <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
            <dc:title>Vintage Volume</dc:title>
            <dc:creator>Old Hand</dc:creator>
            <meta name="cover" content="art"/>
          </metadata>
          <manifest>
            <item id="ncx" href="toc.ncx" \
        media-type="application/x-dtbncx+xml"/>
            <item id="art" href="art.png" media-type="image/png"/>
            <item id="c1" href="old1.xhtml" \
        media-type="application/xhtml+xml"/>
            <item id="c2" href="old2.xhtml" \
        media-type="application/xhtml+xml"/>
          </manifest>
          <spine toc="ncx">
            <itemref idref="c1"/>
            <itemref idref="c2"/>
          </spine>
        </package>
        """.write(
            to: oebps.appendingPathComponent("book.opf"),
            atomically: true, encoding: .utf8
        )

        try """
        <?xml version="1.0" encoding="utf-8"?>
        <ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
          <head><meta name="dtb:uid" content="urn:uuid:v"/></head>
          <docTitle><text>Vintage Volume</text></docTitle>
          <navMap>
            <navPoint id="a" playOrder="1">
              <navLabel><text>Old Part 1</text></navLabel>
              <content src="old1.xhtml"/>
            </navPoint>
            <navPoint id="b" playOrder="2">
              <navLabel><text>Old Part 2</text></navLabel>
              <content src="old2.xhtml#frag"/>
            </navPoint>
          </navMap>
        </ncx>
        """.write(
            to: oebps.appendingPathComponent("toc.ncx"),
            atomically: true, encoding: .utf8
        )

        return root
    }

    /// Zips an unpacked EPUB tree into an .epub file.
    static func zipEPUB(directory: URL, to destination: URL) throws {
        let archive = try Archive(url: destination, accessMode: .create)
        try archive.addEntry(
            with: "mimetype",
            type: .file,
            uncompressedSize: Int64("application/epub+zip".utf8.count),
            compressionMethod: .none
        ) { position, size in
            let data = Data("application/epub+zip".utf8)
            return data.subdata(
                in: Int(position)..<Int(position) + size
            )
        }
        let fileManager = FileManager.default
        let enumerator = fileManager.enumerator(
            at: directory, includingPropertiesForKeys: [.isDirectoryKey]
        )!
        for case let url as URL in enumerator {
            let isDirectory = (try? url.resourceValues(
                forKeys: [.isDirectoryKey]
            ).isDirectory) ?? false
            guard !isDirectory else { continue }
            let relative = url.path.replacingOccurrences(
                of: directory.path + "/", with: ""
            )
            try archive.addEntry(
                with: relative, fileURL: url
            )
        }
    }
}
