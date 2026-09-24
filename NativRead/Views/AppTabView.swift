import SwiftUI

/// The app shell: three destinations that stay put while readers move between
/// them — the shelf, the translation workspace, and preferences. Readers open
/// as full-screen covers above this shell, so a book never loses the tab bar's
/// place underneath it.
///
/// All three destinations stay mounted, as UIKit's tab controller kept them,
/// so scroll positions and pushed screens survive a switch. The switch itself
/// is a short crossfade with a nudge in the direction of the tab order — the
/// page you leave slips a little toward its own tab, the one arriving comes
/// in from its side — so the bar and the content agree on where things are.
struct AppTabView: View {
    /// Owned by `RootView` so finishing the welcome can land on the shelf its
    /// last button promises, whichever tab the reader started from.
    @Binding var selection: Destination

    @Environment(LocalizationStore.self) private var localizationStore
    @Environment(TranslationStore.self) private var translationStore
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The translate stage sits above the whole shell, tab bar included, and
    /// its cover lifts from whichever shelf the reader tapped.
    @State private var translationPresenter = TranslationPresenter()

    private var palette: BrandPalette {
        BrandPalette.resolve(systemDark: colorScheme == .dark)
    }

    /// How far a page sits off-centre while it is not the selection.
    private static let restingNudge: CGFloat = 12

    var body: some View {
        ZStack {
            destination(.library) {
                LibraryView()
            }
            destination(.translate) {
                TranslateHomeView()
            }
            destination(.settings) {
                SettingsView()
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            AppTabBar(items: Self.items, selection: $selection, palette: palette)
        }
        .background(palette.background.ignoresSafeArea())
        .environment(translationPresenter)
        .translationStage(presenter: translationPresenter)
    }

    private func destination<Content: View>(
        _ tab: Destination, @ViewBuilder content: () -> Content
    ) -> some View {
        let isSelected = tab == selection
        let side = CGFloat((tab.order - selection.order).signum())
        return content()
            .id(localizationStore.appLanguage)
            .opacity(isSelected ? 1 : 0)
            .offset(x: reduceMotion ? 0 : side * Self.restingNudge)
            .zIndex(isSelected ? 1 : 0)
            .allowsHitTesting(isSelected)
            .accessibilityHidden(!isSelected)
    }

    private static let items: [AppTabBar<Destination>.Item] = [
        .init(tab: .library, title: "Library",
              icon: .libraryBig, identifier: "tab.library"),
        .init(tab: .translate, title: "Translate",
              icon: .languages, identifier: "tab.translate"),
        .init(tab: .settings, title: "Settings",
              icon: .settings2, identifier: "tab.settings"),
    ]

    enum Destination: Hashable, CaseIterable {
        case library, translate, settings

        /// Left-to-right position in the bar; the switch nudges pages
        /// toward their own tab.
        var order: Int {
            switch self {
            case .library: return 0
            case .translate: return 1
            case .settings: return 2
            }
        }
    }
}
