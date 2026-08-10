import SwiftUI

/// Welcome-screen art. Not a drawing of the app — the shelf scene renders the
/// app's own cover treatment small, so it cannot drift from the real screens.

/// Shared warm paper backdrop behind the welcome screen.
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

// MARK: - The shelf

/// A shelf that never ends: two rows of covers drifting in opposite
/// directions, fading out at both edges. It shows what the app is for — books
/// in languages you do and do not read — without putting anything tappable on
/// a screen whose only action is Continue. An earlier version drew the
/// library's real "Add a book" tile here; testers tried to press it.
struct OnboardingShelfScene: View {
    let palette: BrandPalette

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: Spacing.sm) {
            DriftingShelfRow(
                books: OnboardingSampleJob.topRow,
                reversed: false,
                reduceMotion: reduceMotion
            )
            DriftingShelfRow(
                books: OnboardingSampleJob.bottomRow,
                reversed: true,
                reduceMotion: reduceMotion
            )
        }
        .frame(maxWidth: .infinity)
        // Fading the ends is what makes the rows read as a shelf running past
        // the screen rather than a strip that was cut off.
        .mask {
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.10),
                    .init(color: .black, location: 0.90),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
}

/// One row of covers, looping seamlessly. The row holds two copies of its
/// books and travels exactly one copy's width, so the moment the animation
/// repeats the second copy is standing where the first began.
private struct DriftingShelfRow: View {
    let books: [OnboardingSampleJob.Book]
    /// Drifts right instead of left, so the two rows move against each other.
    let reversed: Bool
    let reduceMotion: Bool

    @State private var travelled = false

    private static let coverWidth: CGFloat = 76
    private static let spacing = Spacing.sm
    /// Slow enough to read as ambient rather than as something to look at.
    private static let secondsPerCover: Double = 4.5

    private var cycle: CGFloat {
        CGFloat(books.count) * (Self.coverWidth + Self.spacing)
    }

    private var offset: CGFloat {
        let progress = travelled ? cycle : 0
        return reversed ? progress - cycle : -progress
    }

    var body: some View {
        // The row is an overlay on an empty box of the right height, so its
        // full natural width — eight covers, far wider than the screen — never
        // reaches the layout. Sizing the parent off it instead pushed the
        // headline and value line off the right edge.
        Color.clear
            .frame(height: Self.coverWidth * 1.5)
            .overlay(alignment: .leading) {
                HStack(spacing: Self.spacing) {
                    // Two passes: the row must never run out of covers mid-loop.
                    ForEach(0 ..< 2, id: \.self) { copy in
                        ForEach(Array(books.enumerated()), id: \.offset) { index, book in
                            cover(book).id("\(copy)-\(index)")
                        }
                    }
                }
                .fixedSize()
                .offset(x: offset)
            }
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(
                    .linear(duration: Double(books.count) * Self.secondsPerCover)
                        .repeatForever(autoreverses: false)
                ) {
                    travelled = true
                }
            }
    }

    private func cover(_ book: OnboardingSampleJob.Book) -> some View {
        Group {
            if let asset = book.coverAsset {
                Image(asset)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                // The shelf's own generated cover, so a scene book and a real
                // book without artwork are drawn by the same code.
                GeneratedCover(title: book.title, author: book.author)
            }
        }
        .frame(width: Self.coverWidth, height: Self.coverWidth * 1.5)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusSmall))
        .overlay(
            RoundedRectangle(cornerRadius: Spacing.radiusSmall)
                .strokeBorder(.black.opacity(0.08))
        )
        .shadow(color: .black.opacity(0.18), radius: 8, y: 5)
    }
}

// MARK: - Sample data

/// The shelf's books. Public domain only, and deliberately mixed: titles the
/// Hungarian reader can read sit beside ones they cannot, which is the whole
/// reason the app exists. The two with real jackets are lifted straight out of
/// the EPUBs in `Resources/Fixtures`; the rest use the app's generated cover.
enum OnboardingSampleJob {
    struct Book {
        let title: String
        let author: String
        /// `nil` falls back to `GeneratedCover`.
        let coverAsset: String?
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

    static let topRow: [Book] = [
        book,
        Book(title: "Pride and Prejudice", author: "Jane Austen", coverAsset: nil),
        Book(title: "Egri csillagok", author: "Gárdonyi Géza", coverAsset: nil),
        Book(title: "Moby-Dick", author: "Herman Melville", coverAsset: nil)
    ]

    static let bottomRow: [Book] = [
        companion,
        Book(title: "Great Expectations", author: "Charles Dickens", coverAsset: nil),
        Book(title: "Az arany ember", author: "Jókai Mór", coverAsset: nil),
        Book(title: "Robinson Crusoe", author: "Daniel Defoe", coverAsset: nil)
    ]
}
