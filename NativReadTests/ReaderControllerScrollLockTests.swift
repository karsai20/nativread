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

    /// Only a settled position the reader actually chose may be written
    /// back as their progress. Persisting a mid-scroll sample, or the
    /// restore that has not landed yet, is what used to drop a reader
    /// back at the top of the chapter.
    func testOnlySettledPositionsArePersistable() {
        func state(
            restoring: Bool, atRest: Bool
        ) -> ReaderEngineState {
            ReaderEngineState(
                page: 3, pageCount: 10, fraction: 0.33,
                isRestoring: restoring, isAtRest: atRest
            )
        }

        XCTAssertTrue(state(restoring: false, atRest: true).isPersistable)
        XCTAssertFalse(state(restoring: true, atRest: true).isPersistable)
        XCTAssertFalse(state(restoring: false, atRest: false).isPersistable)
    }

    /// Scroll flow reports where the reader actually is, not the nearest
    /// whole screen — the rounding was losing up to half a page every
    /// time a chapter was reopened.
    func testScrollEngineReportsAContinuousFraction() {
        let engine = ReaderScripts.engine(
            pageWidth: 393, flow: .scroll, transition: .slide
        )
        XCTAssertTrue(engine.contains("scrollTop / max"))
        XCTAssertTrue(engine.contains("restoreTarget"))
    }

    func testViewportPreparationReplacesPortraitGeometry() {
        let controller = makeController(flow: .paged, transition: .slide)
        let landscape = CGSize(width: 852, height: 393)

        controller.prepareViewport(
            pageSize: landscape,
            css: "body { width: 852px; height: 393px; }"
        )

        XCTAssertEqual(controller.pageSize, landscape)
    }
}
