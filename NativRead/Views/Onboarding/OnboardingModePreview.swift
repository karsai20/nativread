import SwiftUI

/// A sample page the reader can actually try during onboarding, so a reading
/// mode is picked by feeling it rather than by reading a label.
///
/// Every mode is the reader's own, not an impression of it: the curl runs the
/// reader's WebGL fragment shader ported to Metal (`PageCurl.metal`), the
/// slide runs the spring `ReaderController` gives the native scroll, the
/// gesture uses the reader's activation and commit distances, and scroll is a
/// genuine scroll view. UIKit's `.pageCurl` was tried first and rejected: it
/// renders the underside of a turning page as a white flare, which the
/// reader's shader explicitly avoids.
struct OnboardingModePreview: View {
    let mode: WelcomeReadingMode
    let palette: BrandPalette

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page = 0
    /// Live horizontal travel of the top page. Negative is a forward turn.
    @State private var drag: CGFloat = 0
    /// Measured, because a turn travels exactly one card.
    @State private var cardWidth: CGFloat = 320

    /// Public-domain passages, long enough to read as a real page. Localizable
    /// so a translated build can show a passage its readers actually read.
    private static let passages: [LocalizedStringKey] = [
        "Alice was beginning to get very tired of sitting by her sister on the bank, and of having nothing to do: once or twice she had peeped into the book her sister was reading, but it had no pictures or conversations in it, and what is the use of a book, thought Alice, without pictures or conversations? So she was considering, as well as she could, whether the pleasure of making a daisy-chain would be worth the trouble of getting up and picking the daisies.",
        "There was nothing so very remarkable in that; nor did Alice think it so very much out of the way to hear the Rabbit say to itself, Oh dear! Oh dear! I shall be late! But when the Rabbit actually took a watch out of its waistcoat-pocket, and looked at it, and then hurried on, Alice started to her feet, for it flashed across her mind that she had never before seen a rabbit with either a waistcoat-pocket, or a watch to take out of it.",
        "In another moment down went Alice after it, never once considering how in the world she was to get out again. The rabbit-hole went straight on like a tunnel for some way, and then dipped suddenly down, so suddenly that Alice had not a moment to think about stopping herself before she found herself falling down what seemed to be a very deep well."
    ]

    /// Tall enough to read as a page, capped so an iPad does not turn the
    /// step into one giant card.
    private static let pageHeight: CGFloat = 348
    private static let maximumWidth: CGFloat = 460

    // The reader's own swipe (`ReaderScripts`): a drag has to be
    // horizontal-dominant and clear 15pt before the page moves, and 70pt
    // before it turns. Anything less springs back.
    private static let activation: CGFloat = 15
    private static let commitDistance: CGFloat = 70

    var body: some View {
        Group {
            switch mode {
            case .scroll: scrollBody
            case .slide, .curl: pagedBody
            }
        }
        .frame(
            maxWidth: .infinity,
            minHeight: Self.pageHeight,
            maxHeight: Self.pageHeight,
            alignment: .topLeading
        )
        .padding(Spacing.md)
        .frame(maxWidth: Self.maximumWidth)
        .background(palette.surface)
        .clipShape(
            RoundedRectangle(cornerRadius: Spacing.radiusCard, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: Spacing.radiusCard, style: .continuous)
                .strokeBorder(palette.hairline)
        }
        .shadow(color: .black.opacity(0.12), radius: 14, y: 8)
        // Switching mode must not also advance the book: losing your place is
        // not a demonstration.
        .onChange(of: mode) { _, _ in drag = 0 }
        .accessibilityIdentifier("welcome.mode.preview")
    }

    // MARK: - Paged

