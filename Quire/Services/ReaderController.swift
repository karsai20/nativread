import WebKit

/// Owns the WKWebView and speaks to the JS reading engine.
/// SwiftUI only ever wraps `webView`; all commands go through here.
@MainActor
final class ReaderController: NSObject, WKScriptMessageHandler,
                              UIScrollViewDelegate {

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
    /// The user picked Define in the selection menu.
    var onDefineRequested: (() -> Void)? {
        get { webView.onDefineSelection }
        set { webView.onDefineSelection = newValue }
    }
    /// Scroll flow: the user pulled past the chapter edge.
    /// "forward" (bottom) or "backward" (top).
    var onOverscroll: ((String) -> Void)?

    /// Dragging past the chapter edge by this much advances chapters.
    private static let overscrollThreshold: CGFloat = 70

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
        // Incremental rendering must stay ON: suppressing it stops
        // WebKit from rasterising the off-screen CSS columns, so a
        // turned page arrives blank.
        configuration.suppressesIncrementalRendering = false
        webView = HighlightingWebView(
            frame: CGRect(origin: .zero, size: pageSize),
            configuration: configuration
        )
        // Paged flow turns pages by scrolling the root scroller
        // horizontally (a CSS transform leaves WebKit's off-screen
        // tiles unpainted, so the next page arrives blank). The scroll
        // view must stay enabled for the programmatic scroll to take
        // effect, and paging snaps it to whole viewport-wide columns.
        webView.scrollView.isScrollEnabled = true
        webView.scrollView.isPagingEnabled = flow == .paged
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.scrollView.showsVerticalScrollIndicator = flow == .scroll
        webView.isOpaque = false
        super.init()

        webView.scrollView.delegate = self
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
        webView.scrollView.isPagingEnabled = flow == .paged
        webView.scrollView.showsVerticalScrollIndicator = flow == .scroll
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

    /// The current selection's plain text, trimmed; empty when nothing
    /// usable is selected. Used to seed a dictionary Define lookup.
    func selectedText(completion: @escaping (String) -> Void) {
        webView.evaluateJavaScript(
            "window.lumen && window.lumen.selectedText()"
        ) { result, _ in
            completion((result as? String) ?? "")
        }
    }

    /// The sentence the current selection sits in, for saving a word
    /// with its reading context; empty when none can be derived. Pure
    /// DOM read — never affects layout or the rendered page.
    func selectionSentence(completion: @escaping (String) -> Void) {
        webView.evaluateJavaScript(
            "window.lumen && window.lumen.selectionSentence()"
        ) { result, _ in
            completion((result as? String) ?? "")
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

    // MARK: - Overscroll chapter advance (scroll flow)

    /// The rubber-band overscroll happens at the UIScrollView level,
    /// invisible to the page's JS, so chapter-edge pulls are detected
    /// here from the drag's end position.
    nonisolated func scrollViewDidEndDragging(
        _ scrollView: UIScrollView, willDecelerate decelerate: Bool
    ) {
        MainActor.assumeIsolated {
            guard flow == .scroll else { return }
            let offset = scrollView.contentOffset.y
            let maxOffset = max(
                0, scrollView.contentSize.height
                    - scrollView.bounds.height
            )
            if offset > maxOffset + Self.overscrollThreshold {
                onOverscroll?("forward")
            } else if offset < -Self.overscrollThreshold {
                onOverscroll?("backward")
            }
        }
    }

    /// Native paging may settle the user on a different page than the
    /// engine thinks; re-read it from the scroll position.
    nonisolated func scrollViewDidEndDecelerating(
        _ scrollView: UIScrollView
    ) {
        MainActor.assumeIsolated {
            guard flow == .paged else { return }
            webView.evaluateJavaScript(
                "window.lumen && window.lumen.syncPagedPage()"
            )
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
        let zone = body["zone"] as? String
        let direction = body["direction"] as? String
        let scrollX = body["x"] as? Double
        let animate = body["animate"] as? Bool ?? false

        Task { @MainActor in
            switch type {
            case "ready":
                // Reset the scroll position before revealing so a stale
                // offset left by the previous chapter can never flash an
                // empty page; goToFraction below sets the precise target.
                self.webView.scrollView.setContentOffset(.zero, animated: false)
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
                // Safety net: never leave the page hidden once the
                // engine is demonstrably alive.
                if self.webView.alpha == 0 {
                    UIView.animate(withDuration: 0.18) {
                        self.webView.alpha = 1
                    }
                }
                self.onState?(page, pageCount)
            case "tap":
                if let zone { self.onTap?(zone) }
            case "swipe":
                if let direction { self.onSwipe?(direction) }
            case "scroll":
                // The engine requests a horizontal page move; drive the
                // native scroll view directly (reliable, unlike a JS
                // scrollTo) so the destination page is actually painted.
                if let scrollX {
                    self.webView.scrollView.setContentOffset(
                        CGPoint(x: scrollX, y: 0), animated: animate
                    )
                }
            default:
                break
            }
        }
    }
}
