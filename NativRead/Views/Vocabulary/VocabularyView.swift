import SwiftUI

/// The global saved-vocabulary sheet: every word the reader kept from the
/// Define popup, with its reading context and definition, plus Anki-ready
/// CSV / Markdown export. Uses BrandPalette — launched from the library
/// header, so it lives in ambient app chrome, not a reading surface.
struct VocabularyView: View {
    @Environment(VocabularyStore.self) private var store
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var editingNoteFor: VocabularyEntry?

    /// Brand palette follows system appearance, matching the library.
    private var palette: BrandPalette {
        BrandPalette.resolve(systemDark: colorScheme == .dark)
    }

    var body: some View {
        NavigationStack {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(palette.background.ignoresSafeArea())
                .navigationTitle("My Vocabulary")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                            .tint(palette.accent)
                    }
                }
        }
        .presentationDetents([.large])
        .accessibilityIdentifier("vocabulary.sheet")
        .sheet(item: $editingNoteFor) { entry in
            VocabularyNoteEditor(entry: entry, palette: palette) { newNote in
                store.setNote(entryID: entry.id, note: newNote)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if store.entries.isEmpty {
            emptyState
        } else {
            VStack(spacing: 0) {
                exportHeader
                list
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "character.book.closed")
                .font(.system(size: 32))
                .foregroundStyle(palette.secondaryText)
            Text("No saved words yet")
                .font(Typography.title())
                .foregroundStyle(palette.text)
            Text("Tap Define while reading, then Save to keep a word here.")
                .font(Typography.meta())
                .foregroundStyle(palette.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Spacing.xl)
        .accessibilityIdentifier("vocabulary.empty")
    }

    private var exportHeader: some View {
        HStack {
            // Eyebrow count label — tracks how many words are saved without
            // visually competing with the word entries below.
            Text("^[\(store.entries.count) word](inflect: true)")
                .font(Typography.eyebrow)
                .tracking(Typography.eyebrowTracking)
                .textCase(.uppercase)
                .foregroundStyle(palette.secondaryText)
            Spacer()
            Menu {
                if let url = exportURL(format: .csvPlain) {
                    ShareLink(item: url) {
                        Label("CSV (Plain)", systemImage: "tablecells")
                    }
                }
                if let url = exportURL(format: .csvCloze) {
                    ShareLink(item: url) {
                        Label("CSV (Cloze)", systemImage: "rectangle.dashed")
                    }
                }
                if let url = exportURL(format: .markdown) {
                    ShareLink(item: url) {
                        Label("Markdown", systemImage: "doc.richtext")
                    }
                }
                if let url = ankiExportURL() {
                    ShareLink(item: url) {
                        Label(
                            "Anki deck (.apkg)",
                            systemImage: "rectangle.stack.badge.plus"
                        )
                    }
                    .accessibilityIdentifier("vocabulary.export.anki")
                }
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
                    .font(Typography.meta())
                    .foregroundStyle(palette.accent)
            }
            .accessibilityIdentifier("vocabulary.export")
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.xs)
    }

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(store.entries) { entry in
                    row(for: entry)
                        .contextMenu {
                            Button {
                                editingNoteFor = entry
                            } label: {
                                Label(
                                    trimmedNote(entry) == nil
                                        ? "Add Note" : "Edit Note",
                                    systemImage: "note.text"
                                )
                            }
                            .accessibilityIdentifier(
                                "vocabulary.entry.note.edit"
                            )
                            Button(role: .destructive) {
                                store.removeEntry(entry.id)
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                }
            }
        }
        .accessibilityIdentifier("vocabulary.list")
    }

    private func row(for entry: VocabularyEntry) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            // The word itself gets title-weight serif — editorial emphasis
            // without the full grandeur of display.
            Text(entry.word)
                .font(Typography.title())
                .foregroundStyle(palette.accent)

            if let context = trimmedContext(entry) {
                // Context quote: body italic for the literary quoting convention.
                Text(context)
                    .font(Typography.body())
                    .italic()
                    .foregroundStyle(palette.secondaryText)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
            }

            if !entry.definition.isEmpty {
                Text(entry.definition)
                    .font(Typography.body())
                    .foregroundStyle(palette.text)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
            }

            if let note = trimmedNote(entry) {
                Label {
                    Text(note).multilineTextAlignment(.leading)
                } icon: {
                    Image(systemName: "note.text")
                }
                .font(Typography.meta())
                .foregroundStyle(palette.secondaryText)
                .lineLimit(4)
                .padding(.top, Spacing.xxs)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .accessibilityIdentifier("vocabulary.entry")
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(palette.hairline)
                .frame(height: Spacing.hairlineWidth)
                .padding(.horizontal, Spacing.lg)
        }
    }

    // MARK: - Helpers

    private func trimmedNote(_ entry: VocabularyEntry) -> String? {
        guard let note = entry.note?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !note.isEmpty
        else { return nil }
        return note
    }

    private func trimmedContext(_ entry: VocabularyEntry) -> String? {
        guard let context = entry.contextSentence?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !context.isEmpty
        else { return nil }
        return context
    }

    private enum ExportFormat {
        case csvPlain, csvCloze, markdown

        var fileExtension: String {
            switch self {
            case .csvPlain, .csvCloze: return "csv"
            case .markdown: return "md"
            }
        }

        func contents(for entries: [VocabularyEntry]) -> String {
            switch self {
            case .csvPlain:
                return VocabularyExport.csv(for: entries, cloze: false)
            case .csvCloze:
                return VocabularyExport.csv(for: entries, cloze: true)
            case .markdown:
                return VocabularyExport.markdown(for: entries)
            }
        }
    }

    /// Writes the chosen export to a temp file and returns its URL so the
    /// share sheet hands a real document to AirDrop/Files/Mail. Returns
    /// nil only if the write fails.
    private func exportURL(format: ExportFormat) -> URL? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("NativRead Vocabulary")
            .appendingPathExtension(format.fileExtension)
        do {
            try format.contents(for: store.entries)
                .write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    /// Builds a native Anki `.apkg` deck from the saved words and returns
    /// its temp-file URL for the share sheet, or nil if generation fails —
    /// so a failure simply hides the option rather than crashing.
    private func ankiExportURL() -> URL? {
        try? AnkiPackage.build(for: store.entries)
    }
}

/// A small multiline editor for a saved word's personal note. Prefilled
/// with the current note; Save persists, Cancel discards. Accepts
/// `any PaletteColors` so it can be driven by either BrandPalette or
/// ReaderPalette without a conversion shim.
private struct VocabularyNoteEditor: View {
    let entry: VocabularyEntry
    let palette: any PaletteColors
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: String

    init(
        entry: VocabularyEntry,
        palette: any PaletteColors,
        onSave: @escaping (String) -> Void
    ) {
        self.entry = entry
        self.palette = palette
        self.onSave = onSave
        _draft = State(initialValue: entry.note ?? "")
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text(entry.word)
                    .font(Typography.title())
                    .foregroundStyle(palette.accent)

                TextEditor(text: $draft)
                    .font(Typography.body())
                    .foregroundStyle(palette.text)
                    .scrollContentBackground(.hidden)
                    .padding(Spacing.xs)
                    .background(
                        palette.secondaryText.opacity(0.1),
                        in: RoundedRectangle(cornerRadius: Spacing.radiusSmall)
                    )
                    .accessibilityIdentifier("vocabulary.entry.note.editor")
            }
            .padding(Spacing.lg)
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
                    .accessibilityIdentifier("vocabulary.entry.note.save")
                }
            }
        }
        .presentationDetents([.medium])
    }
}
