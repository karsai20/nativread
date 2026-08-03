import SwiftUI
import Observation

enum ReaderSheet: String, Identifiable {
    case contents, position, typography, search
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

    /// Highlight the reader tapped in the text; drives the remove dialog.
    var tappedHighlight: Highlight?
    var loadError: String?

    /// True from the moment a chapter starts loading until the engine
    /// reports the page is painted (`onChapterReady`). Drives the reader
    /// skeleton veil so the blank WKWebView frame is never exposed.
    private(set) var isChapterLoading = false

    /// Guards against a missed ready signal leaving the veil stuck on.
    private var loadingSafetyTask: Task<Void, Never>?
    /// Rotation can report a few intermediate sizes. Debounce those so one
    /// physical turn produces one relayout/reload, not a cascade.
    private var viewportUpdateTask: Task<Void, Never>?
    private var viewportSafeAreaInsets = UIEdgeInsets.zero
    var searchQuery = ""
    private(set) var searchResults: [SearchResult] = []

    /// True while a whole-book search is in flight. Lets the search sheet
    /// show a "Searching…" state instead of a premature "no matches".
    private(set) var isSearching = false

    /// True once a search has actually completed at least once for the
    /// current query, so "no matches" only appears after a real run.
    private(set) var hasSearched = false

    private var extractedRoot: URL
    private var suppressProgressSave = false

    var settings: ReaderSettings { settingsStore.settings }
    var book: Book? { library.book(id: bookID) }

    /// Tracks the device appearance for system theme mode; fed by the
    /// view layer because only SwiftUI sees colour scheme changes.
    private(set) var systemDark = false
    private var reduceMotion = false

    /// The resolved colours every reader surface should draw with.
    var palette: ReaderPalette { settings.palette(systemDark: systemDark) }

    init(
        book: Book,
        library: LibraryStore,
        settingsStore: SettingsStore,
        pageSize: CGSize,
        initialSystemDark: Bool = false
    ) {
        self.bookID = book.id
        self.library = library
        self.settingsStore = settingsStore
        // Seed the appearance before building the initial CSS/palette so the
        // very first painted frame already matches the device (no light→dark
        // flash when a book opens in dark mode).
        self.systemDark = initialSystemDark
        self.extractedRoot = library.extractedRoot(for: book)
        self.controller = ReaderController(
            pageSize: pageSize,
            initialCSS: ReaderStyle.css(
                settings: settingsStore.settings,
                pageWidth: pageSize.width,
                pageHeight: pageSize.height,
                systemDark: initialSystemDark
            ),
            backgroundColor: UIColor(
                settingsStore.settings
                    .palette(systemDark: initialSystemDark).background
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
        controller.onHighlightRequested = { [weak self] in
            self?.highlightCurrentSelection()
        }
        controller.onHighlightTap = { [weak self] text, occurrence in
            guard let self else { return }
            self.tappedHighlight = self.chapterHighlights.first {
                $0.text == text && $0.occurrence == occurrence
            }
        }
        controller.onChapterReady = { [weak self] in
            self?.finishChapterLoading()
            self?.applyStoredHighlights()
        }
        controller.onOverscroll = { [weak self] direction in
            if direction == "forward" {
                return self?.goToNextChapter() ?? false
            } else {
                return self?.goToPreviousChapter() ?? false
            }
        }
    }

    /// Persists any coalesced reading progress right away when the reader
    /// closes.
    func persistProgressNow() {
        viewportUpdateTask?.cancel()
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

    /// Rebuilds the fixed-width pagination engine for the actual laid-out
    /// viewport, preserving the reader's chapter-relative position.
    func viewportDidChange(to viewport: ReaderViewport) {
        let size = viewport.size
        guard size.width > 0, size.height > 0 else { return }
        let insetsChanged = abs(
            viewport.safeAreaInsets.left - viewportSafeAreaInsets.left
        ) > 0.5 || abs(
            viewport.safeAreaInsets.right - viewportSafeAreaInsets.right
        ) > 0.5
        guard insetsChanged
                || abs(size.width - controller.pageSize.width) > 0.5
                || abs(size.height - controller.pageSize.height) > 0.5
        else { return }

        viewportSafeAreaInsets = viewport.safeAreaInsets
        viewportUpdateTask?.cancel()
        viewportUpdateTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(140))
            guard !Task.isCancelled, let self else { return }
            let fraction = self.currentPageFraction
            self.controller.prepareViewport(
                pageSize: size,
                css: ReaderStyle.css(
                    settings: self.settings,
                    pageWidth: size.width,
                    pageHeight: size.height,
                    safeAreaLeft: viewport.safeAreaInsets.left,
                    safeAreaRight: viewport.safeAreaInsets.right,
                    systemDark: self.systemDark
                )
            )
            guard self.parsed != nil else { return }
            self.loadChapter(at: self.spineIndex, fraction: fraction)
        }
    }

    private func loadChapter(
        at index: Int, fraction: Double, locate: (String, Int)? = nil
    ) {
        guard let parsed, parsed.spineURLs.indices.contains(index) else {
            return
        }
        beginChapterLoading()
        spineIndex = index
        lastState = nil
        controller.loadChapter(
            at: parsed.spineURLs[index],
            readAccessRoot: extractedRoot,
            fraction: fraction,
            locate: locate
        )
    }

    /// Raises the loading veil and arms a safety timer so a dropped
    /// `ready` message can never leave the reader stuck behind a skeleton.
    private func beginChapterLoading() {
        isChapterLoading = true
        loadingSafetyTask?.cancel()
        loadingSafetyTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            self?.finishChapterLoading()
        }
    }

