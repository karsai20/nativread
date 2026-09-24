import SwiftUI

/// The translate flow is a book page presented as a system sheet: it slides
/// up over the shelf, closes with a swipe down or the X, and leaves the shelf
/// or the Translate list beneath it exactly as it was.
struct TranslationStageModifier: ViewModifier {
    let presenter: TranslationPresenter

    func body(content: Content) -> some View {
        content.sheet(item: Binding(
            get: { presenter.book },
            set: { if $0 == nil { presenter.dismiss() } }
        )) { book in
            TranslationStage(book: book, onClose: presenter.dismiss)
        }
    }
}

extension View {
    func translationStage(presenter: TranslationPresenter) -> some View {
        modifier(TranslationStageModifier(presenter: presenter))
    }
}

/// Paper page: the cover, the book's details, the close button.
struct TranslationStage: View {
    let book: Book
    let onClose: () -> Void

    @Environment(LibraryStore.self) private var library
    @Environment(TranslationStore.self) private var translations
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.locale) private var locale

    @State private var showsAddedToast = false

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

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                cover
                    .frame(width: Self.coverWidth, height: Self.coverWidth * 1.5)
                    .padding(.top, Spacing.xl)

                TranslationSheet(book: book)
                    .padding(.top, Spacing.lg)
                    .frame(maxHeight: .infinity)
            }

            closeButton
                .padding(.trailing, Spacing.lg)
                .padding(.top, Spacing.md)

            if showsAddedToast {
                toast.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
        }
        .accessibilityIdentifier("translation.sheet")
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(palette.background)
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
        .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
        .animation(.spring(response: 0.6, dampingFraction: 0.86), value: isFlipped)
        .shadow(color: .black.opacity(palette.isDark ? 0.5 : 0.22), radius: 18, y: 10)
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
