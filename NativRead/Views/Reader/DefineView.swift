import SwiftUI
import UIKit

/// Dictionary lookup sheet for a selected word or short phrase. Uses Apple's
/// built-in Dictionary UI so readers get the same installed dictionaries and
/// Manage Dictionaries path available system-wide. iOS does not expose system
/// dictionary definition text to apps, so saving keeps the word and context.
struct DefineView: View {
    let word: String
    let palette: ReaderPalette
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

    var body: some View {
        NavigationStack {
            SystemDictionaryController(term: word)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        onSave("", VocabularyEntry.appleDictionarySource)
        didSave = true
    }
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