    /// The arriving page sits underneath; the leaving page moves on top of it.
    /// Getting that order wrong hid the curl entirely — the new page simply
    /// covered the one that was supposed to be lifting away.
    private var pagedBody: some View {
        ZStack(alignment: .topLeading) {
            pageBody(at: restingIndex)
                .zIndex(0)

            pageBody(at: movingIndex)
                .modifier(
                    PageTurnEffect(
                        mode: mode,
                        offset: drag - (isBackward ? exitTravel : 0),
                        progress: turnProgress,
                        paper: palette.surface,
                        width: cardWidth,
                        reduceMotion: reduceMotion
                    )
                )
                .zIndex(1)
        }
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear { cardWidth = proxy.size.width }
                    .onChange(of: proxy.size.width) { _, new in cardWidth = new }
            }
        }
        .contentShape(Rectangle())
        .gesture(turnGesture)
        .onTapGesture(perform: turn)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sample page")
        .accessibilityHint("Double tap to turn the page")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: Text("Turn page"), turn)
        // The page is its own accessibility element, so the identifier has to
        // sit on it: the container above is no longer one to attach to.
        .accessibilityIdentifier("welcome.mode.preview")
    }

    private var nextPage: Int { (page + 1) % Self.passages.count }
    private var previousPage: Int {
        (page - 1 + Self.passages.count) % Self.passages.count
    }

    /// Dragging right walks back through the book.
    private var isBackward: Bool { drag > 0 }

    /// Forward, the current page lifts away and uncovers the next one.
    /// Backward, the previous page is the one that moves: it starts fully
    /// turned, off past the spine, and unfurls back down onto this one.
    private var movingIndex: Int { isBackward ? previousPage : page }
    private var restingIndex: Int { isBackward ? page : nextPage }

    /// The page is measured inside the card's padding, so clearing the card
    /// takes that padding too. Sliding exactly one page width left a 16pt
    /// sliver inside the clip, which vanished when the pages swapped.
    private var exitTravel: CGFloat { cardWidth + Spacing.md * 2 }

    /// How far through the turn the moving page is, 0 flat…1 fully away,
    /// measured against the distance it travels so the motion fills the
    /// animation.
    private var turnProgress: Double {
        let travelled = Double(abs(drag)) / Double(max(cardWidth, 1))
        return isBackward ? max(1 - travelled, 0) : min(travelled, 1)
    }

    private var turnGesture: some Gesture {
        DragGesture(minimumDistance: Self.activation)
            .onChanged { value in
                // A vertical drag belongs to the screen behind the card, not
                // to a page turn — otherwise brushing the card jumps a page.
                guard abs(value.translation.width)
                    > abs(value.translation.height) else { return }
                drag = value.translation.width
            }
            .onEnded { _ in
                guard abs(drag) >= Self.commitDistance else {
                    return springBack()
                }
                commitDrag()
            }
    }

    // MARK: - Timing, copied from the reader

    /// The reader's ease, `t < 0.5 ? 2t² : 1 - 2(1-t)²` (`ReaderScripts`), as
    /// its cubic-bezier equivalent.
    private static func readerEase(_ duration: Double) -> Animation {
        .timingCurve(0.45, 0, 0.55, 1, duration: duration)
    }

    /// A completed turn. Curl runs the WebGL sheet's 440ms ease; slide runs the
    /// critically damped spring `ReaderController` gives the native scroll
    /// (0.42s, damping 1.0, initial velocity 0.6 — leaves fast, settles soft).
    private var turnAnimation: Animation? {
        guard !reduceMotion else { return nil }
        switch mode {
        case .curl:
            return Self.readerEase(0.44)
        case .slide, .scroll:
            return .interpolatingSpring(
                duration: 0.42, bounce: 0, initialVelocity: 0.6
            )
        }
    }

    /// Releasing part-way. The reader scales the settle by the travel left,
    /// with an 80ms floor, so a nearly finished drag snaps shut and a barely
    /// started one eases back.
    private func settleAnimation(remaining: Double) -> Animation? {
        guard !reduceMotion else { return nil }
        return Self.readerEase(max(0.08, 0.36 * remaining))
    }

    /// Abandoning a drag returns the moving page where it came from: flat for
    /// a forward turn, back off past the spine for a backward one.
    private func springBack() {
        let remaining = isBackward ? 1 - turnProgress : turnProgress
        withAnimation(settleAnimation(remaining: remaining)) { drag = 0 }
    }

    /// Carries the page all the way out, then swaps. Swapping first would show
    /// the new text leaving instead of the old one.
    private func turn() {
        withAnimation(turnAnimation) {
            drag = -exitTravel
        } completion: {
            page = nextPage
            drag = 0
        }
    }

    private func commitDrag() {
        let backward = isBackward
        let landing = backward ? previousPage : nextPage
        let remaining = backward ? turnProgress : 1 - turnProgress
        withAnimation(settleAnimation(remaining: remaining)) {
            drag = backward ? exitTravel : -exitTravel
        } completion: {
            page = landing
            drag = 0
        }
    }

    private func pageBody(at index: Int) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(Self.passages[index])
                .font(Typography.body(17))
                .lineSpacing(6)
                .foregroundStyle(palette.text)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            HStack {
                Text("Swipe or tap to turn")
                Spacer()
                Text(verbatim: "\(index + 1) / \(Self.passages.count)")
            }
            .font(Typography.meta(12))
            .foregroundStyle(palette.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(palette.surface)
    }

    // MARK: - Scroll

    private var scrollBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                ForEach(Array(Self.passages.enumerated()), id: \.offset) { _, passage in
                    Text(passage)
                        .font(Typography.body(17))
                        .lineSpacing(6)
                        .foregroundStyle(palette.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.visible)
    }
}

/// The leaving page moving the way its mode says it should. Not `Animatable`:
/// its inputs are already interpolated state, and animating both layers made
/// the page lag behind the finger.
private struct PageTurnEffect: ViewModifier {
    let mode: WelcomeReadingMode
    let offset: CGFloat
    let progress: Double
    let paper: Color
    let width: CGFloat
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        if reduceMotion {
            // No travel at all: the page crossfades in place.
            content.opacity(1 - progress)
        } else {
            switch mode {
            case .curl:
                content.layerEffect(
                    ShaderLibrary.pageCurl(
                        .float(Float(width)),
                        .float(Float(progress)),
                        .color(paper)
                    ),
                    // The flap samples across the whole sheet, so the effect
                    // must be allowed to read that far from each pixel.
                    maxSampleOffset: CGSize(width: width * 2, height: 0)
                )
            case .slide, .scroll:
                content.offset(x: offset)
            }
        }
    }
}
