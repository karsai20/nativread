import Foundation

/// Parses an already-unpacked EPUB directory: container.xml → OPF →
/// metadata, manifest, spine, cover, then the table of contents.
enum EPUBParser {

    static func parse(extractedRoot: URL) throws -> ParsedEPUB {
        let containerURL = extractedRoot
            .appendingPathComponent("META-INF/container.xml")
        guard let containerData = try? Data(contentsOf: containerURL) else {
            throw EPUBError.missingContainer
        }

        let containerParser = ContainerXMLDelegate()
        containerParser.run(on: containerData)
        guard let opfPath = containerParser.opfPath else {
            throw EPUBError.missingContainer
        }

        let opfURL = extractedRoot.appendingPathComponent(opfPath)
        guard let opfData = try? Data(contentsOf: opfURL) else {
            throw EPUBError.missingOPF(opfPath)
        }
        let opfDirectory = opfURL.deletingLastPathComponent()

        let opf = OPFDelegate()
        opf.run(on: opfData)

        let manifestByID = Dictionary(
            uniqueKeysWithValues: opf.manifest.map { ($0.id, $0) }
        )

        var spineURLs: [URL] = []
        var spineHrefs: [String] = []
        for idref in opf.spineIDRefs {
            guard let item = manifestByID[idref] else { continue }
            let url = resolve(href: item.href, against: opfDirectory)
            if FileManager.default.fileExists(atPath: url.path) {
                spineURLs.append(url)
                spineHrefs.append(normalize(href: item.href))
            }
        }
        guard !spineURLs.isEmpty else { throw EPUBError.emptySpine }

        let coverImageURL = findCover(
            opf: opf, manifestByID: manifestByID, opfDirectory: opfDirectory
        )

        let toc = parseTOC(
            opf: opf, manifestByID: manifestByID,
            opfDirectory: opfDirectory, spineHrefs: spineHrefs
        )

        let weights = spineURLs.map { url -> Double in
            let size = (try? FileManager.default
                .attributesOfItem(atPath: url.path)[.size] as? Int) ?? nil
            return Double(max(size ?? 1, 1))
        }

        return ParsedEPUB(
            title: opf.title ?? "Untitled",
            author: opf.author ?? "Unknown author",
            spineURLs: spineURLs,
            spineHrefs: spineHrefs,
            coverImageURL: coverImageURL,
            toc: toc,
            spineWeights: weights
        )
    }

    // MARK: - Cover

    private static func findCover(
        opf: OPFDelegate,
        manifestByID: [String: EPUBManifestItem],
        opfDirectory: URL
    ) -> URL? {
        // EPUB 3: manifest item flagged properties="cover-image".
        if let item = opf.manifest.first(where: {
            $0.properties.contains("cover-image")
        }) {
            return existingURL(href: item.href, against: opfDirectory)
        }
        // EPUB 2: <meta name="cover" content="item-id"/>.
        if let coverID = opf.coverMetaItemID, let item = manifestByID[coverID] {
            return existingURL(href: item.href, against: opfDirectory)
        }
        // Last resort: a manifest image whose id or href mentions "cover".
        if let item = opf.manifest.first(where: {
            $0.mediaType.hasPrefix("image/")
                && ($0.id.lowercased().contains("cover")
                    || $0.href.lowercased().contains("cover"))
        }) {
            return existingURL(href: item.href, against: opfDirectory)
        }
        return nil
    }

    // MARK: - TOC

    private static func parseTOC(
        opf: OPFDelegate,
        manifestByID: [String: EPUBManifestItem],
        opfDirectory: URL,
        spineHrefs: [String]
    ) -> [TOCEntry] {
        var raw: [(title: String, href: String, depth: Int)] = []

        // EPUB 3 navigation document.
        if let navItem = opf.manifest.first(where: {
            $0.properties.contains("nav")
        }), let data = try? Data(
            contentsOf: resolve(href: navItem.href, against: opfDirectory)
        ) {
            let nav = NavDelegate()
            nav.run(on: data)
            raw = nav.entries.map {
                (
                    $0.title,
                    join(base: navItem.href, relative: $0.href),
                    $0.depth
                )
            }
        }

        // EPUB 2 NCX fallback.
        if raw.isEmpty,
           let ncxItem = opf.manifest.first(where: {
               $0.mediaType == "application/x-dtbncx+xml"
           }) ?? manifestByID[opf.spineTOCID ?? ""],
           let data = try? Data(
               contentsOf: resolve(href: ncxItem.href, against: opfDirectory)
           ) {
            let ncx = NCXDelegate()
            ncx.run(on: data)
            raw = ncx.entries.map {
                (
                    $0.title,
                    join(base: ncxItem.href, relative: $0.href),
                    $0.depth
                )
            }
        }

        // Synthesised TOC when the book ships none.
        if raw.isEmpty {
            return spineHrefs.enumerated().map { index, href in
                TOCEntry(
                    title: "Chapter \(index + 1)", href: href,
                    spineIndex: index, depth: 0
                )
            }
        }

        return raw.map { entry in
            let withoutFragment = String(
                entry.href.split(separator: "#", maxSplits: 1)[0]
            )
            let spineIndex = spineHrefs.firstIndex(
                of: normalize(href: withoutFragment)
            )
            return TOCEntry(
                title: entry.title, href: entry.href,
                spineIndex: spineIndex, depth: entry.depth
            )
        }
    }

