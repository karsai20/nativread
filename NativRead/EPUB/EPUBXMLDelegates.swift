import Foundation

/// Small base class so each delegate can simply `run(on:)` a document.
class XMLDelegateBase: NSObject, XMLParserDelegate {
    func run(on data: Data) {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.shouldProcessNamespaces = true
        parser.parse()
    }
}

/// META-INF/container.xml → path of the OPF package document.
final class ContainerXMLDelegate: XMLDelegateBase {
    private(set) var opfPath: String?

    func parser(
        _ parser: XMLParser, didStartElement elementName: String,
        namespaceURI: String?, qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        guard elementName == "rootfile", opfPath == nil else { return }
        if attributeDict["media-type"] == "application/oebps-package+xml"
            || attributeDict["media-type"] == nil {
            opfPath = attributeDict["full-path"]
        }
    }
}

/// The OPF package document: metadata, manifest, spine.
final class OPFDelegate: XMLDelegateBase {
    private(set) var title: String?
    private(set) var author: String?
    private(set) var manifest: [EPUBManifestItem] = []
    private(set) var spineIDRefs: [String] = []
    /// `toc` attribute of <spine> (NCX id, EPUB 2).
    private(set) var spineTOCID: String?
    /// <meta name="cover" content="..."/> (EPUB 2).
    private(set) var coverMetaItemID: String?

    private var currentText = ""
    private var capturingTitle = false
    private var capturingCreator = false

    func parser(
        _ parser: XMLParser, didStartElement elementName: String,
        namespaceURI: String?, qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        switch elementName {
        case "title" where title == nil:
            capturingTitle = true
            currentText = ""
        case "creator" where author == nil:
            capturingCreator = true
            currentText = ""
        case "item":
            guard let id = attributeDict["id"],
                  let href = attributeDict["href"] else { return }
            let properties = Set(
                (attributeDict["properties"] ?? "")
                    .split(separator: " ").map(String.init)
            )
            manifest.append(EPUBManifestItem(
                id: id, href: href,
                mediaType: attributeDict["media-type"] ?? "",
                properties: properties
            ))
        case "spine":
            spineTOCID = attributeDict["toc"]
        case "itemref":
            if attributeDict["linear"]?.lowercased() != "no",
               let idref = attributeDict["idref"] {
                spineIDRefs.append(idref)
            }
        case "meta":
            if attributeDict["name"] == "cover" {
                coverMetaItemID = attributeDict["content"]
            }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if capturingTitle || capturingCreator { currentText += string }
    }

    func parser(
        _ parser: XMLParser, didEndElement elementName: String,
        namespaceURI: String?, qualifiedName qName: String?
    ) {
        let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        if elementName == "title", capturingTitle {
            capturingTitle = false
            if !text.isEmpty { title = text }
        }
        if elementName == "creator", capturingCreator {
            capturingCreator = false
            if !text.isEmpty { author = text }
        }
    }
}

/// EPUB 3 navigation document: the <nav epub:type="toc"> list.
final class NavDelegate: XMLDelegateBase {
    struct Entry { let title: String; let href: String; let depth: Int }
    private(set) var entries: [Entry] = []

    private var insideTOCNav = false
    private var navDepth = 0
    private var listDepth = -1
    private var currentHref: String?
    private var currentText = ""
    private var capturing = false

    func parser(
        _ parser: XMLParser, didStartElement elementName: String,
        namespaceURI: String?, qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        switch elementName {
        case "nav":
            navDepth += 1
            // epub:type may arrive with or without namespace processing.
            let type = attributeDict["epub:type"] ?? attributeDict["type"]
            if type == "toc" || (!insideTOCNav && type == nil && entries.isEmpty) {
                insideTOCNav = true
                listDepth = -1
            }
        case "ol" where insideTOCNav:
            listDepth += 1
        case "a" where insideTOCNav:
            currentHref = attributeDict["href"]
            currentText = ""
            capturing = true
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if capturing { currentText += string }
    }

    func parser(
        _ parser: XMLParser, didEndElement elementName: String,
        namespaceURI: String?, qualifiedName qName: String?
    ) {
        switch elementName {
        case "a" where insideTOCNav && capturing:
            capturing = false
            let title = currentText
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let href = currentHref, !title.isEmpty {
                entries.append(Entry(
                    title: title, href: href, depth: max(listDepth, 0)
                ))
            }
            currentHref = nil
        case "ol" where insideTOCNav:
            listDepth -= 1
        case "nav":
            navDepth -= 1
            if navDepth == 0 { insideTOCNav = false }
        default:
            break
        }
    }
}

/// EPUB 2 NCX document: navMap/navPoint tree.
final class NCXDelegate: XMLDelegateBase {
    struct Entry { let title: String; let href: String; let depth: Int }
    private(set) var entries: [Entry] = []

    private var depth = -1
    private var capturingLabel = false
    private var currentText = ""
    private var pendingTitle: String?

    func parser(
        _ parser: XMLParser, didStartElement elementName: String,
        namespaceURI: String?, qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        switch elementName {
        case "navPoint":
            depth += 1
            pendingTitle = nil
        case "text":
            capturingLabel = true
            currentText = ""
        case "content":
            if depth >= 0, let src = attributeDict["src"],
               let title = pendingTitle, !title.isEmpty {
                entries.append(Entry(title: title, href: src, depth: depth))
                pendingTitle = nil
            }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if capturingLabel { currentText += string }
    }

    func parser(
        _ parser: XMLParser, didEndElement elementName: String,
        namespaceURI: String?, qualifiedName qName: String?
    ) {
        switch elementName {
        case "text":
            capturingLabel = false
            if pendingTitle == nil {
                let text = currentText
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty { pendingTitle = text }
            }
        case "navPoint":
            depth -= 1
        default:
            break
        }
    }
}
