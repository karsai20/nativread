import SwiftUI

/// Whole-book search with snippets; tapping a result jumps to the match
/// and highlights it on the page.
struct SearchSheet: View {
    @Bindable var viewModel: ReaderViewModel
    @FocusState private var isFieldFocused: Bool

    private var theme: ReaderTheme { viewModel.settings.theme }

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(theme.secondaryText)
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
                            .foregroundStyle(theme.secondaryText)
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(theme.text.opacity(0.06))
            )
            .padding(.horizontal, 20)
            .padding(.top, 20)

            if viewModel.searchResults.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "text.page.badge.magnifyingglass")
                        .font(.system(size: 28))
                        .foregroundStyle(theme.secondaryText)
                    Text(viewModel.searchQuery.count >= 2
                        ? "No matches" : "Type at least two characters")
                        .font(.system(.subheadline, design: .serif))
                        .foregroundStyle(theme.secondaryText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                resultsList
            }
        }
        .foregroundStyle(theme.text)
        .background(theme.background.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .onAppear { isFieldFocused = true }
    }

    private var resultsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                Text("\(viewModel.searchResults.count) result\(viewModel.searchResults.count == 1 ? "" : "s")")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.secondaryText)
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
                                .foregroundStyle(theme.accent)
                            highlightedSnippet(result.snippet)
                                .font(.system(size: 14, design: .serif))
                                .foregroundStyle(theme.text)
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
            + Text(match).bold().foregroundColor(theme.accent)
            + Text(after)
    }
}
