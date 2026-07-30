import SwiftUI

/// Onboarding illustrations. These are not drawings of the app — they are the
/// app's own components rendered small: `GeneratedCover` from the shelf, the
/// translator's free-chapter and language-pair cards, the Translate tab's live
/// job card. Nothing here can drift from the real screens or miss a
/// translation, because it is the same code the real screens run.

/// Shared warm paper backdrop used by every onboarding step.
struct OnboardingPaperBackground: View {
    let palette: BrandPalette

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [palette.background, palette.surface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(palette.accent.opacity(palette.isDark ? 0.08 : 0.06))
                .frame(width: 320, height: 320)
                .blur(radius: 2)
                .offset(x: 180, y: -300)

            Circle()
                .fill(palette.text.opacity(palette.isDark ? 0.04 : 0.025))
                .frame(width: 260, height: 260)
                .offset(x: -180, y: 340)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Beat 1: the shelf

/// The library grid as it looks with a couple of books on it, next to the
/// "Add a book" action that owns the empty shelf. Covers come from
/// `GeneratedCover`, the same renderer `BookCard` uses for EPUBs without art.
struct OnboardingShelfScene: View {
    let palette: BrandPalette

    /// Covers sized to the 2:3 ratio the shelf grid uses, large enough that
    /// the beat carries visual weight rather than floating in whitespace.
    private static let tileWidth: CGFloat = 104
    private static let tileHeight: CGFloat = 156

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            // The first cover is the book beat 3 shows mid-translation, so the
            // three beats read as one story about one book.
            cover(OnboardingSampleJob.book)
            cover(OnboardingSampleJob.companion)
            addTile
        }
        .frame(maxWidth: .infinity)
    }

    private func cover(_ book: OnboardingSampleJob.Book) -> some View {
        Image(book.coverAsset)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: Self.tileWidth, height: Self.tileHeight)
            .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusSmall))
            .overlay(
                RoundedRectangle(cornerRadius: Spacing.radiusSmall)
                    .strokeBorder(.black.opacity(0.08))
            )
            .shadow(color: .black.opacity(0.18), radius: 10, y: 6)
            .accessibilityLabel(Text(verbatim: book.title))
    }

    /// The empty slot the reader is about to fill — drawn as the dashed
    /// placeholder rather than a real cover, so the gesture is unmistakable.
    private var addTile: some View {
        VStack(spacing: Spacing.xs) {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
            // The library's own call to action, verbatim, so the gesture the
            // reader is about to make already has its real name here.
            Text("Add a book")
                .font(.system(size: 11, weight: .semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, Spacing.xxs)
        }
        .foregroundStyle(palette.accent)
        .frame(width: Self.tileWidth, height: Self.tileHeight)
        .background(palette.accentSoft)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusSmall))
        .overlay(
            RoundedRectangle(cornerRadius: Spacing.radiusSmall)
                .strokeBorder(
                    palette.accent.opacity(0.55),
                    style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])
                )
        )
    }
}

// MARK: - Beat 2: the translator sheet

/// One real sentence, twice: the reader's own book on top and the translation
/// under it, with the translate glyph bridging them. A language picker would
/// only say which languages are selected; this says what you get.
struct OnboardingTranslateScene: View {
    let palette: BrandPalette

    @Environment(\.locale) private var locale

    var body: some View {
        ZStack(alignment: .center) {
            VStack(spacing: Spacing.lg) {
                sourceCard
                translatedCard
            }

            Image(systemName: "character.book.closed")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(palette.background)
                .frame(width: 46, height: 46)
                .background(palette.accent, in: Circle())
                .overlay(
                    Circle().strokeBorder(palette.background, lineWidth: 4)
                )
        }
    }

    /// Labels name the *role* first, then the language. The scene is bilingual
    /// on purpose, and without "Original" / "Translation" in front the second
    /// card reads like a string somebody forgot to localize.
    private var sourceCard: some View {
        quoteCard(
            label: roleLabel("Original", languageCode: "en"),
            quote: OnboardingSampleJob.sourceQuote,
            labelColor: palette.secondaryText,
            quoteColor: palette.text,
            fill: palette.surface
        )
    }

    private var translatedCard: some View {
        quoteCard(
            label: roleLabel(
                "Translation", languageCode: OnboardingSampleJob.targetCode
            ),
            quote: OnboardingSampleJob.translatedQuote,
            labelColor: palette.accent,
            quoteColor: palette.text,
            fill: palette.accentSoft
        )
    }

    private func roleLabel(
        _ role: String.LocalizationValue, languageCode: String
    ) -> String {
        let name = OnboardingSampleJob.languageName(languageCode, in: locale)
        return "\(String(localized: role, locale: locale)) · \(name)"
    }

