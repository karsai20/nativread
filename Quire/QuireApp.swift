import SwiftUI

@main
struct QuireApp: App {
    @State private var library: LibraryStore
    @State private var settingsStore: SettingsStore
    @State private var statsStore: StatsStore
    @State private var dictionaryProvider = DictionaryProvider()

    init() {
        let store = LibraryStore()
        Self.applyLaunchArguments(to: store)
        _library = State(initialValue: store)
        if ProcessInfo.processInfo.arguments.contains("-resetSettings") {
            SettingsStore.resetPersisted()
        }
        let settings = SettingsStore()
        Self.applyThemeArgument(to: settings)
        _settingsStore = State(initialValue: settings)
        _statsStore = State(initialValue: StatsStore())
    }

    var body: some Scene {
        WindowGroup {
            LibraryView()
                .environment(library)
                .environment(settingsStore)
                .environment(statsStore)
                .environment(dictionaryProvider)
                .task {
                    // Load dictionaries in the background; never block launch.
                    await dictionaryProvider.prepare()
                }
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

    /// `-forceTheme dusk`, `-forceFlow scroll`, `-forceTransition eink`
    /// pin reading settings for UI tests and screenshot automation.
    private static func applyThemeArgument(to store: SettingsStore) {
        let arguments = ProcessInfo.processInfo.arguments

        func value(after flag: String) -> String? {
            guard let flagIndex = arguments.firstIndex(of: flag),
                  arguments.indices.contains(flagIndex + 1) else {
                return nil
            }
            return arguments[flagIndex + 1]
        }

        let theme = value(after: "-forceTheme")
            .flatMap(ReaderTheme.init(rawValue:))
        let flow = value(after: "-forceFlow")
            .flatMap(PageFlow.init(rawValue:))
        let transition = value(after: "-forceTransition")
            .flatMap(PageTransition.init(rawValue:))
        guard theme != nil || flow != nil || transition != nil else {
            return
        }
        store.overrideWithoutPersisting { current in
            var next = current
            if let theme { next.theme = theme }
            if let flow { next.pageFlow = flow }
            if let transition { next.pageTransition = transition }
            return next
        }
    }
}
