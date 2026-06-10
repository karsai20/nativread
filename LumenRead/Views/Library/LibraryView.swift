import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @EnvironmentObject private var bookStore: BookStore
    @EnvironmentObject private var settings: ReaderSettings
    @State private var showImporter = false
    @State private var selectedBook: Book?
    @State private var showDeleteConfirm = false
    @State private var bookToDelete: Book?

    private let columns = [
        GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 24)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if bookStore.books.isEmpty {
                    emptyState
                } else {
                    bookGrid
                }
            }
            .background(Color(.systemBackground))
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showImporter = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.medium)
                    }
                }
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [UTType(filenameExtension: "epub") ?? .data],
                allowsMultipleSelection: true
            ) { result in
                handleImport(result)
            }
            .alert("Import Error", isPresented: .init(
                get: { bookStore.importError != nil },
                set: { if !$0 { bookStore.importError = nil } }
            )) {
                Button("OK") { bookStore.importError = nil }
            } message: {
                Text(bookStore.importError ?? "")
            }
        }
        .overlay {
            if bookStore.isImporting {
                importingOverlay
            }
        }
        .fullScreenCover(item: $selectedBook) { book in
            ReaderView(book: book)
                .environmentObject(settings)
                .environmentObject(bookStore)
        }
    }

    // MARK: - Subviews

    private var bookGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 32) {
                ForEach(bookStore.books) { book in
                    BookCard(book: book)
                        .onTapGesture { selectedBook = book }
                        .contextMenu {
                            Button(role: .destructive) {
                                bookToDelete = book
                                showDeleteConfirm = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
        .confirmationDialog(
            "Delete \"\(bookToDelete?.title ?? "")\"?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let b = bookToDelete { bookStore.deleteBook(b) }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "books.vertical")
                .font(.system(size: 64, weight: .thin))
                .foregroundStyle(Color.primary.opacity(0.3))

            Text("Your library is empty")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)

            Text("Tap + to import an EPUB, or copy files\ninto the LumenRead folder in the Files app.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            Button {
                showImporter = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                    Text("Add Book")
                }
                .font(.body.weight(.medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.accentColor, in: Capsule())
            }
            .padding(.top, 8)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .padding(40)
        .onAppear {
            print("📖 Empty state is showing")
        }
    }

    private var importingOverlay: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(.white)
                Text("Importing…")
                    .font(.subheadline)
                    .foregroundStyle(.white)
            }
            .padding(32)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        }
    }

    // MARK: - Actions

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            for url in urls {
                bookStore.importEPUB(from: url)
            }
        case .failure(let error):
            bookStore.importError = error.localizedDescription
        }
    }
}
