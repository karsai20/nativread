import SwiftUI
import WebKit

/// Thin wrapper: the web view is created and driven by ReaderController,
/// SwiftUI only places it in the hierarchy.
struct ReaderWebView: UIViewRepresentable {
    let controller: ReaderController
    let onViewportChange: (ReaderViewport) -> Void

    func makeUIView(context: Context) -> ReaderWebContainerView {
        ReaderWebContainerView(
            webView: controller.webView,
            onViewportChange: onViewportChange
        )
    }

    func updateUIView(
        _ uiView: ReaderWebContainerView,
        context: Context
    ) {
        uiView.onViewportChange = onViewportChange
    }
}

/// Reports the real laid-out reader size. `UIScreen.main.bounds` is not a
/// reliable source during rotation, while this container's bounds are exactly
/// the full-screen area occupied by the WKWebView.
final class ReaderWebContainerView: UIView {
    var onViewportChange: (ReaderViewport) -> Void

    private let webView: WKWebView
    private var lastReportedViewport: ReaderViewport?

    init(
        webView: WKWebView,
        onViewportChange: @escaping (ReaderViewport) -> Void
    ) {
        self.webView = webView
        self.onViewportChange = onViewportChange
        super.init(frame: webView.frame)
        addSubview(webView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func layoutSubviews() {
        super.layoutSubviews()
        webView.frame = bounds
        reportViewportIfNeeded()
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        reportViewportIfNeeded()
    }

    private func reportViewportIfNeeded() {
        // `ReaderWebView` deliberately renders edge-to-edge. On newer
        // iPhones that can make this container report zero safe-area insets
        // even though the window still has a landscape sensor-housing inset.
        // Use the stricter value so EPUB text never sits underneath hardware.
        let windowInsets = window?.safeAreaInsets ?? .zero
        let effectiveInsets = UIEdgeInsets(
            top: max(safeAreaInsets.top, windowInsets.top),
            left: max(safeAreaInsets.left, windowInsets.left),
            bottom: max(safeAreaInsets.bottom, windowInsets.bottom),
            right: max(safeAreaInsets.right, windowInsets.right)
        )
        let viewport = ReaderViewport(
            size: bounds.size,
            safeAreaInsets: effectiveInsets
        )
        guard viewport.size.width > 0, viewport.size.height > 0,
              viewport != lastReportedViewport else { return }
        lastReportedViewport = viewport
        onViewportChange(viewport)
    }
}

/// Geometry that changes the EPUB layout. Horizontal safe-area insets matter
/// in landscape because the web view intentionally extends behind the sensor
/// housing and home-indicator edge while the text itself must not.
struct ReaderViewport: Equatable {
    let size: CGSize
    let safeAreaInsets: UIEdgeInsets
}
