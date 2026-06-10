import Foundation
import ZIPFoundation

// MARK: - Result Types

struct EPUBMetadata {
    var title: String
    var author: String
    var coverData: Data?
    var chapterPaths: [URL]      // absolute paths inside extraction dir
    var chapterTitles: [String]
    var extractionDir: URL
}

// MARK: - EPUBParser

final class EPUBParser: @unchecked Sendable {

    enum ParseError: LocalizedError {
        case notAnEPUB
        case missingContainer
        case missingOPF
        case missingSpine

        var errorDescription: String? {
            switch self {
            case .notAnEPUB:        return "File is not a valid EPUB."
            case .missingContainer: return "META-INF/container.xml not found."
            case .missingOPF:       return "OPF package file not found."
            case .missingSpine:     return "EPUB spine is empty."
            }
        }
    }

    private let fileManager = FileManager.default

    // Extract and parse an EPUB into `destinationDir`
    func parse(epubURL: URL, into destinationDir: URL) throws -> EPUBMetadata {
        try extractEPUB(from: epubURL, to: destinationDir)
        return try parseMetadata(in: destinationDir)
    }

    // Read metadata from an already-extracted directory (no re-unzipping)
    func parseAlreadyExtracted(in dir: URL) throws -> EPUBMetadata {
        try parseMetadata(in: dir)
    }

    // MARK: - Extraction

    private func extractEPUB(from source: URL, to destination: URL) throws {
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        try fileManager.unzipItem(at: source, to: destination)
    }

    // MARK: - Metadata parsing

    private func parseMetadata(in dir: URL) throws -> EPUBMetadata {
        let opfURL = try findOPF(in: dir)
        let opfDir = opfURL.deletingLastPathComponent()
        let opfData = try Data(contentsOf: opfURL)

        let opfParser = OPFParser(data: opfData, baseDir: opfDir)
        try opfParser.parse()

        let chapterURLs = opfParser.spineItemPaths
        guard !chapterURLs.isEmpty else { throw ParseError.missingSpine }

        // Resolve cover image
        var coverData: Data?
        if let coverPath = opfParser.coverImagePath {
            coverData = try? Data(contentsOf: coverPath)
        }

        return EPUBMetadata(
            title: opfParser.title,
            author: opfParser.author,
            coverData: coverData,
            chapterPaths: chapterURLs,
            chapterTitles: opfParser.chapterTitles,
            extractionDir: dir
        )
    }

    // Reads META-INF/container.xml to find OPF path
    private func findOPF(in dir: URL) throws -> URL {
        let containerURL = dir
            .appendingPathComponent("META-INF")
            .appendingPathComponent("container.xml")

        guard fileManager.fileExists(atPath: containerURL.path) else {
            throw ParseError.missingContainer
        }

        let data = try Data(contentsOf: containerURL)
        let containerParser = ContainerXMLParser(data: data)
        try containerParser.parse()

        guard let opfPath = containerParser.rootfilePath else {
            throw ParseError.missingOPF
        }

        let opfURL = dir.appendingPathComponent(opfPath)
        guard fileManager.fileExists(atPath: opfURL.path) else {
            throw ParseError.missingOPF
        }
        return opfURL
    }
}

// MARK: - ContainerXMLParser

private final class ContainerXMLParser: NSObject, XMLParserDelegate {
    private let data: Data
    var rootfilePath: String?
    private var error: Error?

    init(data: Data) { self.data = data }

    func parse() throws {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        if let error { throw error }
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName: String?,
                attributes attributeDict: [String: String]) {
        if elementName == "rootfile", rootfilePath == nil {
            rootfilePath = attributeDict["full-path"]
        }
    }
}

// MARK: - OPFParser

private final class OPFParser: NSObject, XMLParserDelegate {
    private let data: Data
    private let baseDir: URL

    var title  = "Unknown Title"
    var author = "Unknown Author"
    var coverImagePath: URL?
    var spineItemPaths: [URL] = []
    var chapterTitles: [String] = []

    private var manifest: [String: URL] = [:]    // id → absolute URL
    private var spineIDs: [String] = []
    private var ncxID: String?
    private var navDocID: String?              // EPUB 3 nav document
    private var coverMetaID: String?
    private var inMetadata = false
    private var currentElement = ""
    private var currentText = ""

    init(data: Data, baseDir: URL) {
        self.data = data
        self.baseDir = baseDir
    }

    func parse() throws {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        buildSpine()
        loadNCXTitles()
    }

