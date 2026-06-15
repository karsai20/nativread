import SwiftUI
import Observation

enum ReaderSheet: String, Identifiable {
    case contents, typography, search
    var id: String { rawValue }
}

/// Drives one reading session: chapter loading, paging across chapter
/// boundaries, progress persistence, bookmarks, search navigation.
@MainActor
@Observable
final class ReaderViewModel {

    let bookID: UUID
    private let library: LibraryStore
    private let settingsStore: SettingsStore
    let controller: ReaderController

    private(set) var parsed: ParsedEPUB?
    private(set) var spineIndex = 0
    private(set) var page = 0
    private(set) var pageCount = 1
    var isChromeVisible = true
    var activeSheet: ReaderSheet?
    var loadError: String?
    var searchQuery = ""
    private(set) var searchResults: [SearchResult] = []

    private var extractedRoot: URL
    private var suppressProgressSave = false

    var settings: ReaderSettings { settingsStore.settings }
    var book: Book? { library.book(id: bookID) }

    /// Tracks the device appearance for system theme mode; fed by the
    /// view layer because only SwiftUI sees colour scheme changes.
    private(set) var systemDark = false

    /// The resolved colours every reader surface should draw with.
    var palette: ReaderPalette { settings.palette(systemDark: systemDark) }

    init(
        book: Book,
        library: LibraryStore,
        settingsStore: SettingsStore,
        pageSize: CGSize
    ) {
        self.bookID = book.id
        self.library = library
        self.settingsStore = settingsStore
        self.extractedRoot = library.extractedRoot(for: book)
        self.controller = ReaderController(
            pageSize: pageSize,
            initialCSS: ReaderStyle.css(
                settings: settingsStore.settings,
                pageWidth: pageSize.width,
                pageHeight: pageSize.height
            ),
            flow: settingsStore.settings.pageFlow,
            transition: settingsStore.settings.pageTransition
        )
        controller.onState = { [weak self] page, pageCount in
            self?.handleState(page: page, pageCount: pageCount)
        }
        controller.onTap = { [weak self] zone in
            self?.handleTap(zone: zone)
        }
        controller.onSwipe = { [weak self] direction in
            if direction == "forward" {
                self?.nextPage()
            } else {
                self?.prevPage()
            }
        }
        controller.onHighlightRequested = { [weak self] in
            self?.highlightCurrentSelection()
        }
        controller.onChapterReady = { [weak self] in
            self?.applyStoredHighlights()
        }
        controller.onOverscroll = { [weak self] direction in
            if direction == "forward" {
                self?.goToNextChapter()
            } else {
                self?.goToPreviousChapter()
            }
        }
    }

    /// Persists any coalesced reading progress right away. Call when the
    /// reader closes so the last scroll position is never lost.
    func persistProgressNow() {
        library.flushPendingSave()
    }

    private func handleTap(zone: String) {
        switch zone {
        case "left":
            prevPage()
        case "right":
            nextPage()
        default:
            withAnimation(.easeOut(duration: 0.22)) {
                isChromeVisible.toggle()
            }
        }
    }

    // MARK: - Session

