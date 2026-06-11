import WebKit

/// Owns the WKWebView and speaks to the JS reading engine.
/// SwiftUI only ever wraps `webView`; all commands go through here.
@MainActor
final class ReaderController: NSObject, WKScriptMessageHandler {

    let webView: HighlightingWebView
    let pageSize: CGSize

    /// (page, pageCount) after every page change or relayout.
    var onState: ((Int, Int) -> Void)?
    /// Fired once per chapter when the engine finished measuring.
    var onChapterReady: (() -> Void)?
    /// Tap zones reported by the page: "left", "right", "center".
    var onTap: ((String) -> Void)?
    /// Horizontal swipe in paged flow: "forward" or "backward".
    var onSwipe: ((String) -> Void)?
    /// The user picked Highlight in the selection menu.
    var onHighlightRequested: (() -> Void)? {
        get { webView.onHighlightSelection }
        set { webView.onHighlightSelection = newValue }
    }

    private var settingsCSS: String
    private var flow: PageFlow
    private var transition: PageTransition
    private var pendingFraction: Double?
    private var pendingLocate: (query: String, occurrence: Int)?

    init(
        pageSize: CGSize, initialCSS: String,
        flow: PageFlow, transition: PageTransition
    ) {
        self.pageSize = pageSize
        self.settingsCSS = initialCSS
        self.flow = flow
        self.transition = transition

        let configuration = WKWebViewConfiguration()
        configuration.suppressesIncrementalRendering = true
        webView = HighlightingWebView(
            frame: CGRect(origin: .zero, size: pageSize),
            configuration: configuration
        )
        webView.scrollView.isScrollEnabled = flow == .scroll
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
            source: ReaderScripts.engine(
                pageWidth: pageSize.width, flow: flow,
                transition: transition
            ),
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

    func applySettings(
        css: String, backgroundColor: UIColor,
        flow: PageFlow, transition: PageTransition
    ) {
        settingsCSS = css
        self.flow = flow
        self.transition = transition
        webView.backgroundColor = backgroundColor
        webView.scrollView.backgroundColor = backgroundColor
        webView.scrollView.isScrollEnabled = flow == .scroll
        installUserScripts()
        webView.evaluateJavaScript(ReaderScripts.applyStyle(css: css))
        webView.evaluateJavaScript(
            """
            window.lumen
              && (window.lumen.transition = "\(transition.rawValue)")
            """
        )
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

    /// Resolves the current selection into a relayout-proof locator;
    /// nil when there is no usable selection.
    func selectionLocator(
        completion: @escaping ((text: String, occurrence: Int)?) -> Void
    ) {
        webView.evaluateJavaScript(
            "window.lumen && window.lumen.selectionLocator()"
        ) { result, _ in
            guard let dict = result as? [String: Any],
                  let text = dict["text"] as? String,
                  let occurrence = dict["occurrence"] as? Int else {
                completion(nil)
                return
            }
            completion((text: text, occurrence: occurrence))
        }
    }

    func clearSelection() {
        webView.evaluateJavaScript(
            "window.lumen && window.lumen.clearSelection()"
        )
    }

    /// Draws the stored highlights for the loaded chapter.
    func applyHighlights(_ highlights: [Highlight]) {
        webView.evaluateJavaScript(
            """
            window.lumen && window.lumen.applyHighlights(\
            \(ReaderScripts.highlightsJSON(highlights)))
            """
        )
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
        let zone = body["zone"] as? String
        let direction = body["direction"] as? String

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
            case "tap":
                if let zone { self.onTap?(zone) }
            case "swipe":
                if let direction { self.onSwipe?(direction) }
            default:
                break
            }
        }
    }
}
