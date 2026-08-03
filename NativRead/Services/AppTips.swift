import SwiftUI
import TipKit

/// The three onboarding beats, relocated from the old walkthrough into the
/// screens they describe. TipKit owns display order, one-time persistence,
/// and dismissal; the app only reports state through the parameters below.
enum AppTips {
    /// Welcome finished (or was already seen on a previous launch). Keeps
    /// tips from popping underneath the welcome overlay.
    @Parameter static var hasCompletedOnboarding: Bool = false

    /// The shelf has at least one book of any kind.
    @Parameter static var hasBooks: Bool = false

    /// The shelf has at least one book that can be sent to the translator.
    @Parameter static var hasTranslatableBook: Bool = false

    /// Call once at launch. UI-test runs hide tips unless a test opts in
    /// with `-enableTips`, so popovers cannot swallow taps meant for the
    /// views underneath them.
    static func configure(arguments: [String] = ProcessInfo.processInfo.arguments) {
        if arguments.contains("-enableTips") {
            try? Tips.resetDatastore()
        } else if arguments.contains("-skipOnboarding")
            || arguments.contains("-forceOnboarding") {
            Tips.hideAllTipsForTesting()
        }
        try? Tips.configure()
    }

    /// Beat 1: anchored to the library's import button.
    struct AddBook: Tip {
        var title: Text {
            Text("Add a book in a language you don't read.", comment: "Tip on the library import button")
        }

        var rules: [Rule] {
            #Rule(AppTips.$hasCompletedOnboarding) { $0 == true }
            #Rule(AppTips.$hasBooks) { $0 == false }
        }
    }

    /// Beat 2: anchored to the first translatable book card on the shelf.
    struct TranslateBook: Tip {
        var title: Text {
            Text("Hold a book to translate it.", comment: "Tip on a library book card")
        }

        var message: Text? {
            Text("The first chapter is free.", comment: "Tip on a library book card, second line")
        }

        var rules: [Rule] {
            #Rule(AppTips.$hasCompletedOnboarding) { $0 == true }
            #Rule(AppTips.$hasTranslatableBook) { $0 == true }
        }
    }

    /// Beat 3: anchored to the translation progress card once a job runs.
    struct BackgroundTranslation: Tip {
        var title: Text {
            Text("You can close the app.", comment: "Tip on the translation progress card")
        }

        var message: Text? {
            Text("We keep translating in the background and add the result to your shelf.", comment: "Tip on the translation progress card, second line")
        }
    }

    static let addBook = AddBook()
    static let translateBook = TranslateBook()
    static let backgroundTranslation = BackgroundTranslation()
}

/// The shared editorial look for every tip popover.
struct AppTipStyle: TipViewStyle {
    let palette: BrandPalette

    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                configuration.title
                    .font(Typography.control(16, weight: .semibold))
                    .foregroundStyle(palette.text)

                configuration.message
                    .font(Typography.meta())
                    .foregroundStyle(palette.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                configuration.tip.invalidate(reason: .tipClosed)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.tertiaryText)
                    .frame(width: 28, height: 28)
            }
            .accessibilityLabel("Dismiss tip")
        }
        .padding(Spacing.md)
    }
}
