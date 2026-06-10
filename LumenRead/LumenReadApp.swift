import SwiftUI

@main
struct LumenReadApp: App {
    @State private var library: LibraryStore
    @State private var settingsStore: SettingsStore

    init() {
        let store = LibraryStore()
        Self.applyLaunchArguments(to: store)
        _library = State(initialValue: store)
        let settings = SettingsStore()
        Self.applyThemeArgument(to: settings)
        _settingsStore = State(initialValue: settings)
    }

    var body: some Scene {
        WindowGroup {
            LibraryView()
                .environment(library)
                .environment(settingsStore)
                .onOpenURL { url in
                    try? library.importBook(from: url)
                }
        }
    }

    /// UI-test hooks: `-resetLibrary` wipes the shelf, `-seedSampleBook`
    /// imports the bundled sample EPUB so tests start deterministic.
    private static func applyLaunchArguments(to store: LibraryStore) {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-resetLibrary") {
            for book in store.books { store.delete(book) }
        }
        if arguments.contains("-seedSampleBook"), store.books.isEmpty {
            for name in ["sample-nocover", "sample"] {
                if let url = Bundle.main.url(
                    forResource: name, withExtension: "epub"
                ) {
                    try? store.importBook(from: url)
                }
            }
        }
    }

    /// `-forceTheme dusk` pins a reading theme (screenshot automation).
    private static func applyThemeArgument(to store: SettingsStore) {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flagIndex = arguments.firstIndex(of: "-forceTheme"),
              arguments.indices.contains(flagIndex + 1),
              let theme = ReaderTheme(rawValue: arguments[flagIndex + 1])
        else { return }
        store.update { current in
            var next = current
            next.theme = theme
            return next
        }
    }
}
