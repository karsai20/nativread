import SwiftUI

/// Table of contents + bookmarks, one sheet, segmented.
struct ContentsSheet: View {
    @Bindable var viewModel: ReaderViewModel
    @State private var section = 0
    @State private var editingNoteFor: Highlight?

    private var palette: ReaderPalette { viewModel.palette }

    var body: some View {
        VStack(spacing: Spacing.md) {
            Picker("Section", selection: $section) {
                Text("Contents").tag(0)
                Text("Bookmarks").tag(1)
                Text("Highlights").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.md + 2)

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
                                // Top-level chapters get the full title role;
                                // nested entries step down to body for hierarchy.
                                .font(entry.depth == 0
                                    ? Typography.title(16)
                                    : Typography.body(14))
                                .foregroundStyle(
                                    entry.spineIndex == viewModel.spineIndex
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
                VStack(spacing: Spacing.xs) {
                    Image(systemName: "highlighter")
                        .font(.system(size: 28))
                        .foregroundStyle(palette.secondaryText)
                    Text("No highlights yet")
                        .font(Typography.title())
                        .foregroundStyle(palette.secondaryText)
                    Text("Select text while reading to highlight it")
                        .font(Typography.meta())
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
                // Eyebrow count label — tracked uppercase reinforces "metadata, not prose".
                Text("^[\(book.highlights.count) highlight](inflect: true)")
                    .font(Typography.eyebrow)
                    .tracking(Typography.eyebrowTracking)
                    .textCase(.uppercase)
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
                        .font(Typography.meta(13))
                        .foregroundStyle(palette.accent)
                }
                .accessibilityIdentifier("contents.highlights.export")
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xs)
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
                                VStack(alignment: .leading, spacing: Spacing.xxs) {
                                    // Chapter location — eyebrow style echoes the TOC header.
                                    Text(highlight.chapterTitle)
                                        .font(Typography.eyebrow)
                                        .tracking(Typography.eyebrowTracking)
                                        .textCase(.uppercase)
                                        .foregroundStyle(palette.accent)
                                    Text(highlight.text)
                                        .font(Typography.body(14))
                                        .foregroundStyle(palette.text)
                                        .multilineTextAlignment(.leading)
                                        .lineLimit(3)
                                        .padding(.horizontal, Spacing.xxs + 2)
                                        .background(
                                            palette.accent.opacity(0.16),
                                            in: RoundedRectangle(
                                                cornerRadius: Spacing.xxs
                                            )
                                        )
                                    if let note = trimmedNote(highlight) {
                                        Label {
                                            Text(note)
                                                .multilineTextAlignment(.leading)
                                        } icon: {
                                            Image(systemName: "note.text")
                                        }
                                        .font(Typography.meta())
                                        .foregroundStyle(palette.secondaryText)
                                        .lineLimit(4)
                                        .padding(.top, Spacing.xxs / 2)
                                    }
                                }
                                .frame(
                                    maxWidth: .infinity, alignment: .leading
                                )
                                .padding(.horizontal, Spacing.lg)
                                .padding(.vertical, Spacing.xs)
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
                VStack(spacing: Spacing.xs) {
                    Image(systemName: "bookmark")
                        .font(.system(size: 28))
                        .foregroundStyle(palette.secondaryText)
                    Text("No bookmarks yet")
                        .font(Typography.title())
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
                                VStack(alignment: .leading, spacing: Spacing.xxs) {
                                    // Eyebrow chapter location.
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
                                .frame(
                                    maxWidth: .infinity, alignment: .leading
                                )
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
            VStack(alignment: .leading, spacing: Spacing.sm) {
                // The quoted passage — body role at a slightly smaller size.
                Text(highlight.text)
                    .font(Typography.body(13))
                    .foregroundStyle(palette.secondaryText)
                    .lineLimit(3)
                    .padding(.horizontal, Spacing.xxs + 2)
                    .padding(.vertical, Spacing.xxs)
                    .background(
                        palette.accent.opacity(0.16),
                        in: RoundedRectangle(cornerRadius: Spacing.xxs)
                    )

                TextEditor(text: $draft)
                    .font(Typography.body(16))
                    .foregroundStyle(palette.text)
                    .scrollContentBackground(.hidden)
                    .padding(Spacing.xs)
                    .background(
                        palette.secondaryText.opacity(0.1),
                        in: RoundedRectangle(cornerRadius: Spacing.xs)
                    )
                    .accessibilityIdentifier("contents.highlights.note.editor")
            }
            .padding(Spacing.md)
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
