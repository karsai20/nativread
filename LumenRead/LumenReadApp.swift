import SwiftUI

@main
struct VersoApp: App {
    @StateObject private var bookStore = BookStore()
    @StateObject private var readerSettings = ReaderSettings()

    var body: some Scene {
        WindowGroup {
            LibraryView()
                .environmentObject(bookStore)
                .environmentObject(readerSettings)
                .onOpenURL { url in
                    bookStore.importEPUB(from: url)
                }
        }
    }
}
