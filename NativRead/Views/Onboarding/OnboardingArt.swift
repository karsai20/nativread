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
/// directions, fading out at both edges. It shows what the app is for —
/// books the reader already loves, in their own language — without putting
/// anything tappable on a screen whose only action is Continue. An earlier
/// version drew the library's real "Add a book" tile here; testers tried to
/// press it.
struct OnboardingShelfScene: View {
    let books: OnboardingShelf.Rows
    let palette: BrandPalette

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: Spacing.sm) {
            DriftingShelfRow(
                covers: books.top,
                reversed: false,
                reduceMotion: reduceMotion
            )
            DriftingShelfRow(
                covers: books.bottom,
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

/// One row of covers, looping seamlessly. The row travels exactly one loop's
/// width and holds two loops, so the moment the animation repeats the second
/// loop is standing where the first began.
///
/// A loop is the book list repeated as many times as it takes to be at least
/// as wide as the row itself. Two copies of a short list is not enough: the
/// travel would end with the row's tail short of its right edge, and a shelf
/// with six books — or an iPad — would show the gap.
private struct DriftingShelfRow: View {
    /// Asset-catalog names, in shelf order.
    let covers: [String]
    /// Drifts right instead of left, so the two rows move against each other.
    let reversed: Bool
    let reduceMotion: Bool

    @State private var travelled = false

    private static let coverWidth: CGFloat = 76
    private static let spacing = Spacing.sm
    private static let pitch = coverWidth + spacing
    /// Slow enough to read as ambient rather than as something to look at.
    private static let secondsPerCover: Double = 4.5

    private func loops(toFill width: CGFloat) -> Int {
        let listWidth = CGFloat(covers.count) * Self.pitch
        guard listWidth > 0 else { return 1 }
        return max(1, Int((width / listWidth).rounded(.up)))
    }

    private func offset(cycle: CGFloat) -> CGFloat {
        let progress = travelled ? cycle : 0
        return reversed ? progress - cycle : -progress
    }

    var body: some View {
        // The row is an overlay on an empty box of the right height, so its
        // full natural width — many covers, far wider than the screen — never
        // reaches the layout. Sizing the parent off it instead pushed the
        // headline and value line off the right edge.
        GeometryReader { proxy in
            let loops = loops(toFill: proxy.size.width)
            let perLoop = loops * covers.count
            let cycle = CGFloat(perLoop) * Self.pitch

            Color.clear
                .overlay(alignment: .leading) {
                    HStack(spacing: Self.spacing) {
                        // Two loops: the row must never run out of covers
                        // mid-travel.
                        ForEach(0 ..< (loops * 2), id: \.self) { copy in
                            ForEach(Array(covers.enumerated()), id: \.offset) { index, name in
                                cover(name).id("\(copy)-\(index)")
                            }
                        }
                    }
                    .fixedSize()
                    .offset(x: offset(cycle: cycle))
                }
                .onAppear {
                    guard !reduceMotion else { return }
                    // Duration scales with the loop so every shelf drifts at
                    // the same speed, however many books it holds.
                    withAnimation(
                        .linear(duration: Double(perLoop) * Self.secondsPerCover)
                            .repeatForever(autoreverses: false)
                    ) {
                        travelled = true
                    }
                }
        }
        .frame(height: Self.coverWidth * 1.5)
    }

    private func cover(_ name: String) -> some View {
        Image(name)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: Self.coverWidth, height: Self.coverWidth * 1.5)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusSmall))
        // Antiquarian jackets are often near-white; without a firmer edge the
        // pale ones dissolve into the welcome's paper background.
        .overlay(
            RoundedRectangle(cornerRadius: Spacing.radiusSmall)
                .strokeBorder(.black.opacity(0.16))
        )
        .shadow(color: .black.opacity(0.18), radius: 8, y: 5)
    }
}

// MARK: - Sample data

/// The shelf's books: real jackets of real editions, all public domain, and
/// all in the reader's own language. A Hungarian reader opening the app for
/// the first time should recognise the shelf as *their* shelf — an English
/// row of classics they may not read says the wrong thing on the screen that
/// promises "your language".
///
/// Cover art lives in the asset catalog as `Cover-<language>-<slug>`;
/// provenance and licences are recorded in `docs/COVERS.md`. Every name
/// listed here is checked against the catalog by
/// `OnboardingShelfTests.testEveryCoverResolves`.
enum OnboardingShelf {
    struct Rows {
        let top: [String]
        let bottom: [String]
    }

    /// Falls back to the English shelf for any language without covers of
    /// its own, which is also what the string catalog does.
    static func rows(for language: AppLanguage) -> Rows {
        switch language {
        case .hu: return hungarian
        case .de: return german
        case .es: return spanish
        case .en, .system: return english
        }
    }

    static let english = Rows(
        top: ["alice", "pride", "mobydick", "frankenstein"].map { "Cover-en-\($0)" },
        bottom: ["expectations", "dracula", "doriangray", "janeeyre"].map { "Cover-en-\($0)" }
    )

    static let hungarian = Rows(
        top: ["egricsillagok", "palutcaifiuk", "aranyember", "szentpeteresernyoje"]
            .map { "Cover-hu-\($0)" },
        bottom: ["koszivuemberfiai", "legyjomindhalalig", "toldiesteje", "embertragediaja"]
            .map { "Cover-hu-\($0)" }
    )

    static let german = Rows(
        top: ["prozess", "effibriest", "faust", "werther"].map { "Cover-de-\($0)" },
        bottom: ["zarathustra", "buddenbrooks", "undine", "kinderhausmarchen"]
            .map { "Cover-de-\($0)" }
    )

    /// Six books, both rows, in opposite orders — Commons has fewer usable
    /// Spanish first-edition jackets than Hungarian or German ones. Splitting
    /// them three and three was tried first and looked broken: three covers
    /// are narrower than the screen, so each row repeated itself in plain
    /// sight. Two rows drifting against each other hide the overlap.
    static let spanish: Rows = {
        let slugs = [
            "quijote", "regenta", "niebla", "lazarillo", "sombrero", "madrenaturaleza"
        ].map { "Cover-es-\($0)" }
        // Rotated, not reversed: mirrored rows drifting against each other
        // keep meeting the same pair face to face.
        return Rows(top: slugs, bottom: Array(slugs[3...] + slugs[..<3]))
    }()
}
