import SwiftUI
import WebKit

/// Thin wrapper: the web view is created and driven by ReaderController,
/// SwiftUI only places it in the hierarchy.
struct ReaderWebView: UIViewRepresentable {
    let controller: ReaderController

    func makeUIView(context: Context) -> WKWebView {
        controller.webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
