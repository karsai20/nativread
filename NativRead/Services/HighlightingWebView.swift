import UIKit
import WebKit

/// WKWebView that adds a "Highlight" action to the native text
/// selection menu, alongside the system Copy / Look Up / Translate.
/// The system items already cover dictionary lookup and Apple's
/// on-device translation, so only highlighting needs custom code.
final class HighlightingWebView: WKWebView {

    /// Invoked when the user picks Highlight for the current selection.
    var onHighlightSelection: (() -> Void)?

    /// Invoked when the user picks Define for the current selection.
    var onDefineSelection: (() -> Void)?

    override func buildMenu(with builder: UIMenuBuilder) {
        var actions: [UIAction] = []
        if onHighlightSelection != nil {
            actions.append(UIAction(
                title: "Highlight",
                image: UIImage(systemName: "highlighter")
            ) { [weak self] _ in
                self?.onHighlightSelection?()
            })
        }
        if onDefineSelection != nil {
            actions.append(UIAction(
                title: "Define",
                image: UIImage(systemName: "character.book.closed")
            ) { [weak self] _ in
                self?.onDefineSelection?()
            })
        }
        if !actions.isEmpty {
            builder.insertChild(
                UIMenu(options: .displayInline, children: actions),
                atStartOfMenu: .root
            )
        }
        super.buildMenu(with: builder)
    }
}
