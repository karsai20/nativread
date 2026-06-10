import Foundation
import UIKit

final class BookStore: ObservableObject, @unchecked Sendable {
    @Published private(set) var books: [Book] = []
    @Published var importError: String?
    @Published var isImporting = false

    private let fileManager = FileManager.default
    private let parser = EPUBParser()
    private var metadataURL: URL { FileManager.documentsURL.appendingPathComponent("books.json") }
    private var booksDir: URL  { FileManager.documentsURL.appendingPathComponent("Books") }
    private var extractedDir: URL { FileManager.documentsURL.appendingPathComponent("Extracted") }

    init() {
        print("📚 BookStore initializing...")
        prepareDirs()
        loadMetadata()
        print("📚 Loaded \(books.count) books from metadata")
        scanForNewFiles()
    }

    // MARK: - Public API

    func importEPUB(from url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()

        DispatchQueue.main.async { self.isImporting = true }

        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            defer {
                if accessing { url.stopAccessingSecurityScopedResource() }
                DispatchQueue.main.async { self.isImporting = false }
            }
            do {
                let destName = url.lastPathComponent
                let destURL = self.booksDir.appendingPathComponent(destName)

                let alreadyExists = await MainActor.run {
                    self.books.contains(where: { $0.fileName == destName })
                }
                if alreadyExists { return }

                if !self.fileManager.fileExists(atPath: destURL.path) {
                    try self.fileManager.copyItem(at: url, to: destURL)
                }
                try await self.parseAndStore(fileURL: destURL)
            } catch {
                DispatchQueue.main.async {
                    self.importError = error.localizedDescription
                }
            }
        }
    }

    func deleteBook(_ book: Book) {
        books.removeAll { $0.id == book.id }
        saveMetadata()
        try? fileManager.removeItem(at: book.fileURL)
        try? fileManager.removeItem(at: book.extractionURL)
    }

    func updateProgress(bookID: UUID, chapterIndex: Int, scrollPosition: Double) {
        guard let idx = books.firstIndex(where: { $0.id == bookID }) else { return }
        books[idx].lastChapterIndex = chapterIndex
        books[idx].lastScrollPosition = scrollPosition
        saveMetadata()
    }

    func chapterPaths(for book: Book) -> [URL] {
        let dir = book.extractionURL
        guard fileManager.fileExists(atPath: dir.path) else { return [] }
        return (try? parser.parseAlreadyExtracted(in: dir))?.chapterPaths ?? []
    }

    // MARK: - Private

    private func prepareDirs() {
        [booksDir, extractedDir].forEach {
            try? fileManager.createDirectory(at: $0, withIntermediateDirectories: true)
        }
    }

    private func scanForNewFiles() {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: booksDir, includingPropertiesForKeys: nil
        ) else { return }

        let epubs = contents.filter { $0.pathExtension.lowercased() == "epub" }
        let existingNames = Set(books.map(\.fileName))

        Task.detached(priority: .background) { [weak self] in
            guard let self else { return }
            for epubURL in epubs where !existingNames.contains(epubURL.lastPathComponent) {
                try? await self.parseAndStore(fileURL: epubURL)
            }
        }
    }

    private func parseAndStore(fileURL: URL) async throws {
        let bookID = UUID()
        let extractDest = extractedDir.appendingPathComponent(bookID.uuidString)
        let parser = self.parser

        let metadata = try await Task.detached(priority: .userInitiated) {
            try parser.parse(epubURL: fileURL, into: extractDest)
        }.value

        let book = Book(
            id: bookID,
            title: metadata.title,
            author: metadata.author,
            fileName: fileURL.lastPathComponent,
            coverImageData: metadata.coverData,
            totalChapters: metadata.chapterPaths.count,
            chapterTitles: metadata.chapterTitles
        )

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.books.append(book)
            self.books.sort { $0.addedDate > $1.addedDate }
            self.saveMetadata()
        }
    }

    // MARK: - Persistence

    private func loadMetadata() {
        guard let data = try? Data(contentsOf: metadataURL),
              let decoded = try? JSONDecoder().decode([Book].self, from: data)
        else { return }
        books = decoded.sorted { $0.addedDate > $1.addedDate }
    }

    private func saveMetadata() {
        guard let data = try? JSONEncoder().encode(books) else { return }
        try? data.write(to: metadataURL, options: .atomic)
    }
}
