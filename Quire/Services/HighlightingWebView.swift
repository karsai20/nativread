import UIKit
import WebKit

/// WKWebView that adds a "Highlight" action to the native text
/// selection menu, alongside the system Copy / Look Up / Translate.
/// The system items already cover dictionary lookup and Apple's
/// on-device translation, so only highlighting needs custom code.
final class HighlightingWebView: WKWebView {

    /// Invoked when the user picks Highlight for the current selection.
    var onHighlightSelection: (() -> Void)?

    override func buildMenu(with builder: UIMenuBuilder) {
        if onHighlightSelection != nil {
            let highlight = UIAction(
                title: "Highlight",
                image: UIImage(systemName: "highlighter")
            ) { [weak self] _ in
                self?.onHighlightSelection?()
            }
            builder.insertChild(
                UIMenu(options: .displayInline, children: [highlight]),
                atStartOfMenu: .root
            )
        }
        super.buildMenu(with: builder)
    }
}