    private func finishChapterLoading() {
        loadingSafetyTask?.cancel()
        loadingSafetyTask = nil
        isChapterLoading = false
    }

    /// Last state already applied, to drop no-op notifications. Scroll
    /// flow notifies ~5×/s while the finger moves; re-setting @Observable
    /// properties and touching the library on every one re-renders
    /// SwiftUI mid-scroll for nothing and stutters the glide. Reset on
    /// chapter change so an identical page/count pair in the next
    /// chapter still persists its new spine index.
    private var lastState: (page: Int, pageCount: Int)?

    private func handleState(page: Int, pageCount: Int) {
        guard lastState == nil
            || lastState! != (page: page, pageCount: pageCount) else {
            return
        }
        lastState = (page: page, pageCount: pageCount)
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

    /// Human-scale whole-book location for compact reader chrome and the
    /// expanded position navigator. Unlike the old `page / pageCount` label,
    /// this never mixes chapter-local pages with whole-book percentage.
    var chapterPositionText: String {
        guard let parsed, !parsed.spineURLs.isEmpty else { return "" }
        return "\(spineIndex + 1)/\(parsed.spineURLs.count)"
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

    // MARK: - Chrome page labels

    /// 1-based page number within the chapter, for the resting chrome.
    var currentPageNumber: Int { page + 1 }

    /// Full pages still ahead in this chapter.
    var pagesLeftInChapter: Int { max(0, pageCount - 1 - page) }

    /// Whole-book page estimate at the current typography (see
    /// `Book.estimatedBookPages`).
    var estimatedBookPageCount: Int {
        Book.estimatedBookPages(
            chapterPageCount: pageCount,
            spineIndex: spineIndex,
            weights: book?.spineWeights ?? []
        )
    }

    /// Estimated pages already read of `estimatedBookPageCount`,
    /// clamped so an opened book always shows at least page 1.
    var estimatedBookPagesRead: Int {
        let total = estimatedBookPageCount
        let read = Int((bookFraction * Double(total)).rounded())
        return min(total, max(1, read))
    }

    /// The stored book file, for the share action in the reader menu.
    var bookFileURL: URL? {
        book.map(library.storedFileURL(for:))
    }

    var isOrientationLocked: Bool {
        settingsStore.isOrientationLocked
    }

    /// Persists the flipped lock; the view syncs the UIKit orientation
    /// mask, keeping AppDelegate out of the view model.
    func toggleOrientationLock() {
        settingsStore.setOrientationLocked(!settingsStore.isOrientationLocked)
    }

    @discardableResult
    func goToNextChapter() -> Bool {
        guard hasNextChapter else { return false }
        loadChapter(at: spineIndex + 1, fraction: 0)
        return true
    }

    @discardableResult
    func goToPreviousChapter() -> Bool {
        guard spineIndex > 0 else { return false }
        loadChapter(at: spineIndex - 1, fraction: 1)
        return true
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
        let query = searchQuery
        // Below two characters there is nothing to search; clear without
        // entering the searching state so the hint copy stays visible.
        guard query.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
        else {
            searchResults = []
            hasSearched = false
            isSearching = false
            return
        }
        isSearching = true
        hasSearched = false
        // Whole-book search reads and plain-texts every spine file, so it
        // runs off the main thread to keep the sheet responsive.
        Task {
            let results = await Task.detached(priority: .userInitiated) {
                SearchService.search(query: query, in: parsed)
            }.value
            // Ignore a stale result if the query changed meanwhile.
            guard query == self.searchQuery else { return }
            self.searchResults = results
            self.isSearching = false
            self.hasSearched = true
        }
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

    func setReduceMotion(_ enabled: Bool) {
        guard reduceMotion != enabled else { return }
        reduceMotion = enabled
        reapplyStyle()
    }

    private func reapplyStyle() {
        controller.applySettings(
            css: ReaderStyle.css(
                settings: settings,
                pageWidth: controller.pageSize.width,
                pageHeight: controller.pageSize.height,
                safeAreaLeft: viewportSafeAreaInsets.left,
                safeAreaRight: viewportSafeAreaInsets.right,
                systemDark: systemDark
            ),
            backgroundColor: UIColor(palette.background),
            flow: settings.pageFlow,
            transition: reduceMotion ? .instant : settings.pageTransition
        )
    }
}
