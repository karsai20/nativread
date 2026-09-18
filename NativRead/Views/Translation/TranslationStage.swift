import SwiftUI

/// The translate flow is a book page, the way a store shows one title: the
/// cover the reader tapped lifts off the shelf onto a paper page that fades
/// in beneath it — no scrim, no glass. Spatial consistency: it came from the
/// shelf, it goes back to the shelf. Nothing drags; close is the X.
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
                .scaleEffect(isActive && !reduceMotion ? 0.96 : 1)
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

/// Paper page: the lifted cover, the book's details, the close button.
struct TranslationStage: View {
    let book: Book
    let heroID: String
    let namespace: Namespace.ID
    let onClose: () -> Void

    @Environment(LibraryStore.self) private var library
    @Environment(TranslationStore.self) private var translations
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.locale) private var locale

    @State private var showsAddedToast = false

    private static let coverWidth: CGFloat = 150

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
        ZStack(alignment: .topTrailing) {
            palette.background
                .ignoresSafeArea()
                .transition(.opacity)

            VStack(spacing: 0) {
                cover
                    .padding(.top, Spacing.xl)
                    .transition(.identity)

                TranslationSheet(book: book)
                    .padding(.top, Spacing.lg)
                    .frame(maxHeight: .infinity)
                    .transition(.opacity)
            }

            closeButton
                .padding(.trailing, Spacing.lg)
                .padding(.top, Spacing.xs)
                .transition(.opacity)

            if showsAddedToast {
                toast.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
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
        .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
        .shadow(color: .black.opacity(palette.isDark ? 0.5 : 0.22), radius: 18, y: 10)
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

    // MARK: - Chrome

    private var closeButton: some View {
        Button(action: onClose) {
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
