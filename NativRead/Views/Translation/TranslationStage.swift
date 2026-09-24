import SwiftUI

/// The translate flow is a book page, the way a store shows one title: the
/// cover the reader tapped lifts off the shelf onto a paper page that fades
/// in beneath it — no scrim, no glass. Spatial consistency: it came from the
/// shelf, it goes back to the shelf — by the X, or by swiping the page right
/// the way a pushed screen goes back.
///
/// Exactly one cover is ever visible: the shelf's hides the instant the stage
/// mounts, the stage's flies between the shelf slot and the page slot, and
/// the shelf's shows again only after the flight home has landed.
struct TranslationStageModifier: ViewModifier {
    let presenter: TranslationPresenter
    let namespace: Namespace.ID

    func body(content: Content) -> some View {
        // Touches follow the lift, not the mount: the shelf scrolls again the
        // moment close is tapped, while the cover is still flying home.
        let isActive = presenter.isLifted
        ZStack {
            content
                .allowsHitTesting(!isActive)
                .accessibilityHidden(isActive)

            if let active = presenter.book {
                TranslationStage(
                    book: active,
                    shelfID: TranslationPresenter.heroID(for: active, host: presenter.host),
                    namespace: namespace,
                    presenter: presenter
                )
                .id(active.id)
                .transition(.identity)
                .allowsHitTesting(isActive)
                .zIndex(1)
            }
        }
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
    /// returns to. Hidden, without animation, while the stage draws it.
    func translationHero(
        for book: Book, host: TranslationPresenter.Host,
        in namespace: Namespace.ID, presenter: TranslationPresenter
    ) -> some View {
        let isOffShelf = presenter.book?.id == book.id && presenter.host == host
        return self
            .matchedGeometryEffect(
                id: TranslationPresenter.heroID(for: book, host: host),
                in: namespace
            )
            .opacity(isOffShelf ? 0 : 1)
            .animation(nil, value: isOffShelf)
    }
}

/// Paper page: the lifted cover, the book's details, the close button.
struct TranslationStage: View {
    let book: Book
    let shelfID: String
    let namespace: Namespace.ID
    let presenter: TranslationPresenter

    @Environment(LibraryStore.self) private var library
    @Environment(TranslationStore.self) private var translations
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.locale) private var locale

    @State private var showsAddedToast = false
    /// How far the reader has pulled the page right, and whether a swipe has
    /// already sent it off. `isHorizontalSwipe` is decided on the first move
    /// so a vertical drag never nudges the page sideways.
    @State private var dragX: CGFloat = 0
    @State private var isSwipedAway = false
    @State private var isHorizontalSwipe: Bool?
    @State private var pageWidth: CGFloat = 400

    private static let coverWidth: CGFloat = 132

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

    private var isLifted: Bool { presenter.isLifted }

    /// The page slides with the finger; once swiped away it keeps going.
    private var pageOffset: CGFloat { isSwipedAway ? pageWidth : dragX }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            palette.background
                .ignoresSafeArea()
                .opacity(isLifted ? 1 : 0)
                // The edge the finger pulls: a shadow so the page reads as
                // lying on the list it came from.
                .shadow(color: .black.opacity(dragX > 0 ? 0.18 : 0), radius: 18, x: -4)
                .offset(x: pageOffset)

            VStack(spacing: 0) {
                // The cover's place on the page; the cover itself flies above.
                // The slot, not the cover, follows the finger: the cover is
                // pinned to the slot's global frame, which cancels any offset
                // put on the cover itself. The offset sits after the matched
                // effect so it counts towards that frame, and the flight home
                // starts from wherever the finger left the cover.
                Color.clear
                    .frame(width: Self.coverWidth, height: Self.coverWidth * 1.5)
                    .matchedGeometryEffect(id: TranslationPresenter.stageSlotID, in: namespace)
                    .offset(x: dragX)
                    .padding(.top, Spacing.xl)

                TranslationSheet(book: book)
                    .padding(.top, Spacing.lg)
                    .frame(maxHeight: .infinity)
                    .opacity(isLifted ? 1 : 0)
                    .offset(x: pageOffset, y: isLifted || reduceMotion ? 0 : 24)
            }
            .allowsHitTesting(isLifted)

            cover

            closeButton
                .padding(.trailing, Spacing.lg)
                .padding(.top, Spacing.xs)
                .opacity(isLifted ? 1 : 0)
                .offset(x: pageOffset)
                .allowsHitTesting(isLifted)

            if showsAddedToast {
                toast.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
        }
        .accessibilityIdentifier("translation.sheet")
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { pageWidth = $0 }
        .simultaneousGesture(swipeBack)
        .accessibilityAction(.escape) { presenter.dismiss() }
        .onAppear { presenter.lift() }
        // Caught mid-flight home and lifted again: the page comes back whole.
        .onChange(of: isLifted) { _, lifted in
            guard lifted else { return }
            isSwipedAway = false
            dragX = 0
        }
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

    // MARK: - Swipe back

    private static let swipeCommitFraction: CGFloat = 0.3
    private static let swipeFlickFraction: CGFloat = 0.6

    private var swipeBack: some Gesture {
        DragGesture(minimumDistance: 14)
            .onChanged { value in
                guard isLifted else { return }
                if isHorizontalSwipe == nil {
                    isHorizontalSwipe = value.translation.width > abs(value.translation.height)
                }
                guard isHorizontalSwipe == true else { return }
                dragX = max(0, value.translation.width)
            }
            .onEnded { value in
                defer { isHorizontalSwipe = nil }
                guard isHorizontalSwipe == true, isLifted else { return }
                let isCommitted = dragX > pageWidth * Self.swipeCommitFraction
                    || value.predictedEndTranslation.width > pageWidth * Self.swipeFlickFraction
                if isCommitted {
                    withAnimation(TranslationPresenter.animation) { isSwipedAway = true }
                    presenter.dismiss()
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) { dragX = 0 }
                }
            }
    }

    // MARK: - Cover

    /// Pinned to the shelf slot or the page slot; animating `isLifted` moves
    /// it between the two. Under Reduce Motion it stays on the page and fades.
    private var cover: some View {
        let target = isLifted || reduceMotion ? TranslationPresenter.stageSlotID : shelfID
        return ZStack {
            front
                .opacity(isFlipped ? 0 : 1)
            back
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(isFlipped ? 1 : 0)
        }
        .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
        .animation(.spring(response: 0.6, dampingFraction: 0.86), value: isFlipped)
        .matchedGeometryEffect(id: target, in: namespace, isSource: false)
        .shadow(
            color: .black.opacity(isLifted ? (palette.isDark ? 0.5 : 0.22) : 0.22),
            radius: isLifted ? 18 : 5, y: isLifted ? 10 : 3
        )
        .opacity(reduceMotion && !isLifted ? 0 : 1)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
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
        String(localized: "\(job.targetLanguage.localizedName(in: locale)) edition", bundle: .appLanguage)
    }

    // MARK: - Chrome

    private var closeButton: some View {
        Button { presenter.dismiss() } label: {
            Icon(.x, size: 16)
                .foregroundStyle(palette.text)
                .frame(width: 38, height: 38)
                .background(palette.surface)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(palette.hairline))
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
            .padding(.bottom, Spacing.xl)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .accessibilityIdentifier("translation.addedToast")
    }
}
