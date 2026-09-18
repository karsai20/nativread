import SwiftUI

/// The translate flow is not a screen you navigate to: the cover the reader
/// tapped lifts off the shelf, the shelf dims and recedes, and a material
/// flap rises from the bottom edge under the cover. Spatial consistency —
/// it came from the shelf, it goes back to the shelf; the flap leaves the
/// way it came. The flap is fixed: close is the X or the scrim.
///
/// Hosts apply `.translationStage(book:namespace:)`; covers on the shelf
/// apply `.translationHero(for:in:activeBookID:)` so the lift is a matched
/// geometry move, not a cross-fade.
struct TranslationStageModifier: ViewModifier {
    let presenter: TranslationPresenter
    let namespace: Namespace.ID

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static var liftAnimation: Animation { .spring(response: 0.45, dampingFraction: 1) }

    func body(content: Content) -> some View {
        let isActive = presenter.book != nil
        ZStack {
            content
                .scaleEffect(isActive && !reduceMotion ? 0.94 : 1)
                .blur(radius: isActive && !reduceMotion ? 6 : 0)
                .allowsHitTesting(!isActive)
                .accessibilityHidden(isActive)

            if let active = presenter.book {
                TranslationStage(
                    book: active,
                    heroID: TranslationPresenter.heroID(for: active, host: presenter.host),
                    namespace: namespace,
                    onClose: { withAnimation(Self.liftAnimation) { presenter.dismiss() } }
                )
                .zIndex(1)
            }
        }
        .animation(reduceMotion ? .easeOut(duration: 0.2) : Self.liftAnimation, value: isActive)
    }
}

private struct TranslationHeroNamespaceKey: EnvironmentKey {
    static let defaultValue: Namespace.ID? = nil
}

extension EnvironmentValues {
    /// The shell's matched-geometry namespace for translate covers, or nil
    /// where no stage is hosted (previews, tests of a bare shelf).
    var translationHeroNamespace: Namespace.ID? {
        get { self[TranslationHeroNamespaceKey.self] }
        set { self[TranslationHeroNamespaceKey.self] = newValue }
    }
}

extension View {
    func translationStage(presenter: TranslationPresenter, namespace: Namespace.ID) -> some View {
        modifier(TranslationStageModifier(presenter: presenter, namespace: namespace))
    }

    /// Marks a shelf cover as the place the translate cover lifts from and
    /// returns to. Hidden while its book is on stage — the stage draws it.
    func translationHero(
        for book: Book, host: TranslationPresenter.Host,
        in namespace: Namespace.ID, presenter: TranslationPresenter
    ) -> some View {
        let isOnStage = presenter.book?.id == book.id && presenter.host == host
        return self
            .matchedGeometryEffect(
                id: TranslationPresenter.heroID(for: book, host: host),
                in: namespace, isSource: !isOnStage
            )
            .opacity(isOnStage ? 0 : 1)
    }
}

/// Scrim, the lifted cover, the close button and the flap.
struct TranslationStage: View {
    let book: Book
    let heroID: String
    let namespace: Namespace.ID
    let onClose: () -> Void

