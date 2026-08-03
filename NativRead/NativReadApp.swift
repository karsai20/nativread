import SwiftUI

/// Exists solely to serve the orientation mask, which SwiftUI cannot
/// override per-scene. The reader's rotation-lock toggle flips
/// `lockPortrait` and asks every scene to re-read it.
final class AppDelegate: NSObject, UIApplicationDelegate {
    static var lockPortrait = false

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        Self.lockPortrait ? .portrait : .all
    }

    /// Applies a changed `lockPortrait` to the live UI (iOS 16+ API).
    static func refreshOrientationLock() {
        for case let scene as UIWindowScene
            in UIApplication.shared.connectedScenes {
            for window in scene.windows {
                window.rootViewController?
                    .setNeedsUpdateOfSupportedInterfaceOrientations()
            }
        }
    }
}

@main
struct NativReadApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self)
    private var appDelegate
    @State private var library: LibraryStore
    @State private var settingsStore: SettingsStore
    @State private var translationStore: TranslationStore
    @State private var translationAuthStore: TranslationAuthStore
    @State private var bookPurchaseStore: BookPurchaseStore
    @State private var localizationStore: LocalizationStore

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
        Self.applyTranslationBackendArgument(to: settings)
        AppDelegate.lockPortrait = settings.isOrientationLocked
        _settingsStore = State(initialValue: settings)

        _translationStore = State(initialValue: TranslationStore())
        let auth = TranslationAuthStore(
            initialSessionToken: Self.translationSessionTokenArgument
        )
        _translationAuthStore = State(initialValue: auth)
        _bookPurchaseStore = State(initialValue: BookPurchaseStore { [settings] in
            guard let backendURL = settings.translationBackendURL,
                  let sessionToken = auth.sessionToken
            else { return nil }
            return TranslationBackendClient(
                baseURL: backendURL, bearerToken: sessionToken
            )
        })

        // Build LocalizationStore after the reset hook so the persisted app
        // language can be overridden for tests without touching user defaults.
        let locStore = LocalizationStore()
        Self.applyLanguageArgument(to: locStore)
        _localizationStore = State(initialValue: locStore)

        AppTips.configure()
        AppTips.hasCompletedOnboarding = settings.hasSeenOnboarding
    }

    var body: some Scene {
        WindowGroup {
            RootView(initialShowLaunch: Self.shouldShowLaunch(settingsStore))
                .environment(library)
                .environment(settingsStore)
                .environment(translationStore)
                .environment(translationAuthStore)
                .environment(bookPurchaseStore)
                .environment(localizationStore)
                // Apply the chosen locale to the entire view tree so SwiftUI
                // Text nodes use the right String Catalog translation.
                .environment(\.locale, localizationStore.resolvedLocale)
                // Whole-app Light/Dark/System preference; `.system` → nil so
                // the device setting wins. The reader sets its own scheme while
                // open (its theme system), this governs the library + chrome.
                .preferredColorScheme(settingsStore.appAppearance.colorScheme)
                .onOpenURL { url in
                    _ = try? library.importBook(from: url)
                }
                // A purchase whose confirmation never reached the backend — a
                // dead network, a kill mid-flight — is replayed from here.
                .task { bookPurchaseStore.startObservingTransactions() }
        }
    }

    /// Decides whether the first-launch onboarding appears. Shown only the
    /// first time (until `hasSeenOnboarding`), overridable for tests via
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
        let showcaseLanguage = arguments.firstIndex(
            of: "-seedShowcaseState"
        ).flatMap { index in
            arguments.indices.contains(index + 1)
                ? arguments[index + 1]
                : nil
        }
        if arguments.contains("-resetLibrary") {
            for book in store.books { store.delete(book) }
        }
        if arguments.contains("-seedSampleBook"), store.books.isEmpty {
            for name in ["sample-nocover", "sample"] {
                if let url = Bundle.main.url(
                    forResource: name, withExtension: "epub"
                ) {
                    _ = try? store.importBook(from: url)
                }
            }
        }
        if arguments.contains("-seedAliceBooks"), store.books.isEmpty {
            for name in [
                "alice-wonderland-en",
                "alice-csodaorszagban-hu"
            ] {
                if let url = Bundle.main.url(
                    forResource: name, withExtension: "epub"
                ) {
                    _ = try? store.importBook(from: url)
                }
            }
        }
        if arguments.contains("-seedShowcaseBooks"), store.books.isEmpty {
            for name in [
                "alice-wonderland-standard-en",
                "pal-utcai-fiuk-gutenberg-hu"
            ] {
                if let url = Bundle.main.url(
                    forResource: name, withExtension: "epub"
                ) {
                    _ = try? store.importBook(from: url)
                }
            }
        }
        // PDF / TXT seeds run the real importer over a freshly generated
        // sample, so the PDF reader and synthesized-TXT path can be driven
        // and screenshotted by UI tests.
        if arguments.contains("-seedSamplePDF"),
           !store.books.contains(where: { $0.format == .pdf }),
           let url = SampleDocuments.makePDF(
               languageCode: showcaseLanguage
           ) {
            _ = try? store.importBook(from: url)
        }
        if arguments.contains("-seedSampleText"),
           !store.books.contains(where: { $0.format == .txt }),
           let url = SampleDocuments.makeText() {
            _ = try? store.importBook(from: url)
        }
        // Mark the first book in-progress so the Now Reading hero renders
        // in screenshots without driving the reader by hand.
        if arguments.contains("-seedProgress"), let first = store.books.first {
            store.updateProgress(
                bookID: first.id, spineIndex: 1, pageFraction: 0.4
            )
            store.flushPendingSave()
        }

        // Deterministic, book-native state for the complete bilingual
        // screenshot run. It puts each showcase book inside its first real
        // chapter and supplies one bookmark + annotated highlight so every
        // reader collection has meaningful content.
        if let language = showcaseLanguage {
            let isHungarian = language == "hu"
            let titleFragment = isHungarian ? "Pál-utcai" : "Alice"
            guard let book = store.books.first(where: {
                $0.title.localizedCaseInsensitiveContains(titleFragment)
            }) else { return }

            let spineIndex = min(
                isHungarian ? 3 : 5,
                max(0, book.spineWeights.count - 1)
            )
            let chapterTitle = isHungarian
                ? "I. fejezet"
                : "Chapter I · Down the Rabbit-Hole"
            let snippet = isHungarian
                ? "Háromnegyed egykor a tanteremben minden komolyságnak vége szakadt."
                : "Alice was beginning to get very tired of sitting by her sister."
            let note = isHungarian
                ? "A történet emlékezetes nyitánya."
                : "The beginning of Alice’s extraordinary journey."

            store.updateProgress(
                bookID: book.id,
                spineIndex: spineIndex,
                pageFraction: 0.28
            )
            if book.bookmarks.isEmpty {
                store.addBookmark(
                    bookID: book.id,
                    bookmark: Bookmark(
                        spineIndex: spineIndex,
                        pageFraction: 0.28,
                        chapterTitle: chapterTitle,
                        snippet: snippet
                    )
                )
            }
            // Unlike the bookmark's display-only snippet, the highlight text
            // is a locator: it must match the book text verbatim or the mark
            // never renders. Alice's sentence continues "…on the bank", so
            // the seeded period would make the locator miss.
            let highlightText = isHungarian
                ? snippet
                : "Alice was beginning to get very tired of sitting by her sister"
            if book.highlights.isEmpty {
                store.addHighlight(
                    bookID: book.id,
                    highlight: Highlight(
                        spineIndex: spineIndex,
                        text: highlightText,
                        occurrence: 0,
                        chapterTitle: chapterTitle,
                        note: note
                    )
                )
            }
            store.flushPendingSave()
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

    /// `-translationBackendURL <url>` points UI tests at a local placeholder
    /// backend for this launch only. Production users still choose and persist
    /// their endpoint explicitly in Settings.
    private static func applyTranslationBackendArgument(
        to store: SettingsStore
    ) {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flagIndex = arguments.firstIndex(
            of: "-translationBackendURL"
        ), arguments.indices.contains(flagIndex + 1) else {
            return
        }
        store.overrideTranslationBackendURLWithoutPersisting(
            arguments[flagIndex + 1]
        )
    }

    /// UI-test-only session injection. The token is kept in memory and never
    /// written to Keychain, so automated account screens cannot affect a real
    /// Sign in with Apple session.
    private static var translationSessionTokenArgument: String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flagIndex = arguments.firstIndex(
            of: "-translationSessionToken"
        ), arguments.indices.contains(flagIndex + 1) else {
            return nil
        }
        return arguments[flagIndex + 1]
    }

    /// `-forceLanguage <code>` (en/es/de/hu) pins the app language for UI
    /// tests without persisting it; subsequent launches revert to stored values.
    /// `-resetLanguage` is handled in `init()` via `resetPersisted()`.
    private static func applyLanguageArgument(to store: LocalizationStore) {
        let arguments = ProcessInfo.processInfo.arguments
        if let flagIndex = arguments.firstIndex(of: "-forceLanguage"),
           arguments.indices.contains(flagIndex + 1) {
            let code = arguments[flagIndex + 1]
            if let language = AppLanguage(rawValue: code) {
                store.overrideWithoutPersisting(language)
            }
        }
    }
}