    private func quoteCard(
        label: String,
        quote: String,
        labelColor: Color,
        quoteColor: Color,
        fill: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(label.uppercased())
                .font(Typography.eyebrow)
                .tracking(Typography.eyebrowTracking)
                .foregroundStyle(labelColor)

            // The reader's own serif, so the sample reads like book text
            // rather than interface copy.
            Text(verbatim: quote)
                .font(Typography.body(16))
                .foregroundStyle(quoteColor)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(fill)
        .clipShape(
            RoundedRectangle(cornerRadius: Spacing.radiusCard, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: Spacing.radiusCard, style: .continuous)
                .strokeBorder(palette.hairline, lineWidth: Spacing.hairlineWidth)
        }
    }
}

// MARK: - Beat 3: the job that keeps running

/// The Translate tab's in-progress card. The bar creeps forward on a loop
/// because that is the one thing this step is claiming: work continues.
struct OnboardingWaitingScene: View {
    let palette: BrandPalette
    let isAnimated: Bool

    @Environment(\.locale) private var locale
    @State private var isFull = false

    private static let idleProgress = 0.18
    private static let fullProgress = 0.82

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .top, spacing: Spacing.sm) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(verbatim: OnboardingSampleJob.book.title)
                        .font(Typography.control(17, weight: .semibold))
                        .foregroundStyle(palette.text)

                    Text(
                        OnboardingSampleJob.languageName(
                            OnboardingSampleJob.targetCode, in: locale
                        )
                    )
                    .font(Typography.control(14))
                    .foregroundStyle(palette.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                AppPill(
                    title: String(localized: "Translating"),
                    tone: .info,
                    palette: palette
                )
            }

            AppProgressTrack(
                value: isFull && isAnimated
                    ? Self.fullProgress
                    : Self.idleProgress,
                tone: palette.info,
                palette: palette
            )
        }
        .padding(Spacing.md)
        .background(palette.surface)
        .clipShape(
            RoundedRectangle(cornerRadius: Spacing.radiusGroup, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: Spacing.radiusGroup, style: .continuous)
                .strokeBorder(palette.hairline, lineWidth: Spacing.hairlineWidth)
        }
        .onAppear {
            guard isAnimated else { return }
            withAnimation(
                .easeInOut(duration: 2.4).repeatForever(autoreverses: true)
            ) {
                isFull = true
            }
        }
    }
}

// MARK: - Sample data

/// The one book the mini-renders pretend to be working on. Public-domain
/// titles only, and the target language is read from the shipped quality gate
/// so onboarding can never advertise a language the picker does not offer.
enum OnboardingSampleJob {
    struct Book {
        let title: String
        let author: String
        /// Asset name of the real cover. Both are public-domain scans lifted
        /// straight out of the EPUBs already in `Resources/Fixtures`, so the
        /// shelf shows book jackets rather than generated monograms.
        let coverAsset: String
    }

    static let book = Book(
        title: "Alice's Adventures in Wonderland",
        author: "Lewis Carroll",
        coverAsset: "SampleCoverAlice"
    )
    static let companion = Book(
        title: "A Pál utcai fiúk",
        author: "Molnár Ferenc",
        coverAsset: "SampleCoverPal"
    )

    /// One real sentence and its translation, for the beat that has to show
    /// what a translation actually looks like. Kept in step with
    /// `TranslationTargetLanguage.passed`; revisit if a second language ships.
    static let sourceQuote =
        "Alice was beginning to get very tired of sitting by her sister on the bank."
    static let translatedQuote =
        "Alice már elunta, hogy tétlenül üldögéljen nénje mellett a parton."

    static var targetCode: String {
        TranslationTargetLanguage.passed.first?.rawValue ?? "hu"
    }

    /// Same resolution the translator sheet uses, so "Hungarian" reads as
    /// "Magyar" once the app is in Hungarian.
    static func languageName(_ code: String, in locale: Locale) -> String {
        (locale.localizedString(forLanguageCode: code) ?? code).capitalized
    }
}

// MARK: - Shared card treatment

/// The surface + hairline the translator's cards use, so the mini-renders sit
/// on exactly the same material as the real ones.
private struct OnboardingCard: ViewModifier {
    let palette: BrandPalette

    func body(content: Content) -> some View {
        content
            .background(palette.surface)
            .clipShape(
                RoundedRectangle(cornerRadius: Spacing.radiusCard, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: Spacing.radiusCard, style: .continuous)
                    .strokeBorder(palette.hairline, lineWidth: Spacing.hairlineWidth)
            }
    }
}
