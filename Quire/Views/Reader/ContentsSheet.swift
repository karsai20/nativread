import SwiftUI

/// Table of contents + bookmarks, one sheet, segmented.
struct ContentsSheet: View {
    @Bindable var viewModel: ReaderViewModel
    @State private var section = 0
    @State private var editingNoteFor: Highlight?

    private var palette: ReaderPalette { viewModel.palette }

    var body: some View {
        VStack(spacing: 14) {
            Picker("Section", selection: $section) {
                Text("Contents").tag(0)
                Text("Bookmarks").tag(1)
                Text("Highlights").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.top, 18)

            switch section {
            case 0: tocList
            case 1: bookmarkList
            default: highlightList
            }
        }
        .foregroundStyle(palette.text)
        .background(palette.background.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .sheet(item: $editingNoteFor) { highlight in
            NoteEditor(
                highlight: highlight,
                palette: palette
            ) { newNote in
                viewModel.setNote(newNote, for: highlight)
            }
        }
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
                                        ? palette.accent : palette.text
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

    private var highlightList: some View {
        Group {
            let highlights = viewModel.book?.highlights ?? []
            if highlights.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "highlighter")
                        .font(.system(size: 28))
                        .foregroundStyle(palette.secondaryText)
                    Text("No highlights yet")
                        .font(.system(.subheadline, design: .serif))
                        .foregroundStyle(palette.secondaryText)
                    Text("Select text while reading to highlight it")
                        .font(.system(size: 12))
                        .foregroundStyle(palette.secondaryText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    exportHeader
                    highlightScroll
                }
            }
        }
    }

    @ViewBuilder
    private var exportHeader: some View {
        if let book = viewModel.book {
            HStack {
                Text("^[\(book.highlights.count) highlight](inflect: true)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.secondaryText)
                Spacer()
                Menu {
                    if let markdownURL = exportURL(for: book, format: .markdown) {
                        ShareLink(item: markdownURL) {
                            Label("Markdown", systemImage: "doc.richtext")
                        }
                    }
                    if let csvURL = exportURL(for: book, format: .csv) {
                        ShareLink(item: csvURL) {
                            Label("CSV", systemImage: "tablecells")
                        }
                    }
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(palette.accent)
                }
                .accessibilityIdentifier("contents.highlights.export")
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
    }

    private var highlightScroll: some View {
        Group {
            let highlights = viewModel.book?.highlights ?? []
            ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(highlights) { highlight in
                            Button {
                                viewModel.goTo(highlight: highlight)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(highlight.chapterTitle)
                                        .font(.system(
                                            size: 12, weight: .semibold
                                        ))
                                        .foregroundStyle(palette.accent)
                                    Text(highlight.text)
                                        .font(.system(
                                            size: 14, design: .serif
                                        ))
                                        .foregroundStyle(palette.text)
                                        .multilineTextAlignment(.leading)
                                        .lineLimit(3)
                                        .padding(.horizontal, 6)
                                        .background(
                                            palette.accent.opacity(0.16),
                                            in: RoundedRectangle(
                                                cornerRadius: 4
                                            )
                                        )
                                    if let note = trimmedNote(highlight) {
                                        Label {
                                            Text(note)
                                                .multilineTextAlignment(.leading)
                                        } icon: {
                                            Image(systemName: "note.text")
                                        }
                                        .font(.system(size: 12))
                                        .foregroundStyle(palette.secondaryText)
                                        .lineLimit(4)
                                        .padding(.top, 2)
                                    }
                                }
                                .frame(
                                    maxWidth: .infinity, alignment: .leading
                                )
                                .padding(.horizontal, 24)
                                .padding(.vertical, 10)
                            }
                            .contextMenu {
                                Button {
                                    editingNoteFor = highlight
                                } label: {
                                    Label(
                                        trimmedNote(highlight) == nil
                                            ? "Add Note" : "Edit Note",
                                        systemImage: "note.text"
                                    )
                                }
                                .accessibilityIdentifier(
                                    "contents.highlights.note.edit"
                                )
                                Button(role: .destructive) {
                                    viewModel.removeHighlight(highlight)
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .accessibilityIdentifier("contents.highlights")
        }
    }

    /// The highlight's note when it has visible content, else nil — so an
    /// empty or whitespace-only note never renders a stray note row.
    private func trimmedNote(_ highlight: Highlight) -> String? {
        guard let note = highlight.note?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !note.isEmpty
        else { return nil }
        return note
    }

    private var bookmarkList: some View {
        Group {
            let bookmarks = viewModel.book?.bookmarks ?? []
            if bookmarks.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "bookmark")
                        .font(.system(size: 28))
                        .foregroundStyle(palette.secondaryText)
                    Text("No bookmarks yet")
                        .font(.system(.subheadline, design: .serif))
                        .foregroundStyle(palette.secondaryText)
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
                                        .foregroundStyle(palette.accent)
                                    Text(bookmark.snippet)
                                        .font(.system(
                                            size: 14, design: .serif
                                        ))
                                        .foregroundStyle(palette.text)
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

    private enum ExportFormat {
        case markdown, csv

        var fileExtension: String {
            switch self {
            case .markdown: return "md"
            case .csv: return "csv"
            }
        }

        func contents(for book: Book) -> String {
            switch self {
            case .markdown: return HighlightExport.markdown(for: book)
            case .csv: return HighlightExport.csv(for: book)
            }
        }
    }

    /// Writes the chosen export to a temp file named after the book and
    /// returns its URL, so the share sheet hands AirDrop/Files/Mail a real
    /// `.md`/`.csv` document. Returns nil only if the write fails.
    private func exportURL(for book: Book, format: ExportFormat) -> URL? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "\(sanitizedFileName(book.title)) Highlights"
            )
            .appendingPathExtension(format.fileExtension)
        do {
            try format.contents(for: book)
                .write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    /// Strips path-hostile characters so the book title is safe as a
    /// filename, collapsing the result to a non-empty fallback.
    private func sanitizedFileName(_ title: String) -> String {
        let illegal = CharacterSet(charactersIn: "/\\:?%*|\"<>")
            .union(.newlines)
        let cleaned = title
            .components(separatedBy: illegal)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Book" : cleaned
    }
}

/// A small multiline editor for a highlight's personal note. Prefilled
/// with the current note; Save persists, Cancel discards.
private struct NoteEditor: View {
    let highlight: Highlight
    let palette: ReaderPalette
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: String

    init(
        highlight: Highlight,
        palette: ReaderPalette,
        onSave: @escaping (String) -> Void
    ) {
        self.highlight = highlight
        self.palette = palette
        self.onSave = onSave
        _draft = State(initialValue: highlight.note ?? "")
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text(highlight.text)
                    .font(.system(size: 13, design: .serif))
                    .foregroundStyle(palette.secondaryText)
                    .lineLimit(3)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(
                        palette.accent.opacity(0.16),
                        in: RoundedRectangle(cornerRadius: 4)
                    )

                TextEditor(text: $draft)
                    .font(.system(size: 16, design: .serif))
                    .foregroundStyle(palette.text)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(
                        palette.secondaryText.opacity(0.1),
                        in: RoundedRectangle(cornerRadius: 8)
                    )
                    .accessibilityIdentifier("contents.highlights.note.editor")
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(palette.background.ignoresSafeArea())
            .navigationTitle("Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(draft)
                        dismiss()
                    }
                    .accessibilityIdentifier("contents.highlights.note.save")
                }
            }
        }
        .presentationDetents([.medium])
    }
}
