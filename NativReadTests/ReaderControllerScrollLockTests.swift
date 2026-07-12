import XCTest
@testable import NativRead

/// Curl mode hands horizontal drags to the page's touch handlers, which
/// only receive them while the scroll view's native pan is disabled.
/// Every other flow/transition must keep the native pan — losing it
/// there would kill swiping entirely.
@MainActor
final class ReaderControllerScrollLockTests: XCTestCase {

    private func makeController(
        flow: PageFlow, transition: PageTransition
    ) -> ReaderController {
        ReaderController(
            pageSize: CGSize(width: 393, height: 852),
            initialCSS: "",
            backgroundColor: .white,
            flow: flow,
            transition: transition
        )
    }

    func testCurlModeDisablesNativePan() {
        let controller = makeController(flow: .paged, transition: .curl)
        XCTAssertFalse(controller.webView.scrollView.isScrollEnabled)
    }

    func testOtherTransitionsKeepNativePan() {
        for transition in PageTransition.allCases where transition != .curl {
            let controller = makeController(
                flow: .paged, transition: transition
            )
            XCTAssertTrue(
                controller.webView.scrollView.isScrollEnabled,
                "\(transition) must keep the native pager swipeable"
            )
        }
    }

    func testScrollFlowKeepsNativePanEvenWithCurlSetting() {
        let controller = makeController(flow: .scroll, transition: .curl)
        XCTAssertTrue(controller.webView.scrollView.isScrollEnabled)
    }

    /// A transparent WKWebView forces blended tile compositing, which
    /// visibly drops scroll-flow frame rate — the webview must stay
    /// opaque with the theme paper behind it.
    func testWebViewIsOpaqueWithPaperBackground() {
        let controller = makeController(flow: .scroll, transition: .slide)
        XCTAssertTrue(controller.webView.isOpaque)
        XCTAssertEqual(controller.webView.backgroundColor, .white)
        XCTAssertEqual(
            controller.webView.scrollView.backgroundColor, .white
        )
    }

    func testApplySettingsTogglesPanLock() {
        let controller = makeController(flow: .paged, transition: .slide)
        controller.applySettings(
            css: "", backgroundColor: .white,
            flow: .paged, transition: .curl
        )
        XCTAssertFalse(controller.webView.scrollView.isScrollEnabled)
        controller.applySettings(
            css: "", backgroundColor: .white,
            flow: .paged, transition: .slide
        )
        XCTAssertTrue(controller.webView.scrollView.isScrollEnabled)
    }
}
