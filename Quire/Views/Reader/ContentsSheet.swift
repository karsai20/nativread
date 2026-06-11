import SwiftUI

/// Table of contents + bookmarks, one sheet, segmented.
struct ContentsSheet: View {
    @Bindable var viewModel: ReaderViewModel
    @State private var section = 0

    private var theme: ReaderTheme { viewModel.settings.theme }

    var body: some View {
        VStack(spacing: 14) {
            Picker("Section", selection: $section) {
                Text("Contents").tag(0)
                Text("Bookmarks").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.top, 18)

            if section == 0 {
                tocList
            } else {
                bookmarkList
            }
        }
        .foregroundStyle(theme.text)
        .background(theme.background.ignoresSafeArea())
        .presentationDetents([.medium, .large])
    }

    private var tocList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(viewModel.parsed?.toc ?? []) { entry in
                    Button {
                        viewModel.goTo(entry: entry)
                    } label: {
                        HStack {
                            Text(entry.title)
                                .font(.system(
                                    size: entry.depth == 0 ? 16 : 14,
                                    weight: entry.spineIndex
                                        == viewModel.spineIndex
                                        ? .semibold : .regular,
                                    design: .serif
                                ))
                                .foregroundStyle(
                                    entry.spineIndex == viewModel.spineIndex
                                        ? theme.accent : theme.text
                                )
                                .multilineTextAlignment(.leading)
                            Spacer()
                        }
                        .padding(.leading,
                                 CGFloat(entry.depth) * 18 + 24)
                        .padding(.trailing, 24)
                        .padding(.vertical, 11)
                    }
                    .disabled(entry.spineIndex == nil)
                    .opacity(entry.spineIndex == nil ? 0.4 : 1)
                }
            }
        }
        .accessibilityIdentifier("contents.toc")
    }

    private var bookmarkList: some View {
        Group {
            let bookmarks = viewModel.book?.bookmarks ?? []
            if bookmarks.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "bookmark")
                        .font(.system(size: 28))
                        .foregroundStyle(theme.secondaryText)
                    Text("No bookmarks yet")
                        .font(.system(.subheadline, design: .serif))
                        .foregroundStyle(theme.secondaryText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(bookmarks) { bookmark in
                            Button {
                                viewModel.goTo(bookmark: bookmark)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(bookmark.chapterTitle)
                                        .font(.system(
                                            size: 12, weight: .semibold
                                        ))
                                        .foregroundStyle(theme.accent)
                                    Text(bookmark.snippet)
                                        .font(.system(
                                            size: 14, design: .serif
                                        ))
                                        .foregroundStyle(theme.text)
                                        .multilineTextAlignment(.leading)
                                        .lineLimit(2)
                                }
                                .frame(
                                    maxWidth: .infinity, alignment: .leading
                                )
                                .padding(.horizontal, 24)
                                .padding(.vertical, 10)
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
    }
}
