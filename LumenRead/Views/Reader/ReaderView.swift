import SwiftUI

struct ReaderView: View {
    @EnvironmentObject private var settings: ReaderSettings
    @EnvironmentObject private var bookStore: BookStore
    @Environment(\.dismiss) private var dismiss

    let book: Book

    @State private var chapterPaths: [URL] = []
    @State private var currentChapter: Int
    @State private var scrollPosition: Double = 0
    @State private var showChrome = false
    @State private var showTypography = false
    @State private var showTOC = false
    @State private var isLoaded = false
    @State private var chromeDismissTask: Task<Void, Never>?

    init(book: Book) {
        self.book = book
        _currentChapter = State(initialValue: book.lastChapterIndex)
        _scrollPosition = State(initialValue: book.lastScrollPosition)
    }

    var body: some View {
        ZStack {
            settings.theme.backgroundColor.ignoresSafeArea()

            if isLoaded && !chapterPaths.isEmpty {
                reader
            } else if !isLoaded {
                loadingView
            } else {
                errorView
            }

            if showChrome {
                chrome
            }
        }
        .ignoresSafeArea()
        .statusBarHidden(!showChrome)
        .preferredColorScheme(settings.theme.systemColorScheme)
        .onAppear { loadChapters() }
        .onDisappear { saveProgress() }
        .sheet(isPresented: $showTypography) {
            TypographyPanel()
                .environmentObject(settings)
        }
        .sheet(isPresented: $showTOC) {
            TOCView(
                titles: book.chapterTitles,
                currentChapter: currentChapter
            ) { index in
                showTOC = false
                navigateTo(chapter: index)
            }
        }
    }

    // MARK: - Reader

    private var reader: some View {
        ReaderWebView(
            chapterURL: chapterPaths[currentChapter],
            css: settings.generateCSS(),
            scrollPosition: $scrollPosition
        ) { newPos in
            scrollPosition = newPos
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture { toggleChrome() }
        .gesture(
            DragGesture(minimumDistance: 50, coordinateSpace: .global)
                .onEnded { handleSwipe($0) }
        )
    }

    // MARK: - Chrome (navigation bar + controls)

    private var chrome: some View {
        VStack(spacing: 0) {
            topBar
            Spacer()
            bottomBar
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.2), value: showChrome)
    }

    private var topBar: some View {
        HStack(spacing: 16) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .medium))
                    .frame(width: 44, height: 44)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(book.title)
                    .font(.system(size: 15, weight: .medium))
                    .lineLimit(1)

                if !book.chapterTitles.isEmpty && currentChapter < book.chapterTitles.count {
                    Text(book.chapterTitles[currentChapter])
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Button { showTOC = true } label: {
                Image(systemName: "list.bullet")
                    .font(.system(size: 16))
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 56)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial)
        .foregroundStyle(.primary)
    }

    private var bottomBar: some View {
        HStack(spacing: 0) {
            // Previous chapter
            Button {
                navigateTo(chapter: currentChapter - 1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 52, height: 52)
            }
            .disabled(currentChapter == 0)

            Spacer()

            // Progress + chapter indicator
            VStack(spacing: 4) {
                Text("\(currentChapter + 1) / \(chapterPaths.count)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                ProgressView(value: book.readingProgress)
                    .frame(width: 80)
                    .tint(.primary.opacity(0.5))
            }

            Spacer()

            // Typography
            Button { showTypography = true } label: {
                Image(systemName: "textformat.size")
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 52, height: 52)
            }

            // Next chapter
            Button {
                navigateTo(chapter: currentChapter + 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 52, height: 52)
            }
            .disabled(currentChapter >= chapterPaths.count - 1)
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 32)
        .background(.ultraThinMaterial)
        .foregroundStyle(.primary)
    }

    // MARK: - Supporting views

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.3)
            Text("Opening book…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var errorView: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(.secondary)
            Text("Could not load this book")
                .font(.headline)
            Button("Close") { dismiss() }
        }
    }

    // MARK: - Actions

    private func loadChapters() {
        Task {
            let paths = bookStore.chapterPaths(for: book)
            await MainActor.run {
                chapterPaths = paths
                isLoaded = true
                currentChapter = min(book.lastChapterIndex, max(0, paths.count - 1))
                scrollPosition = book.lastScrollPosition
            }
        }
    }

    private func navigateTo(chapter index: Int) {
        guard index >= 0 && index < chapterPaths.count else { return }
        saveProgress()
        scrollPosition = 0
        currentChapter = index
    }

    private func handleSwipe(_ gesture: DragGesture.Value) {
        let dx = gesture.translation.width
        guard abs(dx) > 60 else { return }
        if dx < 0 {
            navigateTo(chapter: currentChapter + 1)
        } else {
            navigateTo(chapter: currentChapter - 1)
        }
    }

    private func toggleChrome() {
        chromeDismissTask?.cancel()
        withAnimation { showChrome.toggle() }
        if showChrome {
            chromeDismissTask = Task {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                if !Task.isCancelled {
                    await MainActor.run {
                        withAnimation { showChrome = false }
                    }
                }
            }
        }
    }

    private func saveProgress() {
        bookStore.updateProgress(
            bookID: book.id,
            chapterIndex: currentChapter,
            scrollPosition: scrollPosition
        )
    }
}

// MARK: - Table of Contents

private struct TOCView: View {
    let titles: [String]
    let currentChapter: Int
    let onSelect: (Int) -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(titles.enumerated()), id: \.offset) { index, title in
                    HStack {
                        Text(title)
                            .font(.system(size: 15))
                            .foregroundStyle(index == currentChapter ? .primary : .secondary)
                        Spacer()
                        if index == currentChapter {
                            Image(systemName: "bookmark.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { onSelect(index) }
                }
            }
            .navigationTitle("Contents")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
