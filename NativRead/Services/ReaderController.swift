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
    /// The user pulled past the chapter edge. "forward" (bottom/right
    /// edge) or "backward" (top/left edge). In scroll flow this is a
    /// vertical overscroll; in paged flow a horizontal one past the last
    /// or first column. Returns true when a chapter load started.
    var onOverscroll: ((String) -> Bool)?

    /// Dragging past the chapter edge by this much advances chapters.
    private static let overscrollThreshold: CGFloat = 70

    /// Encodes a string as a safe JavaScript string literal (quotes
    /// included) via JSON, so book or selection text can never break out
    /// of — or inject into — an evaluated script.
    private static func jsStringLiteral(_ string: String) -> String {
        guard let data = try? JSONEncoder().encode(string),
              let literal = String(data: data, encoding: .utf8)
        else { return "\"\"" }
        return literal
    }

    private var settingsCSS: String
    private var flow: PageFlow
    private var transition: PageTransition
    private var pendingFraction: Double?
    private var pendingLocate: (query: String, occurrence: Int)?
    private var chapterAdvancePending = false
    private var navigationGeneration = 0

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
        navigationGeneration += 1
        pendingFraction = fraction
        pendingLocate = locate.map { (query: $0.0, occurrence: $0.1) }
        webView.alpha = 0
        webView.loadFileURL(url, allowingReadAccessTo: readAccessRoot)
    }

    func applySettings(
        css: String, backgroundColor: UIColor,
        flow: PageFlow, transition: PageTransition
    ) {
        navigationGeneration += 1
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
        navigationGeneration += 1
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

    // MARK: - Overscroll chapter advance

    /// The rubber-band overscroll happens at the UIScrollView level,
    /// invisible to the page's JS, so chapter-edge pulls are detected
    /// here from the drag's end position — vertically in scroll flow,
    /// horizontally past the first/last column in paged flow.
    nonisolated func scrollViewDidEndDragging(
        _ scrollView: UIScrollView, willDecelerate decelerate: Bool
    ) {
        MainActor.assumeIsolated {
            if flow == .scroll {
                let offset = scrollView.contentOffset.y
                let maxOffset = max(
                    0, scrollView.contentSize.height
                        - scrollView.bounds.height
                )
                if offset > maxOffset + Self.overscrollThreshold {
                    if onOverscroll?("forward") == true {
                        chapterAdvancePending = true
                    }
                } else if offset < -Self.overscrollThreshold {
                    if onOverscroll?("backward") == true {
                        chapterAdvancePending = true
                    }
                }
            } else {
                let offset = scrollView.contentOffset.x
                let maxOffset = max(
                    0, scrollView.contentSize.width
                        - scrollView.bounds.width
                )
                if offset > maxOffset + Self.overscrollThreshold {
                    // The advance starts loading the next chapter; a sync
                    // now would read the OLD chapter's rubber-band offset
                    // and persist stale state under the new spine index.
                    if onOverscroll?("forward") == true {
                        chapterAdvancePending = true
                    }
                    return
                } else if offset < -Self.overscrollThreshold {
                    if onOverscroll?("backward") == true {
                        chapterAdvancePending = true
                    }
                    return
                }
                // A drag that snaps back within the same page won't
                // decelerate, so sync here too: the engine's page must
                // never go stale before the next tap turn reads it.
                if !decelerate {
                    webView.evaluateJavaScript(
                        "window.lumen && window.lumen.syncPagedPage()"
                    )
                }
            }
        }
    }

    /// A finger drag must win over an in-flight programmatic tap-turn:
    /// freeze the scroll view at whatever offset the animation has
    /// reached (its presentation layer) and drop the animation, so the
    /// native pager tracks the finger from there instead of fighting it.
    nonisolated func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        MainActor.assumeIsolated {
            guard flow == .paged else { return }
            if let origin = scrollView.layer.presentation()?.bounds.origin {
                scrollView.setContentOffset(origin, animated: false)
            }
            scrollView.layer.removeAllAnimations()
        }
    }

    /// Native paging may settle the user on a different page than the
    /// engine thinks; re-read it from the scroll position.
    nonisolated func scrollViewDidEndDecelerating(
        _ scrollView: UIScrollView
    ) {
        MainActor.assumeIsolated {
            guard flow == .paged else { return }
            if chapterAdvancePending {
                // A hard edge pull can start the next chapter in
                // didEndDragging, then decelerate after rubber-band
                // settle; that late sync would read the old document under
                // the new spine index. At the first/last chapter the
                // overscroll callback returns false, so this flag is not set.
                return
            }
            webView.evaluateJavaScript(
                "window.lumen && window.lumen.syncPagedPage()"
            )
        }
    }

    // MARK: - Curl transition (tap turns)

    /// Non-nil while a curl animation is on screen.
    private var curlPageVC: UIPageViewController?
    private var curlSafetyTask: Task<Void, Never>?

    /// Snapshot config capped at an effective 2× pixel density. Full 3×
    /// captures add ~1.5s latency and make the turn feel broken (Readest
    /// production finding); capped, the overlay mounts tens of ms after
    /// the tap. `snapshotWidth` is in POINTS (image px = points × screen
    /// scale), so shrink the point width on >2× screens.
    private var curlSnapshotConfiguration: WKSnapshotConfiguration {
        let configuration = WKSnapshotConfiguration()
        let scale = UIScreen.main.scale
        if scale > 2 {
            configuration.snapshotWidth = NSNumber(
                value: Double(webView.bounds.width) * 2.0 / Double(scale)
            )
        }
        return configuration
    }

    /// Snapshot choreography: the page is a WKWebView with CSS columns, so
    /// live content can't curl. Instead: snapshot the old page, cover the
    /// webview with it, jump the scroll view to the target instantly
    /// underneath, snapshot the new page once WebKit painted it, then play
    /// a UIPageViewController page-curl between the two images and remove
    /// the overlay to reveal the live (already-turned) page.
    ///
    /// Known ceilings, accepted: a finger drag still slides natively in
    /// curl mode (Kindle behaves the same — curl plays on tap only), and
    /// chapter-boundary turns use the loading veil, never a cross-document
    /// curl.
    private func performCurl(to target: CGPoint) {
        let scroll = webView.scrollView
        let generation = navigationGeneration
        // One curl at a time: a second tap mid-curl is dropped
        // (responsiveness over fidelity for rapid tappers). The engine
        // already advanced its page for the dropped turn, so resync it to
        // the real offset to keep state consistent.
        guard curlPageVC == nil else {
            evaluate("window.lumen && window.lumen.syncPagedPage()")
            return
        }
        let forward = target.x > scroll.contentOffset.x
        webView.takeSnapshot(with: curlSnapshotConfiguration) {
            [weak self] oldImage, _ in
            guard let self else { return }
            guard generation == self.navigationGeneration else { return }
            guard let oldImage else {
                // Snapshot failed: degrade to an instant jump.
                scroll.setContentOffset(target, animated: false)
                return
            }
            // Cover the webview with the old page BEFORE jumping, so the
            // new page never flashes ahead of the curl.
            let pageVC = self.beginCurlOverlay(oldImage: oldImage)
            scroll.setContentOffset(target, animated: false)
            // Give WebKit a beat to paint the target column before
            // capturing it; snapshotting too early yields a blank page.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                [weak self] in
                guard let self else { return }
                guard generation == self.navigationGeneration else {
                    self.dismissCurl(pageVC)
                    return
                }
                self.webView.takeSnapshot(
                    with: self.curlSnapshotConfiguration
                ) { newImage, _ in
                    guard generation == self.navigationGeneration else {
                        self.dismissCurl(pageVC)
                        return
                    }
                    guard let newImage else {
                        // Live page is already on target; just reveal it.
                        self.dismissCurl(pageVC)
                        return
                    }
                    pageVC.setViewControllers(
                        [Self.snapshotViewController(newImage)],
                        direction: forward ? .forward : .reverse,
                        animated: true
                    ) { [weak self] _ in
                        guard let self else { return }
                        guard generation == self.navigationGeneration else {
                            self.dismissCurl(pageVC)
                            return
                        }
                        self.dismissCurl(pageVC)
                    }
                }
            }
        }
    }

    /// Builds the curl overlay seeded with the old page and installs it
    /// over the webview (under the SwiftUI chrome, which lives outside
    /// this container). Arms a safety timeout so a dropped completion can
    /// never leave the overlay stuck — same pattern as the chapter veil.
    private func beginCurlOverlay(oldImage: UIImage) -> UIPageViewController {
        let pageVC = UIPageViewController(
            transitionStyle: .pageCurl, navigationOrientation: .horizontal
        )
        pageVC.view.frame = webView.bounds
        pageVC.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        pageVC.view.backgroundColor = webView.backgroundColor
        // No dataSource → no curl gestures; the view itself still swallows
        // taps so a tap mid-curl can't reach the page's tap zones.
        pageVC.view.isUserInteractionEnabled = true
        pageVC.setViewControllers(
            [Self.snapshotViewController(oldImage)],
            direction: .forward, animated: false
        )
        // Transient (<1s) portrait-locked iPhone-only overlay: UIKit
        // trait/containment forwarding is intentionally omitted. Revisit
        // before iPad or rotation support lands.
        webView.addSubview(pageVC.view)
        curlPageVC = pageVC
        curlSafetyTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            self?.dismissCurl(pageVC)
        }
        return pageVC
    }

    private func dismissCurl(_ pageVC: UIPageViewController) {
        guard curlPageVC === pageVC else { return }
        curlSafetyTask?.cancel()
        curlSafetyTask = nil
        pageVC.view.removeFromSuperview()
        curlPageVC = nil
    }

    /// A throwaway VC showing one page snapshot, for the curl pager.
    private static func snapshotViewController(
        _ image: UIImage
    ) -> UIViewController {
        let vc = UIViewController()
        let imageView = UIImageView(image: image)
        imageView.frame = vc.view.bounds
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        vc.view.addSubview(imageView)
        return vc
    }

    // MARK: - Engine messages

    /// Fire-and-forget JS eval. Routing through a synchronous method keeps the
    /// "use the async alternative" suggestion from firing when called inside an
    /// async `Task`, while preserving the existing non-awaiting behaviour.
    private func evaluate(_ javaScript: String) {
        webView.evaluateJavaScript(javaScript, completionHandler: nil)
    }

    nonisolated func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        // WebKit invokes this handler on the main thread; `message.body` is
        // main-actor isolated, so read it via `assumeIsolated` before hopping
        // off to the (also main-actor) Task below.
        let rawBody = MainActor.assumeIsolated { message.body }
        guard let body = rawBody as? [String: Any],
              let type = body["type"] as? String else { return }
        let page = body["page"] as? Int ?? 0
        let pageCount = body["pageCount"] as? Int ?? 1
        let zone = body["zone"] as? String
        let scrollX = body["x"] as? Double
        let scrollY = body["y"] as? Double
        let animate = body["animate"] as? Bool ?? false

        Task { @MainActor in
            switch type {
            case "ready":
                self.navigationGeneration += 1
                self.chapterAdvancePending = false
                // Reset the scroll position before revealing so a stale
                // offset left by the previous chapter can never flash an
                // empty page; goToFraction below sets the precise target.
                self.webView.scrollView.setContentOffset(.zero, animated: false)
                if let locate = self.pendingLocate {
                    self.pendingLocate = nil
                    self.pendingFraction = nil
                    self.evaluate(
                        """
                        window.lumen.locate(\
                        \(Self.jsStringLiteral(locate.query)), \
                        \(locate.occurrence))
                        """
                    )
                } else {
                    let fraction = self.pendingFraction ?? 0
                    self.pendingFraction = nil
                    self.evaluate(
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
            case "scroll":
                // The engine requests a horizontal page move; drive the
                // native scroll view directly (reliable, unlike a JS
                // scrollTo) so the destination page is actually painted.
                if let scrollX {
                    let target = CGPoint(x: scrollX, y: 0)
                    let scroll = self.webView.scrollView
                    if animate, self.transition == .curl {
                        self.performCurl(to: target)
                    } else if animate {
                        // A critically-damped spring (damping 1.0 → no
                        // overshoot) departs quickly and settles softly, the
                        // Apple Books tap-turn feel. `.beginFromCurrentState`
                        // lets a rapid second tap retarget mid-glide instead
                        // of snapping; `.allowUserInteraction` keeps a drag
                        // able to take over. The inner
                        // `setContentOffset(animated: false)` lets the spring
                        // own the motion.
                        UIView.animate(
                            withDuration: 0.42, delay: 0,
                            usingSpringWithDamping: 1.0,
                            initialSpringVelocity: 0.6,
                            options: [.allowUserInteraction, .beginFromCurrentState]
                        ) {
                            scroll.setContentOffset(target, animated: false)
                        }
                    } else {
                        scroll.setContentOffset(target, animated: false)
                    }
                }
            case "scrollV":
                // Scroll-flow tap advance: glide the native scroll view
                // vertically. Same critically-damped spring as the paged turn
                // so a tap-to-advance feels smooth, not the steppy JS
                // smooth-scroll.
                if let scrollY {
                    let scroll = self.webView.scrollView
                    let target = CGPoint(x: 0, y: scrollY)
                    UIView.animate(
                        withDuration: 0.42, delay: 0,
                        usingSpringWithDamping: 1.0,
                        initialSpringVelocity: 0.6,
                        options: [.allowUserInteraction, .beginFromCurrentState]
                    ) {
                        scroll.setContentOffset(target, animated: false)
                    }
                }
            default:
                break
            }
        }
    }
}
