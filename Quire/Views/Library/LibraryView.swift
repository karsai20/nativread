import SwiftUI
import UniformTypeIdentifiers

/// The shelf. Warm paper surface, serif wordmark, two-column cover grid.
struct LibraryView: View {
    @Environment(LibraryStore.self) private var library
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(StatsStore.self) private var statsStore
    @Environment(\.colorScheme) private var colorScheme

    @State private var isImporterPresented = false
    @State private var openBook: Book?
    @State private var importError: String?
    @State private var isStatsPresented = false
    @State private var isImporting = false

    /// The shelf chrome follows the active reading theme so the library
    /// and the reader feel like one continuous surface.
    private var palette: ReaderPalette {
        settingsStore.settings.palette(systemDark: colorScheme == .dark)
    }

    private var sortedBooks: [Book] {
        library.books.sorted {
            ($0.lastOpenedAt ?? $0.addedAt)
                > ($1.lastOpenedAt ?? $1.addedAt)
        }
    }

    var body: some View {
        ZStack {
            palette.background.ignoresSafeArea()

            if library.books.isEmpty {
                emptyState
            } else {
                shelf
            }

            if isImporting {
                LoadingOverlay(palette: palette, message: "Importing…")
                    .accessibilityIdentifier("library.importing")
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: isImporting)
        .preferredColorScheme(palette.isDark ? .dark : .light)
        .onAppear {
            if ProcessInfo.processInfo.arguments
                .contains("-autoOpenFirstBook") {
                openBook = sortedBooks.first
            }
        }
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [
                UTType(filenameExtension: "epub") ?? .data
            ],
            allowsMultipleSelection: true
        ) { result in
            handleImport(result)
        }
        .fullScreenCover(item: $openBook) { book in
            ReaderView(
                book: book,
                library: library,
                settingsStore: settingsStore,
                statsStore: statsStore
            )
        }
        .sheet(isPresented: $isStatsPresented) {
            StatsView()
                .environment(statsStore)
                .environment(settingsStore)
        }
        .alert(
            "Import failed",
            isPresented: Binding(
                get: { importError != nil },
                set: { if !$0 { importError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importError ?? "")
        }
    }

    // MARK: - Shelf

    private var shelf: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.horizontal, 24)
                    .padding(.top, 18)
                    .padding(.bottom, 26)

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 22),
                        GridItem(.flexible(), spacing: 22)
                    ],
                    alignment: .leading,
                    spacing: 30
                ) {
                    ForEach(sortedBooks) { book in
                        Button {
                            openBook = book
                        } label: {
                            BookCard(
                                book: book,
                                coverURL: library.coverURL(for: book),
                                titleColor: palette.text,
                                captionColor: palette.secondaryText
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier(
                            "library.book.\(book.title)"
                        )
                        .contextMenu {
                            Button(role: .destructive) {
                                library.delete(book)
                            } label: {
                                Label("Delete book", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Quire")
                    .font(.system(size: 34, weight: .semibold,
                                  design: .serif))
                    .italic()
                    .foregroundStyle(palette.text)
                Text(
                    "\(library.books.count) book\(library.books.count == 1 ? "" : "s") on the shelf"
                )
                .font(.system(size: 13))
                .foregroundStyle(palette.secondaryText)
            }
            Spacer()
            HStack(spacing: 12) {
                statsButton
                importButton
            }
        }
    }

    private var statsButton: some View {
        Button {
            isStatsPresented = true
        } label: {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(palette.accent)
                .frame(width: 40, height: 40)
                .background(
                    Circle().fill(palette.surface)
                )
        }
        .accessibilityIdentifier("library.stats")
        .accessibilityLabel("Reading statistics")
    }

    private var importButton: some View {
        Button {
            isImporterPresented = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(palette.background)
                .frame(width: 40, height: 40)
                .background(Circle().fill(palette.accent))
        }
        .disabled(isImporting)
        .accessibilityIdentifier("library.import")
        .accessibilityLabel("Import book")
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(palette.surface)
                    .frame(width: 120, height: 120)
                Image(systemName: "books.vertical")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(palette.accent)
            }
            VStack(spacing: 6) {
                Text("Your shelf is empty")
                    .font(.system(size: 24, weight: .semibold,
                                  design: .serif))
                    .italic()
                    .foregroundStyle(palette.text)
                Text("Add an EPUB from Files and start reading.")
                    .font(.system(size: 14))
                    .foregroundStyle(palette.secondaryText)
            }
            Button {
                isImporterPresented = true
            } label: {
                Label("Add a book", systemImage: "plus")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.background)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(palette.accent))
            }
            .disabled(isImporting)
            .accessibilityIdentifier("library.import.empty")
            .padding(.top, 6)
        }
        .padding(32)
    }

    // MARK: - Import

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard !urls.isEmpty else { return }
            importBooks(from: urls)
        case .failure(let error):
            importError = error.localizedDescription
        }
    }

    /// Runs the unzip + EPUB parse off the main thread so large books
    /// no longer freeze the shelf, then hops back to the main actor to
    /// surface progress and errors. `LibraryStore` is reference-shared
    /// and its mutations land via the @Observable book array.
    private func importBooks(from urls: [URL]) {
        isImporting = true
        let library = library
        Task {
            let failureMessage = await Task.detached(
                priority: .userInitiated
            ) { () -> String? in
                var firstFailure: String?
                for url in urls {
                    do {
                        try library.importBook(from: url)
                    } catch {
                        // Surface the first failure; remaining books in
                        // the batch are still attempted.
                        if firstFailure == nil {
                            firstFailure = error.localizedDescription
                        }
                    }
                }
                return firstFailure
            }.value
            isImporting = false
            if let failureMessage {
                importError = failureMessage
            }
        }
    }
}
