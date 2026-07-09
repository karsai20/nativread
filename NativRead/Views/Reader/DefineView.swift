import SwiftUI
import UIKit

/// Dictionary lookup sheet for a selected word or short phrase. Uses Apple's
/// built-in Dictionary UI so readers get the same installed dictionaries and
/// Manage Dictionaries path available system-wide. iOS does not expose system
/// dictionary definition text to apps, so saving keeps the word and context.
struct DefineView: View {
    let word: String
    let palette: ReaderPalette
    let defineLanguage: AppLanguage
    /// The sentence the word was read in, for saving as context; nil when
    /// the reader could not capture it.
    var context: String? = nil
    /// Invoked when the reader taps Save; nil disables saving (e.g. previews).
    /// The definition is empty because Apple's Dictionary text is display-only.
    var onSave: ((_ definition: String, _ source: String) -> Void)? = nil
    /// Whether this word is already in the saved vocabulary, reflected on
    /// open so the action reads "Saved" rather than offering a duplicate.
    var isAlreadySaved: Bool = false

    @Environment(\.dismiss) private var dismiss

    /// Flips to true once the reader taps Save in this session.
    @State private var didSave = false

    private var lookupResult: DictionaryLookupResult? {
        DictionaryProvider.lookup(word, language: defineLanguage)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                dictionaryHeader
                    .padding(Spacing.md)

                Divider()
                    .overlay(palette.hairline)

                SystemDictionaryController(term: word)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(palette.background.ignoresSafeArea())
            .navigationTitle(word)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if onSave != nil {
                    ToolbarItem(placement: .cancellationAction) {
                        saveButton
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .tint(palette.accent)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .accessibilityIdentifier("define.sheet")
    }

    // MARK: - Local dictionary surface

    @ViewBuilder
    private var dictionaryHeader: some View {
        if let lookupResult {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(lookupResult.source)
                    .font(Typography.eyebrow)
                    .tracking(Typography.eyebrowTracking)
                    .textCase(.uppercase)
                    .foregroundStyle(palette.secondaryText)

                Text(lookupResult.definition)
                    .font(Typography.body(17))
                    .foregroundStyle(palette.text)
                    .textSelection(.enabled)
                    .accessibilityIdentifier("define.localDefinition")

                Text("System dictionary results appear below when installed on this device.")
                    .font(Typography.meta())
                    .foregroundStyle(palette.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(defineLanguage.defineSourceName)
                    .font(Typography.eyebrow)
                    .tracking(Typography.eyebrowTracking)
                    .textCase(.uppercase)
                    .foregroundStyle(palette.secondaryText)

                Text("No bundled definition yet. The Apple system dictionary below remains available as a fallback.")
                    .font(Typography.body(16))
                    .foregroundStyle(palette.text)
                    .accessibilityIdentifier("define.localFallback")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Save

    /// "Save" -> "Saved": disabled once saved (this session or already in
    /// the list). Reduced-motion friendly - only the label and tint change,
    /// no implicit movement.
    private var saveButton: some View {
        let saved = didSave || isAlreadySaved
        return Button {
            performSave()
        } label: {
            Label(saved ? "Saved" : "Save",
                  systemImage: saved ? "checkmark" : "plus")
                .font(Typography.body(15))
        }
        .tint(palette.accent)
        .disabled(saved)
        .accessibilityIdentifier("define.save")
    }

    private func performSave() {
        guard let onSave, !didSave, !isAlreadySaved else { return }
        if let lookupResult {
            onSave(lookupResult.definition, lookupResult.source)
        } else {
            onSave("", VocabularyEntry.appleDictionarySource)
        }
        didSave = true
    }
}

struct DictionaryLookupResult: Equatable {
    let term: String
    let definition: String
    let source: String
}

enum DictionaryProvider {
    static func lookup(
        _ rawTerm: String,
        language: AppLanguage
    ) -> DictionaryLookupResult? {
        guard let key = normalizedKey(rawTerm) else { return nil }
        let definition: String?
        switch language {
        case .en:
            definition = englishDefinitions[key]
        case .hu:
            definition = englishToHungarian[key]
        case .system, .es, .de:
            definition = nil
        }

        guard let definition else { return nil }
        return DictionaryLookupResult(
            term: rawTerm,
            definition: definition,
            source: language.defineSourceName
        )
    }

    private static func normalizedKey(_ rawTerm: String) -> String? {
        let trimmed = rawTerm.trimmingCharacters(
            in: .whitespacesAndNewlines.union(.punctuationCharacters)
        )
        let collapsed = trimmed
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .lowercased()
        return collapsed.isEmpty ? nil : collapsed
    }

    /// Minimal bundled English pack used by tests, screenshots, and first-run
    /// validation. The build path can replace this table with generated WordNet
    /// assets without changing the Define UI contract.
    private static let englishDefinitions: [String: String] = [
        "lantern": "A portable light with a protective enclosure.",
        "book": "A written or printed work bound for reading.",
        "reader": "A person who reads or an app used for reading text."
    ]

    /// Launch Hungarian Define pack: English headword to Hungarian gloss. Keep
    /// this provider explicit so Settings never advertises Spanish/German lookup
    /// before a real downloadable pack exists.
    private static let englishToHungarian: [String: String] = [
        "lantern": "lámpás; hordozható fényforrás védő burával",
        "book": "könyv; olvasásra szánt írott vagy nyomtatott mű",
        "reader": "olvasó; szöveget olvasó személy vagy olvasóalkalmazás"
    ]
}

/// Thin SwiftUI bridge for `UIReferenceLibraryViewController`, the same system
/// dictionary surface that exposes the installed Apple dictionaries. When the
/// term has no installed dictionary match, the controller shows its own "No
/// definition found" screen with the built-in **Manage** button, so no custom
/// dictionary-management path is needed.
private struct SystemDictionaryController: UIViewControllerRepresentable {
    let term: String

    func makeUIViewController(
        context: Context
    ) -> UIReferenceLibraryViewController {
        UIReferenceLibraryViewController(term: term)
    }

    func updateUIViewController(
        _ uiViewController: UIReferenceLibraryViewController,
        context: Context
    ) {}
}
