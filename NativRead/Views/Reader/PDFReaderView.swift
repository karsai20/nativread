import SwiftUI
import PDFKit

/// Full-screen PDF reading surface. Same chrome language as `ReaderView`
/// — melt-away top/bottom bars, page position, page label, bookmark —
/// over a fixed-layout PDFKit page instead of the reflowable web view.
struct PDFReaderView: View {
    @State private var viewModel: PDFReaderViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency)
    private var reduceTransparency

    init(
        book: Book,
        library: LibraryStore,
        settingsStore: SettingsStore,
        initialSystemDark: Bool
    ) {
        _viewModel = State(initialValue: PDFReaderViewModel(
            book: book,
            library: library,
            settingsStore: settingsStore,
            initialSystemDark: initialSystemDark
        ))
    }

    private var palette: ReaderPalette { viewModel.palette }

    var body: some View {
        ZStack {
            palette.background.ignoresSafeArea()

            if let error = viewModel.loadError {
                errorView(error)
            } else {
                pdfSurface
            }

            chrome
        }
        .statusBarHidden(!viewModel.isChromeVisible)
        .preferredColorScheme(palette.isDark ? .dark : .light)
        .onChange(of: colorScheme) {
            viewModel.setSystemDark(colorScheme == .dark)
        }
        .onAppear {
            viewModel.setSystemDark(colorScheme == .dark)
            viewModel.open()
        }
        .onDisappear {
            viewModel.persistProgressNow()
        }
        .sheet(item: $viewModel.activeSheet) { sheet in
            switch sheet {
            case .contents:
                PDFContentsSheet(viewModel: viewModel)
            case .position:
                PDFReadingPositionSheet(viewModel: viewModel)
            case .search:
                PDFSearchSheet(viewModel: viewModel)
            case .appearance:
                PDFAppearanceSheet(viewModel: viewModel)
            }
        }
        .accessibilityAction(.escape) { dismiss() }
    }

    @ViewBuilder
    private var pdfSurface: some View {
        ZStack {
            PDFKitView(
                documentURL: viewModel.documentURL,
                pageIndex: viewModel.page,
                isNight: viewModel.isNight,
                backgroundColor: UIColor(palette.background),
                onPageChange: { viewModel.setPage($0) },
                onTapZone: { viewModel.handleTap(zone: $0) }
            )
            .ignoresSafeArea()

            // Sepia: a warm multiply tint over the white page keeps images
            // and live selection intact (no re-render), unlike night invert.
            if let tint = viewModel.pageTint {
                tint
                    .blendMode(.multiply)
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
            }
        }
    }

    // MARK: - Chrome

    private var chrome: some View {
        VStack(spacing: 0) {
            if viewModel.isChromeVisible {
                topBar.transition(.move(edge: .top).combined(with: .opacity))
            }
            Spacer()
            if viewModel.isChromeVisible {
                bottomBar.transition(
                    .move(edge: .bottom).combined(with: .opacity)
                )
            }
        }
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.22),
            value: viewModel.isChromeVisible
        )
    }

    private var topBar: some View {
        HStack(spacing: Spacing.md) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(
                        width: Spacing.minTapTarget,
                        height: Spacing.minTapTarget
                    )
            }
            .accessibilityIdentifier("reader.back")

            VStack(spacing: 2) {
                Text(viewModel.book?.title ?? "")
                    .font(Typography.title(15))
                    .lineLimit(1)
                Text(viewModel.currentChapterTitle)
                    .font(Typography.eyebrow)
                    .tracking(Typography.eyebrowTracking)
                    .textCase(.uppercase)
                    .foregroundStyle(palette.secondaryText)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)

            Button {
                viewModel.toggleBookmark()
            } label: {
                Image(systemName: viewModel.currentBookmark != nil
                    ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 16, weight: .medium))
            }
            .accessibilityIdentifier("reader.bookmark")
        }
        .foregroundStyle(palette.text)
        .tint(palette.accent)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
        .background(chromeBackground)
    }

    private var bottomBar: some View {
        VStack(spacing: Spacing.xs) {
            passiveProgress

            HStack {
                Button {
                    viewModel.activeSheet = .contents
                } label: {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 17))
                        .frame(
                            width: Spacing.minTapTarget,
                            height: Spacing.minTapTarget
                        )
                }
                .accessibilityIdentifier("reader.contents")

                Spacer()

                Button {
                    viewModel.activeSheet = .position
                } label: {
                    HStack(spacing: 5) {
                        Text(viewModel.pageLabel)
                            .font(Typography.meta(12))
                            .monospacedDigit()
                        Image(systemName: "chevron.up")
                            .font(.system(size: 8, weight: .bold))
                            .accessibilityHidden(true)
                    }
                    .foregroundStyle(palette.secondaryText)
                    .frame(minHeight: Spacing.minTapTarget)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("reader.position")
                .accessibilityLabel(
                    Text("Position in book: \(viewModel.pageLabel)")
                )

                Spacer()

                Button {
                    viewModel.activeSheet = .search
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16))
                        .frame(
                            width: Spacing.minTapTarget,
                            height: Spacing.minTapTarget
                        )
                }
                .accessibilityIdentifier("reader.search")

                Button {
                    viewModel.activeSheet = .appearance
                } label: {
                    Image(systemName: "sun.max")
                        .font(.system(size: 16))
                        .frame(
                            width: Spacing.minTapTarget,
                            height: Spacing.minTapTarget
                        )
                }
                .padding(.leading, Spacing.md)
                .accessibilityIdentifier("reader.appearance")
            }
        }
        .foregroundStyle(palette.text)
        .tint(palette.accent)
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.xs)
        .background(chromeBackground)
    }

    private var passiveProgress: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(palette.hairline.opacity(0.6))
                Capsule()
                    .fill(palette.accent)
                    .frame(width: max(
                        0,
                        proxy.size.width * viewModel.bookFraction
                    ))
            }
        }
        .frame(height: 3)
        .accessibilityHidden(true)
    }

    private var chromeBackground: some View {
        palette.background
            .opacity(reduceTransparency ? 1 : 0.94)
            .overlay(
                palette.surface.opacity(reduceTransparency ? 1 : 0.5)
            )
            .overlay(alignment: .bottom) {
                Rectangle().fill(palette.hairline).frame(height: 1)
            }
            .ignoresSafeArea()
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "doc.questionmark")
                .font(.system(size: 40))
                .foregroundStyle(palette.secondaryText)
            Text("This book could not be opened")
                .font(Typography.title(17))
            Text(message)
                .font(Typography.meta())
                .foregroundStyle(palette.secondaryText)
                .multilineTextAlignment(.center)
            Button("Back to Library") { dismiss() }
                .buttonStyle(.borderedProminent)
                .tint(palette.accent)
        }
        .foregroundStyle(palette.text)
        .padding(Spacing.xl)
    }
}

