import Foundation
import ZIPFoundation

/// Cuts a book down to what the free chapter needs before it is uploaded:
/// every spine document up to the first real chapter, and none after it.
///
/// Images only the cut chapters show are left out too; everything else (OPF,
/// navigation, styles, fonts, the cover) is copied as is. Both
/// the backend's EPUB reader and `EPUBParser` skip spine items whose file is
/// missing, so the cut book stays a valid book that simply ends after the
/// chapter — and the rest of the text never leaves the device.
///
/// Deterministic on purpose: the backend allows one free chapter per book,
/// keyed by the content hash of what was uploaded, so the same book must
/// always cut to the same bytes.
enum SampleEPUBBuilder {
    /// The backend translates the first prose document of at least 250 words
    /// (`SAMPLE_MIN_CONTENT_WORDS`). Cutting at 300 by this count leaves a
    /// margin, so a chapter this counter puts just above the line is not one
    /// the server's own count puts just below it — and then misses.
    static let minimumChapterWords = 300
    /// A contents page is mostly link text (the server's `NAVIGATION_LINK_RATIO`).
    static let navigationLinkRatio = 0.5
    /// The zip epoch. A fixed date keeps two cuts of one book byte-identical.
    private static let fixedDate = Date(timeIntervalSince1970: 315_532_800)

    static func build(from source: URL, to destination: URL) throws {
        let archive = try Archive(url: source, accessMode: .read)
        let droppable = try droppablePaths(in: archive)

        try? FileManager.default.removeItem(at: destination)
        let output = try Archive(url: destination, accessMode: .create)
        // mimetype first and stored, as the EPUB container requires; the rest
        // in the source's own order, which is stable for a given file.
        let files = archive.filter { $0.type == .file }
        let ordered = files.filter { $0.path == "mimetype" } + files.filter { $0.path != "mimetype" }
        for entry in ordered where !droppable.contains(EPUBParser.normalize(href: entry.path)) {
            let data = try contents(of: entry, in: archive)
            try output.addEntry(
                with: entry.path,
                type: .file,
                uncompressedSize: Int64(data.count),
                modificationDate: fixedDate,
                compressionMethod: entry.path == "mimetype" ? .none : .deflate
            ) { position, size in
                data.subdata(in: Int(position) ..< Int(position) + size)
            }
        }
    }

    /// Zip paths left out of the sample: spine documents after the first real
    /// chapter (never the navigation document), and images only they use.
    private static func droppablePaths(in archive: Archive) throws -> Set<String> {
        guard let container = archive["META-INF/container.xml"] else {
            throw EPUBError.missingContainer
        }
        let containerParser = ContainerXMLDelegate()
        containerParser.run(on: try contents(of: container, in: archive))
        guard let opfPath = containerParser.opfPath, let opfEntry = archive[opfPath] else {
            throw EPUBError.missingContainer
        }
        let opf = OPFDelegate()
        opf.run(on: try contents(of: opfEntry, in: archive))

        var manifestByID: [String: EPUBManifestItem] = [:]
        for item in opf.manifest where manifestByID[item.id] == nil {
            manifestByID[item.id] = item
        }
        let path = { (item: EPUBManifestItem) in
            EPUBParser.normalize(href: EPUBParser.join(base: opfPath, relative: item.href))
        }
        let spine = opf.spineIDRefs.compactMap { manifestByID[$0] }
        let spinePaths = spine.map(path)

        guard let chapter = try spinePaths.firstIndex(where: { try isRealChapter(at: $0, in: archive) }) else {
            // No chapter long enough to stand alone: the server previews the
            // first non-empty page, which may be anywhere, so send it all.
            return []
        }
        let navPaths = Set(opf.manifest.filter { $0.properties.contains("nav") }.map(path))
        let cutChapters = Set(spinePaths.suffix(from: chapter + 1)).subtracting(navPaths)

        var used = Set(opf.manifest.filter {
            $0.properties.contains("cover-image") || $0.id == opf.coverMetaItemID
        }.map(path))
        let keptDocuments = Set(spinePaths.prefix(chapter + 1)).union(navPaths)
        let styleSheets = opf.manifest.filter { $0.mediaType == "text/css" }.map(path)
        for document in keptDocuments.union(styleSheets) {
            used.formUnion(try references(in: document, of: archive))
        }
        let unusedImages = opf.manifest
            .filter { $0.mediaType.hasPrefix("image/") }
            .map(path)
            .filter { !used.contains($0) }
        return cutChapters.union(unusedImages)
    }

    /// Paths a document or stylesheet points at (`src`, `href`, `xlink:href`,
    /// CSS `url(...)`), resolved against its own location.
    private static func references(in path: String, of archive: Archive) throws -> Set<String> {
        guard let entry = archive[path] else { return [] }
        let data = try contents(of: entry, in: archive)
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .utf16),
              let regex = try? NSRegularExpression(
                  pattern: #"(?i)(?:\b(?:xlink:)?(?:src|href)\s*=\s*["']([^"'#]+)|url\(\s*["']?([^"')#]+))"#
              )
        else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return Set(regex.matches(in: text, range: range).compactMap { match in
            let group = match.range(at: 1).location != NSNotFound ? 1 : 2
            return Range(match.range(at: group), in: text).map {
                EPUBParser.normalize(href: EPUBParser.join(base: path, relative: String(text[$0])))
            }
        })
    }

    private static func isRealChapter(at path: String, in archive: Archive) throws -> Bool {
        guard let entry = archive[path] else { return false }
        let data = try contents(of: entry, in: archive)
        guard let xhtml = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .utf16) else {
            return false
        }
        let words = wordCount(SearchService.plainText(fromXHTML: xhtml))
        guard words >= minimumChapterWords else { return false }
        let linkedWords = linkTexts(in: xhtml).reduce(0) { $0 + wordCount($1) }
        return Double(linkedWords) / Double(words) < navigationLinkRatio
    }

    private static func linkTexts(in xhtml: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: "(?is)<a\\b[^>]*>(.*?)</a>") else { return [] }
        let range = NSRange(xhtml.startIndex..., in: xhtml)
        return regex.matches(in: xhtml, range: range).compactMap { match in
            Range(match.range(at: 1), in: xhtml).map { SearchService.plainText(fromXHTML: String(xhtml[$0])) }
        }
    }

    private static func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: \.isWhitespace).count
    }

    private static func contents(of entry: Entry, in archive: Archive) throws -> Data {
        var data = Data()
        _ = try archive.extract(entry) { data.append($0) }
        return data
    }
}
