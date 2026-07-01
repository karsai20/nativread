import SwiftUI

/// Whole-book search with snippets; tapping a result jumps to the match
/// and highlights it on the page.
struct SearchSheet: View {
    @Bindable var viewModel: ReaderViewModel
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

    /// Shown while a whole-book search is in flight.
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
        .accessibilityLabel("Searching")
    }

    /// Shown before a search runs (hint) or after one finds nothing.
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
            // Localized at the String level: `Text(String)` is verbatim, so
            // these must resolve through the catalog here, not in the view.
            return String(localized: "Type at least two characters")
        }
        // Only claim "no matches" once a search has actually completed;
        // before that, keep prompting so an empty list never lies.
        return viewModel.hasSearched
            ? String(localized: "No matches")
            : String(localized: "Press search to find")
    }

    private var resultsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                // Eyebrow count: tracked uppercase reads as metadata, not a heading.
                Text("\(String(viewModel.searchResults.count)) result\(viewModel.searchResults.count == 1 ? "" : "s")")
                    .font(Typography.eyebrow)
                    .tracking(Typography.eyebrowTracking)
                    .textCase(.uppercase)
                    .foregroundStyle(palette.secondaryText)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.xxs + 2)
                    .accessibilityIdentifier("search.resultCount")

                ForEach(viewModel.searchResults) { result in
                    Button {
                        viewModel.goTo(result: result)
                    } label: {
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            // Chapter location in eyebrow style.
                            Text(result.chapterTitle)
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

    /// Bolds the query inside the snippet.
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
