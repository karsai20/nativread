import SwiftUI
import Observation
import PDFKit

enum PDFReaderSheet: String, Identifiable {
    case contents, search, appearance
    var id: String { rawValue }
}

/// One entry in a PDF's outline (table of contents).
struct PDFTOCItem: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let pageIndex: Int
    let depth: Int
}

/// One whole-document search hit: which page and the matched text.
struct PDFSearchResult: Identifiable, Equatable {
    let id = UUID()
    let pageIndex: Int
    let snippet: String
}

/// Drives one PDF reading session. Mirrors the public surface
/// `ReaderView` reads (page, pageCount, bookFraction, chrome, sheets,
/// bookmarks, define) so the chrome can be shared, but renders fixed
/// layout through PDFKit rather than the reflowable web engine.
@MainActor
@Observable
final class PDFReaderViewModel {

    let bookID: UUID
    let documentURL: URL
    /// Owned for metadata, TOC and search; the display surface keeps its
    /// own copy so a night-mode reload never invalidates these.
    let document: PDFDocument

    private let library: LibraryStore
    private let settingsStore: SettingsStore
    private let statsStore: StatsStore
    private var sessionStart: Date?

    private(set) var page = 0
    private(set) var pageCount = 1
    /// The last page index actually written to storage. Persistence dedups
    /// against this, not against `page` — external navigation (tap zones,
    /// TOC, search, scrubber) sets `page` first and only then settles the
    /// PDFView, so deduping on `page` would drop every non-swipe page turn.
    private var lastPersistedPage = 0
    var isChromeVisible = true
    var activeSheet: PDFReaderSheet?
    var loadError: String?

    var defineWord: String?
    private(set) var defineContext: String?

    var searchQuery = ""
    private(set) var searchResults: [PDFSearchResult] = []
    private(set) var isSearching = false
    private(set) var hasSearched = false

    private(set) var systemDark: Bool

    var settings: ReaderSettings { settingsStore.settings }
    var palette: ReaderPalette { settings.palette(systemDark: systemDark) }
    /// Night invert engages whenever the resolved theme is a dark one.
    var isNight: Bool { palette.isDark }
    /// A warm multiply tint laid over the white page for the sepia theme;
    /// nil for light and dark themes (dark inverts instead).
    var pageTint: Color? {
        settings.effectiveTheme(systemDark: systemDark) == .sepia
            ? palette.background : nil
    }

    var book: Book? { library.book(id: bookID) }

    init(
        book: Book,
        library: LibraryStore,
        settingsStore: SettingsStore,
        statsStore: StatsStore,
        initialSystemDark: Bool = false
    ) {
        self.bookID = book.id
        self.library = library
        self.settingsStore = settingsStore
        self.statsStore = statsStore
        self.systemDark = initialSystemDark
        self.documentURL = library.booksDirectory
            .appendingPathComponent(book.fileName)

        if let document = PDFDocument(url: documentURL) {
            self.document = document
            self.pageCount = max(document.pageCount, 1)
        } else {
            self.document = PDFDocument()
            self.loadError = PDFImportError.unreadable.localizedDescription
        }
        self.page = min(max(book.progress.spineIndex, 0), pageCount - 1)
        self.lastPersistedPage = self.page
    }

    // MARK: - Session

    func open() { sessionStart = .now }

    func persistProgressNow() {
        library.flushPendingSave()
        if let start = sessionStart {
            statsStore.record(seconds: Date().timeIntervalSince(start))
            sessionStart = nil
        }
    }

    func setSystemDark(_ dark: Bool) {
        systemDark = dark
    }

    // MARK: - Paging & progress

    /// Records the page the display surface settled on. `pageFraction` is
    /// stored as 1.0 so the shared whole-book math reads "(page+1)/count",
    /// i.e. the last page is 100%.
    func setPage(_ index: Int) {
        let clamped = min(max(index, 0), pageCount - 1)
        page = clamped
        // Persist whenever the settled page differs from what's on disk.
        // Deduping here (not on `page`) is what lets tap/TOC/search/scrubber
        // turns persist: those move `page` before this settle callback runs.
        guard clamped != lastPersistedPage else { return }
        lastPersistedPage = clamped
        library.updateProgress(
            bookID: bookID, spineIndex: clamped, pageFraction: 1.0
        )
    }

    var bookFraction: Double {
        pageCount > 0 ? Double(page + 1) / Double(pageCount) : 0
    }

    /// Maps a scrubber fraction back to a page index.
    func scrub(toFraction fraction: Double) {
        let target = Int((fraction * Double(pageCount)).rounded(.down))
        page = min(max(target, 0), pageCount - 1)
    }

    func goToPage(_ index: Int) {
        page = min(max(index, 0), pageCount - 1)
    }

    var pageLabel: String {
        let percent = Int((bookFraction * 100).rounded())
        return "\(page + 1) / \(pageCount) · \(percent)%"
    }

    // MARK: - Tap zones

