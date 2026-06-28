import SwiftUI

@main
struct QuireApp: App {
    @State private var library: LibraryStore
    @State private var settingsStore: SettingsStore
    @State private var statsStore: StatsStore
    @State private var vocabularyStore: VocabularyStore
    @State private var localizationStore: LocalizationStore
    @State private var dictionaryProvider: DictionaryProvider

    init() {
        let store = LibraryStore()
        Self.applyLaunchArguments(to: store)
        _library = State(initialValue: store)

        if ProcessInfo.processInfo.arguments.contains("-resetSettings") {
            SettingsStore.resetPersisted()
        }
        if ProcessInfo.processInfo.arguments.contains("-resetLanguage") {
            LocalizationStore.resetPersisted()
        }

        let settings = SettingsStore()
        Self.applyThemeArgument(to: settings)
        _settingsStore = State(initialValue: settings)

        _statsStore = State(initialValue: StatsStore())

        let vocabulary = VocabularyStore()
        Self.applyVocabularyArguments(to: vocabulary)
        _vocabularyStore = State(initialValue: vocabulary)

        // Build LocalizationStore first so the initial dictionary set can be
        // derived from the already-persisted language choice (or from the
        // `-forceLanguage` hook).
        let locStore = LocalizationStore()
        Self.applyLanguageArgument(to: locStore)
        _localizationStore = State(initialValue: locStore)

        // Derive the initial dictionary list from the effective dictionary
        // language — honouring an independent Define language choice when set.
        let dictionaries = BundledDictionary.bundled(for: locStore.dictionaryLanguage)
        _dictionaryProvider = State(
            initialValue: DictionaryProvider(dictionaries: dictionaries)
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView(initialShowLaunch: Self.shouldShowLaunch(settingsStore))
                .environment(library)
                .environment(settingsStore)
                .environment(statsStore)
                .environment(vocabularyStore)
                .environment(localizationStore)
                .environment(dictionaryProvider)
                // Apply the chosen locale to the entire view tree so SwiftUI
                // Text nodes use the right String Catalog translation.
                .environment(\.locale, localizationStore.resolvedLocale)
                .task {
                    // Load dictionaries in the background; the launch splash
                    // (when shown) waits on `isReady`, but this kicks off on
                    // every launch regardless of the splash.
                    await dictionaryProvider.prepare()
                }
                .onOpenURL { url in
                    try? library.importBook(from: url)
                }
        }
    }

    /// Decides whether the first-launch splash appears. Shown only the first
    /// time (until `hasSeenOnboarding`), overridable for tests via
    /// `-forceOnboarding` (always show) / `-skipOnboarding` (never show).
    private static func shouldShowLaunch(_ settings: SettingsStore) -> Bool {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-skipOnboarding") { return false }
        if arguments.contains("-forceOnboarding") { return true }
        return !settings.hasSeenOnboarding
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

    /// UI-test hooks for the saved vocabulary: `-resetVocabulary` empties
    /// the list, `-seedSampleVocabulary` adds one deterministic entry so
    /// the My Vocabulary sheet and export can be exercised without driving
    /// the (hard-to-automate) WKWebView selection → Define → Save flow.
    @MainActor
    private static func applyVocabularyArguments(to store: VocabularyStore) {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-resetVocabulary") {
            for entry in store.entries { store.removeEntry(entry.id) }
        }
        if arguments.contains("-seedSampleVocabulary") {
            store.addEntry(VocabularyEntry(
                word: "lantern",
                definition: "a portable case with transparent sides for "
                    + "holding a light",
                contextSentence: "She raised the lantern to the dark "
                    + "doorway.",
                dictionarySource: "WordNet"
            ))
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

    /// `-forceLanguage <code>` (en/es/de/hu) pins the app language for UI
    /// tests without persisting it; subsequent launches revert to the stored
    /// value. `-resetLanguage` is handled in `init()` via `resetPersisted()`.
    private static func applyLanguageArgument(to store: LocalizationStore) {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flagIndex = arguments.firstIndex(of: "-forceLanguage"),
              arguments.indices.contains(flagIndex + 1) else {
            return
        }
        let code = arguments[flagIndex + 1]
        if let language = AppLanguage(rawValue: code) {
            store.overrideWithoutPersisting(language)
        }
    }
}
