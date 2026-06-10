import WebKit

/// Owns the WKWebView and speaks to the JS pagination engine.
/// SwiftUI only ever wraps `webView`; all commands go through here.
@MainActor
final class ReaderController: NSObject, WKScriptMessageHandler {

    let webView: WKWebView
    let pageSize: CGSize

    /// (page, pageCount) after every page change or relayout.
    var onState: ((Int, Int) -> Void)?
    /// Fired once per chapter when the engine finished measuring.
    var onChapterReady: (() -> Void)?

    private var settingsCSS: String
    private var pendingFraction: Double?
    private var pendingLocate: (query: String, occurrence: Int)?

    init(pageSize: CGSize, initialCSS: String) {
        self.pageSize = pageSize
        self.settingsCSS = initialCSS

        let configuration = WKWebViewConfiguration()
        configuration.suppressesIncrementalRendering = true
        webView = WKWebView(
            frame: CGRect(origin: .zero, size: pageSize),
            configuration: configuration
        )
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.isOpaque = false
        super.init()

        configuration.userContentController.add(self, name: "lumen")
        installUserScripts()
    }

    private func installUserScripts() {
        let controller = webView.configuration.userContentController
        controller.removeAllUserScripts()
        controller.addUserScript(WKUserScript(
            source: ReaderScripts.applyStyle(css: settingsCSS),
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))
        controller.addUserScript(WKUserScript(
            source: ReaderScripts.engine(pageWidth: pageSize.width),
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        ))
    }

    // MARK: - Commands

    func loadChapter(
        at url: URL, readAccessRoot: URL,
        fraction: Double = 0, locate: (String, Int)? = nil
    ) {
        pendingFraction = fraction
        pendingLocate = locate.map { (query: $0.0, occurrence: $0.1) }
        webView.alpha = 0
        webView.loadFileURL(url, allowingReadAccessTo: readAccessRoot)
    }

    func applySettings(css: String, backgroundColor: UIColor) {
        settingsCSS = css
        webView.backgroundColor = backgroundColor
        webView.scrollView.backgroundColor = backgroundColor
        installUserScripts()
        webView.evaluateJavaScript(ReaderScripts.applyStyle(css: css))
    }

    /// Turns the page; `completion(false)` means we hit a chapter edge.
    func nextPage(completion: @escaping (Bool) -> Void) {
        webView.evaluateJavaScript("window.lumen && window.lumen.next()") {
            result, _ in
            completion((result as? Bool) ?? false)
        }
    }

    func prevPage(completion: @escaping (Bool) -> Void) {
        webView.evaluateJavaScript("window.lumen && window.lumen.prev()") {
            result, _ in
            completion((result as? Bool) ?? false)
        }
    }

    func goToFraction(_ fraction: Double) {
        webView.evaluateJavaScript(
            "window.lumen && window.lumen.goToFraction(\(fraction), false)"
        )
    }

    /// Current page snippet for bookmark labels.
    func snippet(completion: @escaping (String) -> Void) {
        webView.evaluateJavaScript("window.lumen && window.lumen.snippet()") {
            result, _ in
            completion((result as? String) ?? "")
        }
    }

    // MARK: - Engine messages

    nonisolated func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard let body = message.body as? [String: Any],
              let type = body["type"] as? String else { return }
        let page = body["page"] as? Int ?? 0
        let pageCount = body["pageCount"] as? Int ?? 1

        Task { @MainActor in
            switch type {
            case "ready":
                if let locate = self.pendingLocate {
                    self.pendingLocate = nil
                    self.pendingFraction = nil
                    let escaped = locate.query
                        .replacingOccurrences(of: "\\", with: "\\\\")
                        .replacingOccurrences(of: "\"", with: "\\\"")
                    self.webView.evaluateJavaScript(
                        """
                        window.lumen.locate("\(escaped)", \
                        \(locate.occurrence))
                        """
                    )
                } else {
                    let fraction = self.pendingFraction ?? 0
                    self.pendingFraction = nil
                    self.webView.evaluateJavaScript(
                        "window.lumen.goToFraction(\(fraction), false)"
                    )
                }
                self.onChapterReady?()
                UIView.animate(withDuration: 0.18) {
                    self.webView.alpha = 1
                }
            case "state":
                self.onState?(page, pageCount)
            default:
                break
            }
        }
    }
}
