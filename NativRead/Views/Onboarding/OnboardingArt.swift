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

/// The library grid as it looks with a couple of books on it, next to the
/// "Add a book" action that owns the empty shelf.
struct OnboardingShelfScene: View {
    let palette: BrandPalette

    /// Covers sized to the 2:3 ratio the shelf grid uses, large enough that
    /// the beat carries visual weight rather than floating in whitespace.
    private static let tileWidth: CGFloat = 104
    private static let tileHeight: CGFloat = 156

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
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

// MARK: - Sample data

/// The two covers on the welcome shelf. Public-domain titles only; both are
/// real jackets lifted straight out of the EPUBs in `Resources/Fixtures`.
enum OnboardingSampleJob {
    struct Book {
        let title: String
        let author: String
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
}