    // MARK: - Path helpers

    /// Resolves a (possibly percent-encoded) href against a directory.
    static func resolve(href: String, against directory: URL) -> URL {
        let decoded = href.removingPercentEncoding ?? href
        return URL(fileURLWithPath: decoded, relativeTo: directory)
            .standardizedFileURL
    }

    private static func existingURL(href: String, against dir: URL) -> URL? {
        let url = resolve(href: href, against: dir)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// Normalises hrefs for spine matching: decode, drop "./".
    static func normalize(href: String) -> String {
        var value = href.removingPercentEncoding ?? href
        while value.hasPrefix("./") { value.removeFirst(2) }
        return value
    }

    /// Joins "nav/toc.xhtml" + "ch1.xhtml" → "nav/ch1.xhtml",
    /// resolving any "../" segments.
    static func join(base: String, relative: String) -> String {
        if relative.hasPrefix("/") { return String(relative.dropFirst()) }
        var parts = base.split(separator: "/").dropLast().map(String.init)
        for segment in relative.split(separator: "/") {
            switch segment {
            case "..": if !parts.isEmpty { parts.removeLast() }
            case ".": continue
            default: parts.append(String(segment))
            }
        }
        return parts.joined(separator: "/")
    }

    // MARK: - Content sanitizing

    /// Strips embedded `<script>` from each spine document in place.
    ///
    /// EPUB reflowable content never needs its own scripts — the reading
    /// engine supplies all interactivity — so any author-supplied script is
    /// removed before the chapter is rendered in the WebView. The WebView
    /// keeps JavaScript enabled for the app-injected engine; engine scripts
    /// and `evaluateJavaScript` calls are not affected by this pass.
    ///
    /// Best-effort: unreadable, non-UTF-8, or unwritable files are skipped
    /// and never raise — sanitizing must not block opening a book.
    static func sanitizeScripts(in spineURLs: [URL]) {
        for url in spineURLs {
            guard let original = try? String(contentsOf: url, encoding: .utf8)
            else { continue }
            let cleaned = stripScripts(from: original)
            guard cleaned != original else { continue }
            try? cleaned.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    /// Removes script elements, inline event-handler attributes, and
    /// `javascript:` / `data:text/html` URIs, case-insensitively. EPUB content
    /// is XHTML so these attribute-anchored passes leave prose untouched. This
    /// runs on every imported EPUB, including translated copies fetched from
    /// the network backend, which are otherwise untrusted HTML rendered in the
    /// JS-enabled reader WebView — a `<script>`-only strip would let inline
    /// `on*=` handlers and `javascript:` links execute.
    static func stripScripts(from html: String) -> String {
        let patterns = [
            // Paired and self-closing <script> elements.
            "(?is)<script\\b[^>]*>.*?</script\\s*>",
            "(?is)<script\\b[^>]*/>",
            // Inline event handlers: on…="…" / on…='…' / on…=bareword,
            // anchored to attribute position (preceding whitespace) so prose
            // words like "online" are never matched.
            "(?i)\\son[a-z]+\\s*=\\s*\"[^\"]*\"",
            "(?i)\\son[a-z]+\\s*=\\s*'[^']*'",
            "(?i)\\son[a-z]+\\s*=\\s*[^\\s>]+",
            // javascript:/data:text/html in href/src/xlink:href. Tolerates the
            // whitespace/newline/case tricks used to slip past naive filters.
            "(?is)(href|src|xlink:href)\\s*=\\s*\"\\s*j\\s*a\\s*v\\s*a\\s*s\\s*c\\s*r\\s*i\\s*p\\s*t\\s*:[^\"]*\"",
            "(?is)(href|src|xlink:href)\\s*=\\s*'\\s*j\\s*a\\s*v\\s*a\\s*s\\s*c\\s*r\\s*i\\s*p\\s*t\\s*:[^']*'",
            "(?is)(href|src|xlink:href)\\s*=\\s*\"\\s*data\\s*:\\s*text/html[^\"]*\"",
            "(?is)(href|src|xlink:href)\\s*=\\s*'\\s*data\\s*:\\s*text/html[^']*'",
        ]
        return patterns.reduce(html) { partial, pattern in
            partial.replacingOccurrences(
                of: pattern, with: "", options: .regularExpression
            )
        }
    }
}
