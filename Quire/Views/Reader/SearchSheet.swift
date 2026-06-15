import SwiftUI

/// Whole-book search with snippets; tapping a result jumps to the match
/// and highlights it on the page.
struct SearchSheet: View {
    @Bindable var viewModel: ReaderViewModel
    @FocusState private var isFieldFocused: Bool

    private var palette: ReaderPalette { viewModel.palette }

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(palette.secondaryText)
                TextField("Search in book", text: $viewModel.searchQuery)
                    .focused($isFieldFocused)
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
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(palette.surface)
            )
            .padding(.horizontal, 20)
            .padding(.top, 20)

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
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(palette.accent)
            Text("Searching…")
                .font(.system(.subheadline, design: .serif))
                .foregroundStyle(palette.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("search.searching")
        .accessibilityLabel("Searching")
    }

    /// Shown before a search runs (hint) or after one finds nothing.
    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "text.page.badge.magnifyingglass")
                .font(.system(size: 28))
                .foregroundStyle(palette.secondaryText)
            Text(emptyStateMessage)
                .font(.system(.subheadline, design: .serif))
                .foregroundStyle(palette.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateMessage: String {
        guard viewModel.searchQuery.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).count >= 2 else {
            return "Type at least two characters"
        }
        // Only claim "no matches" once a search has actually completed;
        // before that, keep prompting so an empty list never lies.
        return viewModel.hasSearched ? "No matches" : "Press search to find"
    }

    private var resultsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                Text("\(viewModel.searchResults.count) result\(viewModel.searchResults.count == 1 ? "" : "s")")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(palette.secondaryText)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 6)
                    .accessibilityIdentifier("search.resultCount")

                ForEach(viewModel.searchResults) { result in
                    Button {
                        viewModel.goTo(result: result)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(result.chapterTitle)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(palette.accent)
                            highlightedSnippet(result.snippet)
                                .font(.system(size: 14, design: .serif))
                                .foregroundStyle(palette.text)
                                .multilineTextAlignment(.leading)
                                .lineLimit(3)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
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
