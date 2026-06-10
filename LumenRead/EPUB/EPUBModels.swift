import Foundation

struct EPUBManifestItem: Equatable {
    let id: String
    let href: String
    let mediaType: String
    let properties: Set<String>
}

struct TOCEntry: Equatable, Identifiable {
    let id = UUID()
    let title: String
    let href: String
    let spineIndex: Int?
    let depth: Int

    static func == (lhs: TOCEntry, rhs: TOCEntry) -> Bool {
        lhs.title == rhs.title && lhs.href == rhs.href
            && lhs.spineIndex == rhs.spineIndex && lhs.depth == rhs.depth
    }
}

/// Everything the reader needs from an unpacked EPUB.
struct ParsedEPUB {
    let title: String
    let author: String
    /// Absolute file URLs of the spine documents, reading order.
    let spineURLs: [URL]
    /// Spine hrefs relative to the OPF directory (for TOC matching).
    let spineHrefs: [String]
    let coverImageURL: URL?
    let toc: [TOCEntry]
    /// Relative byte size of every spine document.
    let spineWeights: [Double]
}

enum EPUBError: LocalizedError {
    case missingContainer
    case missingOPF(String)
    case emptySpine
    case unreadableArchive(String)

    var errorDescription: String? {
        switch self {
        case .missingContainer:
            return "The EPUB has no META-INF/container.xml."
        case .missingOPF(let path):
            return "The EPUB package document is missing (\(path))."
        case .emptySpine:
            return "The EPUB contains no readable chapters."
        case .unreadableArchive(let reason):
            return "The file could not be opened as an EPUB: \(reason)"
        }
    }
}
