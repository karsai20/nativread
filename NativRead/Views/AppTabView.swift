import SwiftUI

/// The app shell: three destinations that stay put while readers move between
/// them — the shelf, the translation workspace, and preferences. Readers open
/// as full-screen covers above this shell, so a book never loses the tab bar's
/// place underneath it.
struct AppTabView: View {
    /// Owned by `RootView` so finishing the welcome can land on the shelf its
    /// last button promises, whichever tab the reader started from.
    @Binding var selection: Destination

    @Environment(LocalizationStore.self) private var localizationStore
    @Environment(\.colorScheme) private var colorScheme

    private var palette: BrandPalette {
        BrandPalette.resolve(systemDark: colorScheme == .dark)
    }

    var body: some View {
        TabView(selection: $selection) {
            LibraryView()
                .id(localizationStore.appLanguage)
                .tag(Destination.library)
                .tabItem {
                    Label("Library", systemImage: "books.vertical.fill")
                        .accessibilityIdentifier("tab.library")
                }

            TranslateHomeView()
                .id(localizationStore.appLanguage)
                .tag(Destination.translate)
                .tabItem {
                    Label("Translate", systemImage: "character.book.closed.fill")
                        .accessibilityIdentifier("tab.translate")
                }

            SettingsView()
                .id(localizationStore.appLanguage)
                .tag(Destination.settings)
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                        .accessibilityIdentifier("tab.settings")
                }
        }
        .tint(palette.accent)
        // The tab labels re-read the swizzled Bundle whenever this body runs,
        // which observing `appLanguage` above already guarantees — so the shell
        // itself is never rebuilt and the selected tab survives a language change.
        .onAppear(perform: applyTabBarAppearance)
        .onChange(of: palette) { _, _ in applyTabBarAppearance() }
    }

    /// SwiftUI's tab bar still reads from UIKit's appearance proxy, so the
    /// paper surface and hairline have to be pushed down to it.
    private func applyTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(palette.surface)
        appearance.shadowColor = UIColor(palette.hairline)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    enum Destination: Hashable {
        case library, translate, settings
    }
}
