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

        guard let opfURL = containedURL(
            href: opfPath, against: extractedRoot, root: extractedRoot
        ), let opfData = try? Data(contentsOf: opfURL) else {
            throw EPUBError.missingOPF(opfPath)
        }
        let opfDirectory = opfURL.deletingLastPathComponent()

        let opf = OPFDelegate()
        opf.run(on: opfData)

        // Malicious duplicate ids must not trigger Dictionary's
        // `uniqueKeysWithValues` precondition trap. Keep the first binding.
        var manifestByID: [String: EPUBManifestItem] = [:]
        for item in opf.manifest where manifestByID[item.id] == nil {
            manifestByID[item.id] = item
        }

        var spineURLs: [URL] = []
        var spineHrefs: [String] = []
        for idref in opf.spineIDRefs {
            guard let item = manifestByID[idref] else { continue }
            if let url = containedURL(
                href: item.href, against: opfDirectory, root: extractedRoot
            ), FileManager.default.fileExists(atPath: url.path) {
                spineURLs.append(url)
                spineHrefs.append(normalize(href: item.href))
            }
        }
        guard !spineURLs.isEmpty else { throw EPUBError.emptySpine }

        let coverImageURL = findCover(
            opf: opf, manifestByID: manifestByID,
            opfDirectory: opfDirectory, extractedRoot: extractedRoot
        )

        let toc = parseTOC(
            opf: opf, manifestByID: manifestByID,
            opfDirectory: opfDirectory, extractedRoot: extractedRoot,
            spineHrefs: spineHrefs
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
        opfDirectory: URL,
        extractedRoot: URL
    ) -> URL? {
        // EPUB 3: manifest item flagged properties="cover-image".
        if let item = opf.manifest.first(where: {
            $0.properties.contains("cover-image")
        }) {
            return existingURL(
                href: item.href, against: opfDirectory, root: extractedRoot
            )
        }
        // EPUB 2: <meta name="cover" content="item-id"/>.
        if let coverID = opf.coverMetaItemID, let item = manifestByID[coverID] {
            return existingURL(
                href: item.href, against: opfDirectory, root: extractedRoot
            )
        }
        // Last resort: a manifest image whose id or href mentions "cover".
        if let item = opf.manifest.first(where: {
            $0.mediaType.hasPrefix("image/")
                && ($0.id.lowercased().contains("cover")
                    || $0.href.lowercased().contains("cover"))
        }) {
            return existingURL(
                href: item.href, against: opfDirectory, root: extractedRoot
            )
        }
        return nil
    }

    // MARK: - TOC

    private static func parseTOC(
        opf: OPFDelegate,
        manifestByID: [String: EPUBManifestItem],
        opfDirectory: URL,
        extractedRoot: URL,
        spineHrefs: [String]
    ) -> [TOCEntry] {
        var raw: [(title: String, href: String, depth: Int)] = []

        // EPUB 3 navigation document.
        if let navItem = opf.manifest.first(where: {
            $0.properties.contains("nav")
        }), let navURL = containedURL(
            href: navItem.href, against: opfDirectory, root: extractedRoot
        ), let data = try? Data(contentsOf: navURL) {
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
           let ncxURL = containedURL(
               href: ncxItem.href, against: opfDirectory, root: extractedRoot
           ), let data = try? Data(contentsOf: ncxURL) {
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
        if decoded.hasPrefix("/") {
            return URL(fileURLWithPath: decoded).standardizedFileURL
        }
        return directory.appendingPathComponent(decoded).standardizedFileURL
    }

    private static func existingURL(
        href: String, against dir: URL, root: URL
    ) -> URL? {
        guard let url = containedURL(href: href, against: dir, root: root)
        else { return nil }
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// Resolves an author-controlled path only when it remains inside the
    /// current extracted book. This prevents container.xml / OPF `../`
    /// references from reading another book or an app-private file.
    static func containedURL(
        href: String, against directory: URL, root: URL
    ) -> URL? {
        let candidate = resolve(href: href, against: directory)
        let normalizedRoot = root.standardizedFileURL
        let rootPrefix = normalizedRoot.path.hasSuffix("/")
            ? normalizedRoot.path
            : normalizedRoot.path + "/"
        let candidatePath = candidate.standardizedFileURL.path
        guard candidatePath == normalizedRoot.path
                || candidatePath.hasPrefix(rootPrefix)
        else { return nil }
        return candidate
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
    /// Best-effort: unreadable or unwritable files are skipped and never
    /// raise — sanitizing must not block opening a book. Encoding is
    /// detected (BOM'd UTF-16 XHTML is valid EPUB content and WKWebView
    /// renders it, so skipping non-UTF-8 files would skip sanitizing them)
    /// and the cleaned file is written back in the same encoding.
    static func sanitizeScripts(in spineURLs: [URL]) {
        for url in spineURLs {
            try? sanitizeForReading(url)
        }
    }

    /// Strict import path: unreadable or unwritable content fails closed
    /// instead of letting an unsanitized chapter reach the JS-enabled reader.
    static func sanitizeForReading(in spineURLs: [URL]) throws {
        for url in spineURLs { try sanitizeForReading(url) }
    }

    private static func sanitizeForReading(_ url: URL) throws {
        var encoding = String.Encoding.utf8
        let original = try String(contentsOf: url, usedEncoding: &encoding)
        let hardened = injectContentSecurityPolicy(
            into: stripScripts(from: original)
        )
        guard hardened != original else { return }
        try hardened.write(to: url, atomically: true, encoding: encoding)
    }

    /// Stops remote images/fonts/CSS, frames, forms, plugins and author
    /// scripts. WKUserScript-based reader controls continue to run, while an
    /// EPUB cannot make a hidden network request that reveals reading data.
    static func injectContentSecurityPolicy(into html: String) -> String {
        if html.contains("data-nativread-policy=\"offline\"") { return html }
        let policy = "default-src 'none'; img-src file: data:; "
            + "style-src file: 'unsafe-inline'; font-src file: data:; "
            + "media-src file: data:; script-src 'none'; connect-src 'none'; "
            + "frame-src 'none'; child-src 'none'; object-src 'none'; "
            + "form-action 'none'; base-uri 'none'"
        let meta = "<meta data-nativread-policy=\"offline\" "
            + "http-equiv=\"Content-Security-Policy\" content=\"\(policy)\" />"
        if let head = html.range(
            of: "(?i)<head\\b[^>]*>", options: .regularExpression
        ) {
            var output = html
            output.insert(contentsOf: meta, at: head.upperBound)
            return output
        }
        if let document = html.range(
            of: "(?i)<html\\b[^>]*>", options: .regularExpression
        ) {
            var output = html
            output.insert(contentsOf: "<head>\(meta)</head>", at: document.upperBound)
            return output
        }
        return "<head>\(meta)</head>" + html
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
            // srcdoc smuggles entity-encoded markup that the iframe decodes
            // and renders; reflowable EPUB never needs it, strip it whole.
            "(?is)\\ssrcdoc\\s*=\\s*\"[^\"]*\"",
            "(?is)\\ssrcdoc\\s*=\\s*'[^']*'",
            "(?is)\\ssrcdoc\\s*=\\s*[^\\s>]+",
        ]
        let literalStripped = patterns.reduce(html) { partial, pattern in
            partial.replacingOccurrences(
                of: pattern, with: "", options: .regularExpression
            )
        }
        return neutralizeEncodedSchemeLinks(in: literalStripped)
    }

    /// Removes `href`/`src`/`xlink:href` attributes whose value resolves to a
    /// dangerous scheme only AFTER HTML character references are decoded — e.g.
    /// `href="java&#x73;cript:steal()"`. WKWebView decodes entities before it
    /// acts on a link, so the literal-`javascript:` passes above miss these.
    /// ponytail: covers numeric (dec/hex) refs and the `:`/whitespace named
    /// entities used in scheme-obfuscation; exotic named refs beyond those fall
    /// through, but the browser only executes `javascript:`/`data:text/html`.
    static func neutralizeEncodedSchemeLinks(in html: String) -> String {
        // Unquoted values and form-submission attributes are checked too:
        // WKWebView honors href=javascript:… without quotes and executes
        // formaction/action targets on submit exactly like href on click.
        let attr = "(?is)\\s(href|src|xlink:href|formaction|action|poster)"
            + "\\s*=\\s*(\"[^\"]*\"|'[^']*'|[^\\s>\"']+)"
        guard let regex = try? NSRegularExpression(pattern: attr) else { return html }
        let ns = html as NSString
        var result = html
        // Rebuild from the end so earlier match ranges stay valid.
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: ns.length))
        for match in matches.reversed() {
            let rawValue = ns.substring(with: match.range(at: 2))
            let isQuoted = rawValue.hasPrefix("\"") || rawValue.hasPrefix("'")
            let quotedValue = isQuoted ? String(rawValue.dropFirst().dropLast()) : rawValue
            let decoded = decodeCharacterReferences(quotedValue)
                .unicodeScalars.filter { !$0.properties.isWhitespace && $0.value > 0x20 }
                .map(Character.init)
            let normalized = String(decoded).lowercased()
            if normalized.hasPrefix("javascript:") || normalized.hasPrefix("data:text/html") {
                result = (result as NSString).replacingCharacters(in: match.range, with: "")
            }
        }
        return result
    }

    /// Decodes decimal (`&#106;`), hex (`&#x6a;`), and the handful of named
    /// character references (`&colon;`, `&Tab;`, `&NewLine;`, `&sol;`) that are
    /// used to smuggle scheme separators past a literal filter.
    private static func decodeCharacterReferences(_ text: String) -> String {
        var out = text
        let named = ["&colon;": ":", "&Tab;": "\t", "&NewLine;": "\n", "&sol;": "/"]
        for (entity, replacement) in named {
            out = out.replacingOccurrences(of: entity, with: replacement, options: .caseInsensitive)
        }
        guard let regex = try? NSRegularExpression(pattern: "&#(x?)([0-9a-fA-F]+);") else { return out }
        let ns = out as NSString
        var decoded = out
        for match in regex.matches(in: out, range: NSRange(location: 0, length: ns.length)).reversed() {
            let isHex = ns.substring(with: match.range(at: 1)).lowercased() == "x"
            let digits = ns.substring(with: match.range(at: 2))
            guard let code = UInt32(digits, radix: isHex ? 16 : 10),
                  let scalar = Unicode.Scalar(code) else { continue }
            decoded = (decoded as NSString).replacingCharacters(in: match.range, with: String(scalar))
        }
        return decoded
    }
}
