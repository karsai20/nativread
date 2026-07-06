import Foundation
import ZIPFoundation

/// Writes a reassembled `KF8Converter.Book` out as a valid EPUB zip:
/// mimetype (stored first), container.xml, an OPF package document, and the
/// XHTML/CSS/image resources — all flat under OEBPS/.
enum KF8EPUBWriter {
    static func write(_ book: KF8Converter.Book, to destination: URL) throws {
        try? FileManager.default.removeItem(at: destination)
        let archive = try Archive(url: destination, accessMode: .create)

        // mimetype must be the first entry and stored uncompressed.
        let mimetype = Data("application/epub+zip".utf8)
        try archive.addEntry(
            with: "mimetype", type: .file,
            uncompressedSize: Int64(mimetype.count), compressionMethod: .none
        ) { position, size in
            mimetype.subdata(in: Int(position) ..< Int(position) + size)
        }

        try add(archive, "META-INF/container.xml", Data(containerXML.utf8))
        try add(archive, "OEBPS/content.opf", Data(makeOPF(book).utf8))
        for part in book.parts {
            try add(archive, "OEBPS/\(part.name)", Data(part.xhtml.utf8))
        }
        for style in book.styles {
            try add(archive, "OEBPS/\(style.name)", style.data)
        }
        for image in book.images {
            try add(archive, "OEBPS/\(image.name)", image.data)
        }
    }

    private static func add(_ archive: Archive, _ path: String, _ data: Data) throws {
        try archive.addEntry(
            with: path, type: .file,
            uncompressedSize: Int64(data.count), compressionMethod: .deflate
        ) { position, size in
            data.subdata(in: Int(position) ..< Int(position) + size)
        }
    }

    private static let containerXML = """
    <?xml version="1.0" encoding="UTF-8"?>
    <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
      <rootfiles>
        <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
      </rootfiles>
    </container>
    """

    private static func makeOPF(_ book: KF8Converter.Book) -> String {
        var manifest = ""
        var spine = ""
        for (index, part) in book.parts.enumerated() {
            manifest += "\n    <item id=\"p\(index)\" href=\"\(part.name)\" "
                + "media-type=\"application/xhtml+xml\"/>"
            spine += "\n    <itemref idref=\"p\(index)\"/>"
        }
        for (index, style) in book.styles.enumerated() {
            manifest += "\n    <item id=\"s\(index)\" href=\"\(style.name)\" "
                + "media-type=\"text/css\"/>"
        }
        for (index, image) in book.images.enumerated() {
            let isCover = image.name == book.coverImageName
            let properties = isCover ? " properties=\"cover-image\"" : ""
            manifest += "\n    <item id=\"img\(index)\" href=\"\(image.name)\" "
                + "media-type=\"\(image.mediaType)\"\(properties)/>"
        }

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="uid">
          <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
            <dc:identifier id="uid">urn:uuid:\(UUID().uuidString)</dc:identifier>
            <dc:title>\(escape(book.title))</dc:title>
            <dc:creator>\(escape(book.author))</dc:creator>
            <dc:language>en</dc:language>
          </metadata>
          <manifest>\(manifest)
          </manifest>
          <spine>\(spine)
          </spine>
        </package>
        """
    }

    private static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