    func handleTap(zone: String) {
        switch zone {
        case "left": goToPage(page - 1)
        case "right": goToPage(page + 1)
        default:
            withAnimation(.easeOut(duration: 0.22)) { isChromeVisible.toggle() }
        }
    }

    // MARK: - Contents (outline)

    var toc: [PDFTOCItem] {
        guard let root = document.outlineRoot else { return [] }
        var items: [PDFTOCItem] = []
        flatten(root, depth: -1, into: &items)
        return items
    }

    private func flatten(
        _ outline: PDFOutline, depth: Int, into items: inout [PDFTOCItem]
    ) {
        if depth >= 0, let label = outline.label, !label.isEmpty {
            let index = outline.destination?.page
                .flatMap { document.index(for: $0) } ?? 0
            items.append(PDFTOCItem(
                title: label, pageIndex: index, depth: depth
            ))
        }
        for child in 0..<outline.numberOfChildren {
            if let node = outline.child(at: child) {
                flatten(node, depth: depth + 1, into: &items)
            }
        }
    }

    func goTo(tocItem: PDFTOCItem) {
        activeSheet = nil
        goToPage(tocItem.pageIndex)
    }

    // MARK: - Bookmarks (page-indexed)

    var currentBookmark: Bookmark? {
        book?.bookmarks.first { $0.spineIndex == page }
    }

    func toggleBookmark() {
        if let existing = currentBookmark {
            library.removeBookmark(bookID: bookID, bookmarkID: existing.id)
            return
        }
        let label = "Page \(page + 1)"
        let snippet = document.page(at: page)?.string?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(120)
        library.addBookmark(bookID: bookID, bookmark: Bookmark(
            spineIndex: page,
            pageFraction: 0,
            chapterTitle: label,
            snippet: snippet.map(String.init).flatMap {
                $0.isEmpty ? nil : $0
            } ?? label
        ))
    }

    func goTo(bookmark: Bookmark) {
        activeSheet = nil
        goToPage(bookmark.spineIndex)
    }

    func removeBookmark(_ bookmark: Bookmark) {
        library.removeBookmark(bookID: bookID, bookmarkID: bookmark.id)
    }

    // MARK: - Define

    /// Presents Define for a selection made in the PDF view.
    func define(selection raw: String) {
        guard let word = ReaderViewModel.defineTarget(from: raw) else { return }
        defineContext = nil
        defineWord = word
    }

    func saveToVocabulary(
        definition: String, dictionarySource: String,
        into store: VocabularyStore
    ) {
        guard let word = defineWord else { return }
        store.addEntry(VocabularyEntry(
            word: word,
            definition: definition,
            contextSentence: defineContext,
            dictionarySource: dictionarySource,
            bookID: bookID,
            chapterTitle: "Page \(page + 1)"
        ))
    }

    // MARK: - Appearance

    func setTheme(_ theme: ReaderTheme) {
        settingsStore.update { settings in
            var updated = settings
            updated.theme = theme
            updated.themeMode = .manual
            return updated
        }
    }

    var currentTheme: ReaderTheme {
        settings.effectiveTheme(systemDark: systemDark)
    }

    // MARK: - Search

    func runSearch() {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else {
            searchResults = []
            hasSearched = false
            isSearching = false
            return
        }
        isSearching = true
        hasSearched = false
        // ponytail: synchronous findString blocks until done; fine for
        // typical books. Move to PDFDocument.beginFindString (delegate
        // callbacks) if very large PDFs make the sheet hitch.
        let matches = document.findString(
            query, withOptions: [.caseInsensitive, .diacriticInsensitive]
        )
        searchResults = matches.compactMap { selection in
            guard let pageOfMatch = selection.pages.first else { return nil }
            let index = document.index(for: pageOfMatch)
            return PDFSearchResult(
                pageIndex: index,
                snippet: snippet(for: selection, on: pageOfMatch)
            )
        }
        isSearching = false
        hasSearched = true
    }

    /// A readable snippet around a match: the line of text it sits on,
    /// falling back to the bare match string.
    private func snippet(for selection: PDFSelection, on page: PDFPage) -> String {
        let match = selection.string?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard let pageText = page.string, !match.isEmpty,
              let range = pageText.range(
                  of: match, options: .caseInsensitive
              )
        else { return match }
        // Widen to the surrounding ~80 characters for context.
        let lower = pageText.index(
            range.lowerBound,
            offsetBy: -40,
            limitedBy: pageText.startIndex
        ) ?? pageText.startIndex
        let upper = pageText.index(
            range.upperBound,
            offsetBy: 40,
            limitedBy: pageText.endIndex
        ) ?? pageText.endIndex
        return pageText[lower..<upper]
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func goTo(result: PDFSearchResult) {
        activeSheet = nil
        goToPage(result.pageIndex)
    }

    var currentChapterTitle: String {
        // The nearest preceding outline entry names the reader's location;
        // pages without an outline fall back to a plain page label.
        let here = toc.last { $0.pageIndex <= page }
        return here?.title ?? "Page \(page + 1)"
    }
}
