import UIKit
import WebKit

/// WKWebView that adds a "Highlight" action to the native text-selection
/// menu. System actions — including Apple's Look Up dictionary — remain
/// untouched and are supplied by WebKit.
final class HighlightingWebView: WKWebView {

    /// Invoked when the user picks Highlight for the current selection.
    var onHighlightSelection: (() -> Void)?

    override func buildMenu(with builder: UIMenuBuilder) {
        // Let WebKit install Copy / Look Up / Translate first, then append
        // the reader-specific action without risking a later super call
        // rebuilding the root menu over our insertion.
        super.buildMenu(with: builder)
        if onHighlightSelection != nil {
            builder.insertChild(
                UIMenu(options: .displayInline, children: [
                    UIAction(
                        title: "Highlight",
                        image: UIImage(systemName: "highlighter")
                    ) { [weak self] _ in
                        self?.onHighlightSelection?()
                    }
                ]),
                atStartOfMenu: .root
            )
        }
    }
}