private struct PDFReadingPositionSheet: View {
    @Bindable var viewModel: PDFReaderViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var draftFraction: Double
    @State private var isEditing = false

    private var palette: ReaderPalette { viewModel.palette }

    init(viewModel: PDFReaderViewModel) {
        self.viewModel = viewModel
        _draftFraction = State(initialValue: viewModel.bookFraction)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            HStack {
                Text("Position in book")
                    .font(Typography.display(28))
                Spacer()
                Button("Done") { dismiss() }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.accent)
                    .accessibilityIdentifier("reader.position.done")
            }

            HStack {
                Text("\(viewModel.page + 1) / \(viewModel.pageCount)")
                    .monospacedDigit()
                Spacer()
                Text("\(displayPercent)%").monospacedDigit()
            }
            .font(Typography.meta(13))
            .foregroundStyle(palette.secondaryText)

            Slider(
                value: $draftFraction,
                in: 0...1,
                onEditingChanged: { editing in
                    isEditing = editing
                    if !editing {
                        viewModel.scrub(toFraction: draftFraction)
                    }
                }
            )
            .tint(palette.accent)
            .accessibilityLabel("Position in book")
            .accessibilityValue("\(displayPercent)%")
            .accessibilityIdentifier("reader.position.slider")

            HStack(spacing: Spacing.sm) {
                pageButton(
                    title: "Previous page",
                    icon: "chevron.left",
                    identifier: "reader.position.previousPage",
                    enabled: viewModel.page > 0
                ) { movePage(by: -1) }
                pageButton(
                    title: "Next page",
                    icon: "chevron.right",
                    identifier: "reader.position.nextPage",
                    enabled: viewModel.page < viewModel.pageCount - 1
                ) { movePage(by: 1) }
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.xl)
        .foregroundStyle(palette.text)
        .background(palette.background.ignoresSafeArea())
        .presentationDetents([.height(300), .medium])
        .presentationDragIndicator(.hidden)
        .onChange(of: viewModel.bookFraction) { _, newValue in
            if !isEditing { draftFraction = newValue }
        }
    }

    private var displayPercent: Int {
        Int((draftFraction * 100).rounded())
    }

    private func movePage(by offset: Int) {
        viewModel.goToPage(viewModel.page + offset)
        draftFraction = viewModel.bookFraction
    }

    private func pageButton(
        title: LocalizedStringKey,
        icon: String,
        identifier: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(Typography.body(14))
                .frame(maxWidth: .infinity, minHeight: Spacing.minTapTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.bordered)
        .tint(palette.accent)
        .disabled(!enabled)
        .accessibilityIdentifier(identifier)
    }
}
