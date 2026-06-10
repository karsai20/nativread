import SwiftUI
import UniformTypeIdentifiers

/// The shelf. Warm paper surface, serif wordmark, two-column cover grid.
struct LibraryView: View {
    @Environment(LibraryStore.self) private var library
    @Environment(SettingsStore.self) private var settingsStore

    @State private var isImporterPresented = false
    @State private var openBook: Book?
    @State private var importError: String?

    private let paper = Color(hex: "#F7F2E9")
    private let ink = Color(hex: "#211C15")
    private let accent = Color(hex: "#9A3B2E")

    private var sortedBooks: [Book] {
        library.books.sorted {
            ($0.lastOpenedAt ?? $0.addedAt)
                > ($1.lastOpenedAt ?? $1.addedAt)
        }
    }

    var body: some View {
        ZStack {
            paper.ignoresSafeArea()

            if library.books.isEmpty {
                emptyState
            } else {
                shelf
            }
        }
        .preferredColorScheme(.light)
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
                book: book, library: library, settingsStore: settingsStore
            )
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
                                coverURL: library.coverURL(for: book)
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
                Text("LumenRead")
                    .font(.system(size: 34, weight: .semibold,
                                  design: .serif))
                    .italic()
                    .foregroundStyle(ink)
                Text(
                    "\(library.books.count) book\(library.books.count == 1 ? "" : "s") on the shelf"
                )
                .font(.system(size: 13))
                .foregroundStyle(ink.opacity(0.55))
            }
            Spacer()
            importButton
        }
    }

    private var importButton: some View {
        Button {
            isImporterPresented = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(paper)
                .frame(width: 40, height: 40)
                .background(Circle().fill(accent))
        }
        .accessibilityIdentifier("library.import")
        .accessibilityLabel("Import book")
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.08))
                    .frame(width: 120, height: 120)
                Image(systemName: "books.vertical")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(accent)
            }
            VStack(spacing: 6) {
                Text("Your shelf is empty")
                    .font(.system(size: 24, weight: .semibold,
                                  design: .serif))
                    .italic()
                    .foregroundStyle(ink)
                Text("Add an EPUB from Files and start reading.")
                    .font(.system(size: 14))
                    .foregroundStyle(ink.opacity(0.55))
            }
            Button {
                isImporterPresented = true
            } label: {
                Label("Add a book", systemImage: "plus")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(paper)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(accent))
            }
            .accessibilityIdentifier("library.import.empty")
            .padding(.top, 6)
        }
        .padding(32)
    }

    // MARK: - Import

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            for url in urls {
                do {
                    try library.importBook(from: url)
                } catch {
                    importError = error.localizedDescription
                }
            }
        case .failure(let error):
            importError = error.localizedDescription
        }
    }
}
