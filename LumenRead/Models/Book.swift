import Foundation

struct Book: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var author: String
    var fileName: String
    var coverImageData: Data?
    var lastChapterIndex: Int
    var lastScrollPosition: Double
    var totalChapters: Int
    var addedDate: Date
    var chapterTitles: [String]

    var readingProgress: Double {
        guard totalChapters > 0 else { return 0 }
        return Double(lastChapterIndex) / Double(totalChapters)
    }

    var fileURL: URL {
        FileManager.documentsURL.appendingPathComponent("Books").appendingPathComponent(fileName)
    }

    var extractionURL: URL {
        FileManager.documentsURL.appendingPathComponent("Extracted").appendingPathComponent(id.uuidString)
    }

    init(
        id: UUID = UUID(),
        title: String,
        author: String,
        fileName: String,
        coverImageData: Data? = nil,
        lastChapterIndex: Int = 0,
        lastScrollPosition: Double = 0,
        totalChapters: Int = 0,
        addedDate: Date = Date(),
        chapterTitles: [String] = []
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.fileName = fileName
        self.coverImageData = coverImageData
        self.lastChapterIndex = lastChapterIndex
        self.lastScrollPosition = lastScrollPosition
        self.totalChapters = totalChapters
        self.addedDate = addedDate
        self.chapterTitles = chapterTitles
    }
}

extension FileManager {
    static var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
