import SwiftUI
import UIKit

/// Contents (PDF outline) + page bookmarks, mirroring the EPUB
/// `ContentsSheet` shape but bound to the PDF view model.
struct PDFContentsSheet: View {
    @Bindable var viewModel: PDFReaderViewModel
    @State private var section = 0

    private var palette: ReaderPalette { viewModel.palette }

    var body: some View {
        VStack(spacing: Spacing.md) {
            Picker("Section", selection: $section) {
                Text("Contents").tag(0)
                Text("Bookmarks").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.md + 2)

            if section == 0 { tocList } else { bookmarkList }
        }
        .foregroundStyle(palette.text)
        .background(palette.background.ignoresSafeArea())
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private var tocList: some View {
        let toc = viewModel.toc
        if toc.isEmpty {
            emptyState(
                icon: "list.bullet",
                title: "No contents",
                detail: "This PDF has no embedded outline"
            )
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(toc) { entry in
                        Button {
                            viewModel.goTo(tocItem: entry)
                        } label: {
                            HStack {
                                Text(entry.title)
                                    .font(entry.depth == 0
                                        ? Typography.title(16)
                                        : Typography.body(14))
                                    .foregroundStyle(
                                        entry.pageIndex == viewModel.page
                                            ? palette.accent : palette.text
                                    )
                                    .multilineTextAlignment(.leading)
                                Spacer()
                            }
                            .padding(.leading,
                                     CGFloat(entry.depth) * 18 + Spacing.lg)
                            .padding(.trailing, Spacing.lg)
                            .padding(.vertical, Spacing.xs + 3)
                        }
                    }
                }
            }
            .accessibilityIdentifier("contents.toc")
        }
    }

    @ViewBuilder
    private var bookmarkList: some View {
        let bookmarks = viewModel.book?.bookmarks ?? []
        if bookmarks.isEmpty {
            emptyState(
                icon: "bookmark",
                title: "No bookmarks yet",
                detail: nil
            )
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(bookmarks) { bookmark in
                        Button {
                            viewModel.goTo(bookmark: bookmark)
                        } label: {
                            VStack(alignment: .leading, spacing: Spacing.xxs) {
                                Text(bookmark.chapterTitle)
                                    .font(Typography.eyebrow)
                                    .tracking(Typography.eyebrowTracking)
                                    .textCase(.uppercase)
                                    .foregroundStyle(palette.accent)
                                Text(bookmark.snippet)
                                    .font(Typography.body(14))
                                    .foregroundStyle(palette.text)
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(2)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, Spacing.lg)
                            .padding(.vertical, Spacing.xs)
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                viewModel.removeBookmark(bookmark)
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }

    private func emptyState(
        icon: String, title: String, detail: String?
    ) -> some View {
        VStack(spacing: Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(palette.secondaryText)
            Text(LocalizedStringKey(title))
                .font(Typography.title())
                .foregroundStyle(palette.secondaryText)
            if let detail {
                Text(LocalizedStringKey(detail))
                    .font(Typography.meta())
                    .foregroundStyle(palette.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Whole-document PDF search; tapping a result jumps to the page.
struct PDFSearchSheet: View {
    @Bindable var viewModel: PDFReaderViewModel
    @FocusState private var isFieldFocused: Bool

    private var palette: ReaderPalette { viewModel.palette }

    var body: some View {
        VStack(spacing: Spacing.md) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(palette.secondaryText)
                TextField("Search in book", text: $viewModel.searchQuery)
                    .focused($isFieldFocused)
                    .font(Typography.body())
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                    .onSubmit { viewModel.runSearch() }
                    .accessibilityIdentifier("search.field")
                if !viewModel.searchQuery.isEmpty {
                    Button {
                        viewModel.searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(palette.secondaryText)
                    }
                }
            }
            .padding(Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: Spacing.sm)
                    .fill(palette.surface)
            )
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.md)

            if viewModel.isSearching {
                searchingState
            } else if viewModel.searchResults.isEmpty {
                emptyState
            } else {
                resultsList
            }
        }
        .foregroundStyle(palette.text)
        .background(palette.background.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .onAppear { isFieldFocused = true }
    }

    private var searchingState: some View {
        VStack(spacing: Spacing.sm) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(palette.accent)
            Text("Searching…")
                .font(Typography.title())
                .foregroundStyle(palette.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("search.searching")
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.xs) {
            Image(systemName: "text.page.badge.magnifyingglass")
                .font(.system(size: 28))
                .foregroundStyle(palette.secondaryText)
            Text(emptyStateMessage)
                .font(Typography.title())
                .foregroundStyle(palette.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateMessage: String {
        guard viewModel.searchQuery.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).count >= 2 else {
            return String(localized: "Type at least two characters")
        }
        return viewModel.hasSearched
            ? String(localized: "No matches")
            : String(localized: "Press search to find")
    }

    private var resultsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(viewModel.searchResults) { result in
                    Button {
                        viewModel.goTo(result: result)
                    } label: {
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text("Page \(result.pageIndex + 1)")
                                .font(Typography.eyebrow)
                                .tracking(Typography.eyebrowTracking)
                                .textCase(.uppercase)
                                .foregroundStyle(palette.accent)
                            highlightedSnippet(result.snippet)
                                .font(Typography.body(14))
                                .foregroundStyle(palette.text)
                                .multilineTextAlignment(.leading)
                                .lineLimit(3)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.xs)
                    }
                }
            }
        }
    }

    private func highlightedSnippet(_ snippet: String) -> Text {
        let query = viewModel.searchQuery
        guard !query.isEmpty,
              let range = snippet.range(
                  of: query, options: [.caseInsensitive, .diacriticInsensitive]
              )
        else { return Text(snippet) }
        let before = String(snippet[..<range.lowerBound])
        let match = String(snippet[range])
        let after = String(snippet[range.upperBound...])
        return Text(before)
            + Text(match).bold().foregroundColor(palette.accent)
            + Text(after)
    }
}

/// PDF appearance: page brightness and the page tint (Light / Sepia /
/// Dark). Dark engages the hue-preserving night invert.
struct PDFAppearanceSheet: View {
    @Bindable var viewModel: PDFReaderViewModel
    @State private var brightness = Double(UIScreen.main.brightness)

    private var palette: ReaderPalette { viewModel.palette }

    private let modes: [(label: String, theme: ReaderTheme, icon: String)] = [
        ("Light", .paper, "sun.max"),
        ("Sepia", .sepia, "book.closed"),
        ("Dark", .ink, "moon.stars")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("Appearance")
                .font(Typography.title(20))
                .foregroundStyle(palette.text)
                .padding(.top, Spacing.lg)

            brightnessRow
            modeRow
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.background.ignoresSafeArea())
        .presentationDetents([.height(260), .medium])
    }

    private var brightnessRow: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Brightness")
                .font(Typography.eyebrow)
                .tracking(Typography.eyebrowTracking)
                .textCase(.uppercase)
                .foregroundStyle(palette.secondaryText)
            HStack(spacing: Spacing.sm) {
                Image(systemName: "sun.min")
                    .foregroundStyle(palette.secondaryText)
                Slider(value: $brightness, in: 0...1) { _ in } // continuous
                    .tint(palette.accent)
                    .onChange(of: brightness) {
                        UIScreen.main.brightness = CGFloat(brightness)
                    }
                    .accessibilityIdentifier("appearance.brightness")
                Image(systemName: "sun.max")
                    .foregroundStyle(palette.secondaryText)
            }
        }
    }

    private var modeRow: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Page")
                .font(Typography.eyebrow)
                .tracking(Typography.eyebrowTracking)
                .textCase(.uppercase)
                .foregroundStyle(palette.secondaryText)
            HStack(spacing: Spacing.sm) {
                ForEach(modes, id: \.theme) { mode in
                    modeButton(mode)
                }
            }
        }
    }

    private func modeButton(
        _ mode: (label: String, theme: ReaderTheme, icon: String)
    ) -> some View {
        let isSelected = viewModel.currentTheme == mode.theme
        return Button {
            viewModel.setTheme(mode.theme)
        } label: {
            VStack(spacing: Spacing.xxs) {
                Image(systemName: mode.icon)
                    .font(.system(size: 18))
                Text(LocalizedStringKey(mode.label))
                    .font(Typography.meta(12))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: Spacing.radiusSmall)
                    .fill(isSelected
                        ? palette.accent.opacity(0.18) : palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Spacing.radiusSmall)
                    .strokeBorder(
                        isSelected ? palette.accent : palette.hairline,
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
            .foregroundStyle(isSelected ? palette.accent : palette.text)
        }
        .accessibilityIdentifier("appearance.mode.\(mode.label)")
    }
}