    @Environment(LibraryStore.self) private var library
    @Environment(TranslationStore.self) private var translations
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.locale) private var locale

    @State private var showsAddedToast = false

    private static let coverWidth: CGFloat = 132
    private static let coverTop: CGFloat = 84
    /// How far the cover overlaps the flap's top edge.
    private static let coverOverlap: CGFloat = 34

    private var palette: BrandPalette {
        BrandPalette.resolve(systemDark: colorScheme == .dark)
    }

    private var job: TranslationJob { translations.job(for: book) }

    /// The cover flips to its translated jacket the moment a whole-book run
    /// starts: the object the reader bought changes, no spinner needed.
    private var isFlipped: Bool {
        !reduceMotion && job.activeRequestKind == .full
            && (job.phase.isInFlight || job.phase == .finished)
    }

    var body: some View {
        GeometryReader { proxy in
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.62)
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)
                .transition(.opacity)

            flap
                .frame(height: max(320, proxy.size.height - flapTop))
                .transition(.move(edge: .bottom))

            cover
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, Self.coverTop)
                .allowsHitTesting(false)

            closeButton
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.trailing, Spacing.md)
                .padding(.top, Spacing.xs)
                .transition(.opacity)

            if showsAddedToast { toast }
        }
        }
        .accessibilityIdentifier("translation.sheet")
        .onChange(of: job.phase) { _, phase in
            guard phase == .finished else { return }
            let feedback = UINotificationFeedbackGenerator()
            feedback.notificationOccurred(.success)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) { showsAddedToast = true }
            Task {
                try? await Task.sleep(for: .seconds(2.2))
                withAnimation(.easeOut(duration: 0.25)) { showsAddedToast = false }
            }
        }
    }

    // MARK: - Cover

    private var cover: some View {
        ZStack {
            front
                .opacity(isFlipped ? 0 : 1)
            back
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(isFlipped ? 1 : 0)
        }
        .frame(width: Self.coverWidth, height: Self.coverWidth * 1.5)
        .rotation3DEffect(
            .degrees(isFlipped ? 180 : (reduceMotion ? 0 : -9)),
            axis: (x: 0, y: 1, z: 0), perspective: 0.6
        )
        .rotation3DEffect(.degrees(reduceMotion ? 0 : 2), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
        .shadow(color: .black.opacity(0.55), radius: 22, y: 18)
        .background {
            // Spotlight: the one place the stage spends its light.
            RadialGradient(
                colors: [Color(hex: "#CFE3D6").opacity(0.22), .clear],
                center: .center, startRadius: 10, endRadius: 210
            )
            .frame(width: 420, height: 420)
            .allowsHitTesting(false)
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.86), value: isFlipped)
        .matchedGeometryEffect(id: heroID, in: namespace, isSource: true)
    }

    private var front: some View {
        Color.clear
            .overlay { BookCard.cover(book: book, coverURL: library.coverURL(for: book)) }
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    /// The translated jacket: same art, the edition named along the bottom.
    private var back: some View {
        Color.clear
            .overlay { BookCard.cover(book: book, coverURL: library.coverURL(for: book)) }
            .overlay(alignment: .bottom) {
                Text(verbatim: editionName)
                    .font(Typography.control(9.5, weight: .medium))
                    .tracking(0.8)
                    .textCase(.uppercase)
                    .foregroundStyle(Color(hex: "#F4F1E9"))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .background(.black.opacity(0.45))
            }
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private var editionName: String {
        String(localized: "\(job.targetLanguage.localizedName(in: locale)) edition")
    }

    // MARK: - Flap

    /// Scrolls only when the flap is shorter than its content (small phones,
    /// large type); otherwise it does not move under the finger at all.
    private var flap: some View {
        ScrollView {
            TranslationSheet(book: book)
                .padding(.top, Self.coverOverlap + Spacing.lg)
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background {
                flapMaterial
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 30, topTrailingRadius: 30, style: .continuous))
                    .overlay(alignment: .top) {
                        UnevenRoundedRectangle(topLeadingRadius: 30, topTrailingRadius: 30, style: .continuous)
                            .strokeBorder(.white.opacity(0.6), lineWidth: 1)
                            .mask(alignment: .top) { Rectangle().frame(height: 60) }
                    }
                    .shadow(color: .black.opacity(0.35), radius: 30, y: -10)
                    .ignoresSafeArea(edges: .bottom)
            }
    }

    /// Where the flap's top edge sits relative to the cover: overlapping its
    /// lower third, so the cover reads as resting on the flap.
    private var flapTop: CGFloat { Self.coverTop + Self.coverWidth * 1.5 - Self.coverOverlap }

    @ViewBuilder
    private var flapMaterial: some View {
        if reduceTransparency {
            palette.background
        } else {
            Rectangle().fill(.ultraThinMaterial)
                .overlay(palette.surface.opacity(0.55))
        }
    }

    // MARK: - Chrome

    private var closeButton: some View {
        Button(action: onClose) {
            Icon(.x, size: 16)
                .foregroundStyle(Color(hex: "#F4F1E9"))
                .frame(width: 38, height: 38)
                .background(.ultraThinMaterial.opacity(reduceTransparency ? 0 : 1))
                .background(.white.opacity(reduceTransparency ? 0.3 : 0.12))
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.35)))
        }
        .buttonStyle(PressScaleButtonStyle(reduceMotion: reduceMotion))
        .accessibilityLabel("Close")
        .accessibilityIdentifier("translation.close")
    }

    private var toast: some View {
        Label { Text("Added to your shelf") } icon: { Icon(.check, size: 13) }
            .font(Typography.control(13, weight: .medium))
            .foregroundStyle(palette.background)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(palette.text.opacity(0.92))
            .clipShape(Capsule())
            .padding(.bottom, 104)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .accessibilityIdentifier("translation.addedToast")
    }
}
