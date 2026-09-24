import SwiftUI

/// The passage the welcome translates on screen. Alice is public domain in
/// every language the app ships, and these sentences are lifted from the
/// EPUBs in `Resources/Fixtures` — the demo shows text the reader can go and
/// produce for themselves, not marketing copy.
///
/// The source is always a language the reader cannot read: English for
/// everyone, and Hungarian for the English reader.
struct OnboardingDemoPassage: Equatable {
    struct Line: Equatable {
        let source: String
        let target: String
    }

    /// Language names in their own script, as the picker shows them.
    let sourceEndonym: String
    let targetEndonym: String
    let chapter: Line
    let lines: [Line]

    /// The chapter heading translates first, then each sentence in turn.
    var stageCount: Int { lines.count + 1 }

    static func alice(readIn language: AppLanguage) -> OnboardingDemoPassage {
        // The English reader gets the mirror image: Hungarian in, English out.
        // Everyone else reads English out of the way.
        let readsEnglish = language == .en || language == .system
        let from = readsEnglish ? Text.hungarian : Text.english
        let to = Text.of(language)
        return OnboardingDemoPassage(
            sourceEndonym: (readsEnglish ? AppLanguage.hu : .en).endonym,
            targetEndonym: (readsEnglish ? AppLanguage.en : language).endonym,
            chapter: Line(source: from.chapter, target: to.chapter),
            lines: zip(from.sentences, to.sentences).map(Line.init)
        )
    }

    /// One language's copy of the passage.
    private struct Text {
        let chapter: String
        let sentences: [String]

        static func of(_ language: AppLanguage) -> Text {
            switch language {
            case .hu: return hungarian
            case .de: return german
            case .es: return spanish
            case .en, .system: return english
            }
        }

        static let english = Text(
            chapter: "Down the Rabbit-Hole",
            sentences: [
                "Alice was beginning to get very tired of sitting by her sister on the bank, and of having nothing to do.",
                "Once or twice she had peeped into the book her sister was reading, but it had no pictures or conversations in it.",
                "Suddenly a White Rabbit with pink eyes ran close by her."
            ]
        )

        static let hungarian = Text(
            chapter: "Le a nyúlüregbe",
            sentences: [
                "Alice már nagyon unta, hogy a parton üljön a nővére mellett, és semmi dolga se legyen.",
                "Egyszer-kétszer belenézett a könyvbe, amelyet a nővére olvasott, de abban nem voltak se képek, se beszélgetések.",
                "Hirtelen egy fehér nyúl szaladt el mellette, rózsaszín szemekkel."
            ]
        )

        static let german = Text(
            chapter: "Hinab in den Kaninchenbau",
            sentences: [
                "Alice wurde es allmählich sehr langweilig, neben ihrer Schwester am Ufer zu sitzen und nichts zu tun zu haben.",
                "Ein- oder zweimal hatte sie in das Buch geschaut, das ihre Schwester las, aber es enthielt weder Bilder noch Gespräche.",
                "Da lief plötzlich ein weißes Kaninchen mit rosa Augen dicht an ihr vorbei."
            ]
        )

        static let spanish = Text(
            chapter: "Por la madriguera del conejo",
            sentences: [
                "A Alicia empezaba a cansarse mucho de estar sentada junto a su hermana en la orilla, sin nada que hacer.",
                "Una o dos veces se había asomado al libro que leía su hermana, pero no tenía ilustraciones ni diálogos.",
                "De pronto pasó corriendo cerca de ella un Conejo Blanco de ojos rosados."
            ]
        )
    }
}

/// Step two of the welcome: the reason the app exists, shown rather than
/// claimed. A page the reader cannot read rewrites itself into their own
/// language, one sentence at a time, and the page is a page — same paper,
/// same serif, same measure as the reader.
struct OnboardingTranslationDemo: View {
    let passage: OnboardingDemoPassage
    let palette: BrandPalette

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var stage = 0

    /// Wide enough to read as a page, capped so an iPad does not turn the
    /// step into one giant card.
    private static let maximumWidth: CGFloat = 460
    private static let firstDelay: Double = 0.55
    private static let stageDelay: Double = 0.75

    private var isFinished: Bool { stage >= passage.stageCount }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            page
            languageRow
        }
        .frame(maxWidth: Self.maximumWidth)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier("welcome.translation.demo")
        .onAppear(perform: run)
    }

    // MARK: - The page

    private var page: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            crossfade(passage.chapter, at: 0)
                .font(Typography.title(19))
                .foregroundStyle(palette.text)

            ForEach(Array(passage.lines.enumerated()), id: \.offset) { index, line in
                crossfade(line, at: index + 1)
                    .font(Typography.body(15))
                    .foregroundStyle(palette.text.opacity(0.86))
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surface)
        .clipShape(
            RoundedRectangle(cornerRadius: Spacing.radiusCard, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: Spacing.radiusCard, style: .continuous)
                .strokeBorder(palette.hairline)
        }
        .shadow(color: .black.opacity(0.12), radius: 14, y: 8)
        // A demo that finished before you looked up is no demo.
        .contentShape(Rectangle())
        .onTapGesture(perform: run)
    }

    /// Both languages occupy the same slot, so the `ZStack` reserves the
    /// taller of the two and the page never reflows mid-sentence — the whole
    /// point is that the words change and the book does not.
    private func crossfade(
        _ line: OnboardingDemoPassage.Line, at index: Int
    ) -> some View {
        let isTranslated = stage > index
        return ZStack(alignment: .topLeading) {
            Text(verbatim: line.source)
                .opacity(isTranslated ? 0 : 1)
            Text(verbatim: line.target)
                .opacity(isTranslated ? 1 : 0)
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Which language, into which

    private var languageRow: some View {
        HStack(spacing: Spacing.xs) {
            chip(passage.sourceEndonym, isActive: false)

            Icon(.arrowRight, size: 13)
                .foregroundStyle(palette.secondaryText)

            chip(passage.targetEndonym, isActive: isFinished)
        }
        .animation(.easeInOut(duration: 0.3), value: isFinished)
    }

    private func chip(_ name: String, isActive: Bool) -> some View {
        Text(verbatim: name)
            .font(Typography.control(13, weight: .semibold))
            .foregroundStyle(isActive ? palette.background : palette.secondaryText)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xxs)
            .background(isActive ? palette.accent : palette.surface)
            .clipShape(Capsule())
            .overlay {
                Capsule().strokeBorder(
                    isActive ? palette.accent : palette.hairline,
                    lineWidth: Spacing.hairlineWidth
                )
            }
    }

    // MARK: - Playback

    private func run() {
        guard !reduceMotion else {
            stage = passage.stageCount
            return
        }
        stage = 0
        for step in 1...passage.stageCount {
            withAnimation(
                .easeInOut(duration: 0.45)
                    .delay(Self.firstDelay + Double(step - 1) * Self.stageDelay)
            ) {
                stage = step
            }
        }
    }

    /// VoiceOver gets the finished page, not the animation: the source text
    /// is exactly what the reader cannot read.
    private var accessibilityLabel: String {
        ([passage.chapter.target] + passage.lines.map(\.target))
            .joined(separator: " ")
    }
}