    // MARK: XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement name: String,
                namespaceURI: String?, qualifiedName: String?,
                attributes attrs: [String: String]) {
        currentElement = name
        currentText = ""

        switch name {
        case "metadata", "opf:metadata":
            inMetadata = true
        case "item":
            if let id = attrs["id"], let href = attrs["href"] {
                let url = baseDir.appendingPathComponent(href.removingPercentEncoding ?? href)
                manifest[id] = url
                if attrs["media-type"] == "application/x-dtbncx+xml" { ncxID = id }
                if let props = attrs["properties"] {
                    if props.contains("cover-image") { coverMetaID = id }
                    if props.contains("nav") { navDocID = id }   // EPUB 3
                }
            }
        case "itemref":
            if let idref = attrs["idref"], attrs["linear"] != "no" {
                spineIDs.append(idref)
            }
        case "meta":
            if attrs["name"] == "cover" { coverMetaID = attrs["content"] }
        default: break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, didEndElement name: String,
                namespaceURI: String?, qualifiedName: String?) {
        switch name {
        case "metadata", "opf:metadata": inMetadata = false
        case "dc:title", "title":
            if inMetadata && currentText.trimmingCharacters(in: .whitespacesAndNewlines) != "" {
                title = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        case "dc:creator", "creator":
            if inMetadata && currentText.trimmingCharacters(in: .whitespacesAndNewlines) != "" {
                author = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        default: break
        }
        currentElement = ""
    }

    // MARK: - Post-parse

    private func buildSpine() {
        spineItemPaths = spineIDs.compactMap { manifest[$0] }

        if let cid = coverMetaID, let url = manifest[cid] {
            let ext = url.pathExtension.lowercased()
            if ["jpg","jpeg","png","gif","webp","svg"].contains(ext) {
                coverImagePath = url
            }
        }

        // Fallback: look for cover image file
        if coverImagePath == nil {
            coverImagePath = manifest.values.first {
                let ext = $0.pathExtension.lowercased()
                let name = $0.lastPathComponent.lowercased()
                return ["jpg","jpeg","png"].contains(ext) && name.contains("cover")
            }
        }
    }

    private func loadNCXTitles() {
        // Prefer EPUB 3 nav document over EPUB 2 NCX
        if let navID = navDocID,
           let navURL = manifest[navID],
           let navData = try? Data(contentsOf: navURL) {
            let nav = NavDocumentParser(data: navData)
            nav.parse()
            if !nav.titles.isEmpty {
                chapterTitles = nav.titles
                return
            }
        }
        // Fall back to NCX
        guard let ncxID, let ncxURL = manifest[ncxID],
              let ncxData = try? Data(contentsOf: ncxURL) else {
            chapterTitles = spineItemPaths.enumerated().map { "Chapter \($0.offset + 1)" }
            return
        }
        let ncx = NCXParser(data: ncxData)
        ncx.parse()
        chapterTitles = ncx.titles.isEmpty
            ? spineItemPaths.enumerated().map { "Chapter \($0.offset + 1)" }
            : ncx.titles
    }
}

// MARK: - NCXParser (chapter titles from .ncx / nav)

private final class NCXParser: NSObject, XMLParserDelegate {
    private let data: Data
    var titles: [String] = []
    private var inNavLabel = false
    private var currentText = ""

    init(data: Data) { self.data = data }

    func parse() {
        let p = XMLParser(data: data)
        p.delegate = self
        p.parse()
    }

    func parser(_ p: XMLParser, didStartElement name: String,
                namespaceURI: String?, qualifiedName: String?,
                attributes: [String: String]) {
        if name == "navLabel" || name == "text" && inNavLabel { inNavLabel = true }
        if name == "text" && inNavLabel { currentText = "" }
    }

    func parser(_ p: XMLParser, foundCharacters s: String) {
        if inNavLabel { currentText += s }
    }

    func parser(_ p: XMLParser, didEndElement name: String,
                namespaceURI: String?, qualifiedName: String?) {
        if name == "text" && inNavLabel {
            let t = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { titles.append(t) }
            currentText = ""
        }
        if name == "navLabel" { inNavLabel = false }
    }
}

// MARK: - NavDocumentParser (EPUB 3 nav.xhtml — <nav epub:type="toc">)

private final class NavDocumentParser: NSObject, XMLParserDelegate {
    private let data: Data
    var titles: [String] = []
    private var inTocNav = false
    private var inAnchor = false
    private var currentText = ""
    private var depth = 0     // nesting depth inside toc nav

    init(data: Data) { self.data = data }

    func parse() {
        let p = XMLParser(data: data)
        p.shouldProcessNamespaces = true
        p.delegate = self
        p.parse()
    }

    func parser(_ p: XMLParser, didStartElement name: String,
                namespaceURI: String?, qualifiedName: String?,
                attributes attrs: [String: String]) {
        let local = name.components(separatedBy: ":").last ?? name
        if local == "nav" {
            let epubType = attrs["epub:type"] ?? attrs["type"] ?? ""
            if epubType.contains("toc") { inTocNav = true; depth = 0 }
        }
        if inTocNav {
            if local == "ol" || local == "ul" { depth += 1 }
            if local == "a" { inAnchor = true; currentText = "" }
        }
    }

    func parser(_ p: XMLParser, foundCharacters s: String) {
        if inAnchor { currentText += s }
    }

    func parser(_ p: XMLParser, didEndElement name: String,
                namespaceURI: String?, qualifiedName: String?) {
        let local = name.components(separatedBy: ":").last ?? name
        if inTocNav {
            if local == "a" && inAnchor {
                let t = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !t.isEmpty { titles.append(t) }
                inAnchor = false
            }
            if local == "ol" || local == "ul" {
                depth -= 1
                if depth < 0 { inTocNav = false }
            }
        }
        if local == "nav" { inTocNav = false }
    }
}