    func open() {
        do {
            let parsed = try library.parsedEPUB(
                for: library.book(id: bookID)!
            )
            self.parsed = parsed
            let progress = book?.progress ?? ReadingProgress()
            loadChapter(
                at: min(progress.spineIndex, parsed.spineURLs.count - 1),
                fraction: progress.pageFraction
            )
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func loadChapter(
        at index: Int, fraction: Double, locate: (String, Int)? = nil
    ) {
        guard let parsed, parsed.spineURLs.indices.contains(index) else {
            return
        }
        spineIndex = index
        controller.loadChapter(
            at: parsed.spineURLs[index],
            readAccessRoot: extractedRoot,
            fraction: fraction,
            locate: locate
        )
    }

    private func handleState(page: Int, pageCount: Int) {
        self.page = page
        self.pageCount = pageCount
        guard !suppressProgressSave else { return }
        library.updateProgress(
            bookID: bookID,
            spineIndex: spineIndex,
            pageFraction: pageCount > 1
                ? Double(page) / Double(pageCount - 1) : 0
        )
    }

    // MARK: - Paging

    func nextPage() {
        controller.nextPage { [weak self] turned in
            guard let self, !turned, let parsed = self.parsed else { return }
            if self.spineIndex < parsed.spineURLs.count - 1 {
                self.loadChapter(at: self.spineIndex + 1, fraction: 0)
            }
        }
    }

    func prevPage() {
        controller.prevPage { [weak self] turned in
            guard let self, !turned else { return }
            if self.spineIndex > 0 {
                self.loadChapter(at: self.spineIndex - 1, fraction: 1)
            }
        }
    }

    // MARK: - Navigation

    var bookFraction: Double {
        guard let book else { return 0 }
        return Book.bookFraction(
            spineIndex: spineIndex,
            pageFraction: pageCount > 1
                ? Double(page) / Double(pageCount - 1) : 0,
            weights: book.spineWeights
        )
    }

    func scrub(toBookFraction fraction: Double) {
        guard let book else { return }
        let position = Book.position(
            forBookFraction: fraction, weights: book.spineWeights
        )
        if position.spineIndex == spineIndex {
            controller.goToFraction(position.pageFraction)
        } else {
            loadChapter(
                at: position.spineIndex, fraction: position.pageFraction
            )
        }
    }

    func goTo(entry: TOCEntry) {
        guard let target = entry.spineIndex else { return }
        activeSheet = nil
        if target != spineIndex {
            loadChapter(at: target, fraction: 0)
        } else {
            controller.goToFraction(0)
        }
    }

    func goTo(bookmark: Bookmark) {
        activeSheet = nil
        loadChapter(
            at: bookmark.spineIndex, fraction: bookmark.pageFraction
        )
    }

    func goTo(result: SearchResult) {
        activeSheet = nil
        loadChapter(
            at: result.spineIndex,
            fraction: 0,
            locate: (searchQuery, result.occurrenceInChapter)
        )
    }

    var currentChapterTitle: String {
        guard let parsed else { return "" }
        return SearchService.chapterTitle(
            forSpineIndex: spineIndex, in: parsed
        )
    }

    // MARK: - Chapter advance (scroll flow affordances)

    var hasNextChapter: Bool {
        guard let parsed else { return false }
        return spineIndex < parsed.spineURLs.count - 1
    }

    var nextChapterTitle: String {
        guard let parsed, hasNextChapter else { return "" }
        return SearchService.chapterTitle(
            forSpineIndex: spineIndex + 1, in: parsed
        )
    }

    /// True when the reader sits on the last screenful of the chapter.
    var isAtChapterEnd: Bool {
        page >= pageCount - 1
    }

    func goToNextChapter() {
        guard hasNextChapter else { return }
        loadChapter(at: spineIndex + 1, fraction: 0)
    }

    func goToPreviousChapter() {
        guard spineIndex > 0 else { return }
        loadChapter(at: spineIndex - 1, fraction: 1)
    }

    // MARK: - Bookmarks

    private var currentPageFraction: Double {
        pageCount > 1 ? Double(page) / Double(pageCount - 1) : 0
    }

    var currentBookmark: Bookmark? {
        book?.bookmarks.first {
            $0.spineIndex == spineIndex
                && abs($0.pageFraction - currentPageFraction)
                    < 0.5 / Double(max(pageCount, 1))
        }
    }

    func toggleBookmark() {
        if let existing = currentBookmark {
            library.removeBookmark(bookID: bookID, bookmarkID: existing.id)
            return
        }
        let spine = spineIndex
        let fraction = currentPageFraction
        let chapter = currentChapterTitle
        controller.snippet { [weak self] snippet in
            guard let self else { return }
            self.library.addBookmark(bookID: self.bookID, bookmark: Bookmark(
                spineIndex: spine,
                pageFraction: fraction,
                chapterTitle: chapter,
                snippet: snippet.isEmpty ? chapter : snippet
            ))
        }
    }

    func removeBookmark(_ bookmark: Bookmark) {
        library.removeBookmark(bookID: bookID, bookmarkID: bookmark.id)
    }

    // MARK: - Highlights

    private var chapterHighlights: [Highlight] {
        (book?.highlights ?? []).filter { $0.spineIndex == spineIndex }
    }

    private func applyStoredHighlights() {
        let highlights = chapterHighlights
        guard !highlights.isEmpty else { return }
        controller.applyHighlights(highlights)
    }

    /// Persists the current selection as a highlight and redraws.
    func highlightCurrentSelection() {
        let chapter = currentChapterTitle
        controller.selectionLocator { [weak self] locator in
            guard let self, let locator else { return }
            self.library.addHighlight(bookID: self.bookID, highlight:
                Highlight(
                    spineIndex: self.spineIndex,
                    text: locator.text,
                    occurrence: locator.occurrence,
                    chapterTitle: chapter
                )
            )
            self.controller.clearSelection()
            self.applyStoredHighlights()
        }
    }

    func goTo(highlight: Highlight) {
        activeSheet = nil
        loadChapter(
            at: highlight.spineIndex,
            fraction: 0,
            locate: (highlight.text, highlight.occurrence)
        )
    }

    /// Sets or clears the reader's note on a highlight. A blank or
    /// whitespace-only note is stored as `nil`, never an empty string.
    func setNote(_ note: String?, for highlight: Highlight) {
        let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        library.setHighlightNote(
            bookID: bookID,
            highlightID: highlight.id,
            note: (trimmed?.isEmpty ?? true) ? nil : trimmed
        )
    }

    func removeHighlight(_ highlight: Highlight) {
        library.removeHighlight(
            bookID: bookID, highlightID: highlight.id
        )
        if highlight.spineIndex == spineIndex {
            controller.applyHighlights(chapterHighlights)
        }
    }

    // MARK: - Search

    func runSearch() {
        guard let parsed else { return }
        searchResults = SearchService.search(query: searchQuery, in: parsed)
    }

    // MARK: - Settings

    func updateSettings(_ transform: (ReaderSettings) -> ReaderSettings) {
        let previousFlow = settings.pageFlow
        settingsStore.update(transform)
        reapplyStyle()
        // Switching between paged and scroll changes the document layout
        // fundamentally; reload the chapter at the same position.
        if settings.pageFlow != previousFlow {
            loadChapter(at: spineIndex, fraction: currentPageFraction)
        }
    }

    func setSystemDark(_ dark: Bool) {
        guard dark != systemDark else { return }
        systemDark = dark
        guard settings.themeMode == .system else { return }
        reapplyStyle()
    }

    private func reapplyStyle() {
        controller.applySettings(
            css: ReaderStyle.css(
                settings: settings,
                pageWidth: controller.pageSize.width,
                pageHeight: controller.pageSize.height,
                systemDark: systemDark
            ),
            backgroundColor: UIColor(palette.background),
            flow: settings.pageFlow,
            transition: settings.pageTransition
        )
    }
}
