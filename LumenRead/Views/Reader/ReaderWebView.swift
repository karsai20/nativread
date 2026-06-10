import SwiftUI
import WebKit

// MARK: - UIViewRepresentable

struct ReaderWebView: UIViewRepresentable {
    let chapterURL: URL
    let css: String
    @Binding var scrollPosition: Double
    var onScrollChange: (Double) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true

        // Use a weak wrapper to avoid WKUserContentController retaining Coordinator
        let handler = WeakMessageHandler(context.coordinator)
        config.userContentController.add(handler, name: "contentReady")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.delegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.showsVerticalScrollIndicator = false
        // Lock zoom — font size is controlled by the typography panel
        webView.scrollView.minimumZoomScale = 1.0
        webView.scrollView.maximumZoomScale = 1.0
        webView.scrollView.bouncesZoom = false
        context.coordinator.webView = webView
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let coord = context.coordinator
        let path = chapterURL.path

        if coord.loadedPath != path {
            coord.loadedPath = path
            coord.pendingScrollPosition = scrollPosition
            coord.currentCSS = css
            loadChapter(into: webView, coordinator: coord)
        } else if coord.currentCSS != css {
            coord.currentCSS = css
            updateCSS(in: webView, css: css)
        }
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "contentReady")
        coordinator.cleanupTempFile()
    }

    // MARK: - Chapter Loading

    private func loadChapter(into webView: WKWebView, coordinator: Coordinator) {
        let chapterDir = chapterURL.deletingLastPathComponent()

        let rawHTML = (try? String(contentsOf: chapterURL, encoding: .utf8))
            ?? (try? String(contentsOf: chapterURL, encoding: .isoLatin1))
            ?? "<html><body><p style='font-family:Georgia;padding:40px;font-size:17px;'>Could not load this chapter.</p></body></html>"

        let styledHTML = inject(css: coordinator.currentCSS, into: rawHTML)

        // Write to a temp file in the same directory — this keeps all relative
        // paths (images, fonts, linked CSS) working correctly under loadFileURL.
        let tempURL = chapterDir.appendingPathComponent("._verso_render.html")
        coordinator.tempFileURL = tempURL

        do {
            try styledHTML.write(to: tempURL, atomically: true, encoding: .utf8)
            webView.loadFileURL(tempURL, allowingReadAccessTo: chapterDir)
        } catch {
            // Fallback: images may not load, but text will
            webView.loadHTMLString(styledHTML, baseURL: chapterDir)
        }
    }

    // Injects viewport meta + our CSS + a window.onload reporter into the HTML.
    private func inject(css: String, into html: String) -> String {
        let safeCSS = css.replacingOccurrences(of: "</style>", with: "<\\/style>")

        let injection = """
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
        <style id="verso-styles">\(safeCSS)</style>
        <script>
        window.addEventListener('load', function() {
            var h = document.body ? document.body.scrollHeight : 0;
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.contentReady) {
                window.webkit.messageHandlers.contentReady.postMessage(h);
            }
        });
        </script>
        """

        var result = html
        if let range = result.range(of: "</head>", options: .caseInsensitive) {
            result.insert(contentsOf: injection, at: range.lowerBound)
        } else if let range = result.range(of: "<body", options: .caseInsensitive) {
            result.insert(contentsOf: "<head>\(injection)</head>", at: range.lowerBound)
        } else {
            result = "<html><head>\(injection)</head><body>\(html)</body></html>"
        }
        return result
    }

    // Hot-swaps CSS without reloading the chapter
    private func updateCSS(in webView: WKWebView, css: String) {
        let safe = css
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
        let js = """
        (function(){
            var el = document.getElementById('verso-styles');
            if (el) { el.textContent = `\(safe)`; }
        })();
        """
        webView.evaluateJavaScript(js)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, WKNavigationDelegate, UIScrollViewDelegate, WKScriptMessageHandler {
        var parent: ReaderWebView
        weak var webView: WKWebView?
        var loadedPath: String?
        var pendingScrollPosition: Double = 0
        var currentCSS: String = ""
        var tempFileURL: URL?
        private var isSettlingScroll = false

        init(_ parent: ReaderWebView) { self.parent = parent }

        // WKScriptMessageHandler — fires after window.onload with accurate scrollHeight
        func userContentController(_ controller: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            guard message.name == "contentReady" else { return }
            let scrollHeight = (message.body as? Double) ?? (message.body as? Int).map(Double.init) ?? 0
            restorePosition(totalHeight: scrollHeight)
        }

        private func restorePosition(totalHeight: Double) {
            guard pendingScrollPosition > 0, totalHeight > 0 else { return }
            let targetY = totalHeight * pendingScrollPosition
            isSettlingScroll = true
            webView?.scrollView.setContentOffset(CGPoint(x: 0, y: targetY), animated: false)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                self?.isSettlingScroll = false
            }
            pendingScrollPosition = 0
        }

        // UIScrollViewDelegate
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard !isSettlingScroll else { return }
            let contentH = scrollView.contentSize.height
            let viewH    = scrollView.bounds.height
            let total    = contentH - viewH
            guard total > 1 else { return }
            let progress = Double(scrollView.contentOffset.y / total)
            parent.onScrollChange(max(0, min(1, progress)))
        }

        func cleanupTempFile() {
            guard let url = tempFileURL else { return }
            try? FileManager.default.removeItem(at: url)
        }
    }
}

// MARK: - Weak message handler (prevents WKUserContentController retain cycle)

private final class WeakMessageHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?
    init(_ target: WKScriptMessageHandler) { self.target = target }

    func userContentController(_ controller: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        target?.userContentController(controller, didReceive: message)
    }
}
