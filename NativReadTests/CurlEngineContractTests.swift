import JavaScriptCore
import XCTest
@testable import NativRead

/// Guards the Swift↔JS contract of the curl page turn. Swift evaluates
/// `window.lumen.curlBegin(...)` / `curlFailed(...)` and listens for a
/// `captureCurl` message; if either side renames its half, the turn
/// silently degrades. These names must exist in the injected engine.
final class CurlEngineContractTests: XCTestCase {

    private var engine: String {
        ReaderScripts.engine(
            pageWidth: 393, flow: .paged, transition: .curl
        )
    }

    func testEngineSpeaksCurlProtocol() {
        for token in [
            "captureCurl",     // JS → Swift: photograph the outgoing page
            "curlBegin(",      // Swift → JS: bitmap delivery entry point
            "curlFailed(",     // Swift → JS: capture failed, fall back
            "curlStart()",     // movePaged routes curl turns here
            "curlDragBegin(",  // touch handlers start a finger-scrubbed turn
            "edgeDrag"         // JS → Swift: chapter-edge pull in curl mode
        ] {
            XCTAssertTrue(
                engine.contains(token),
                "Engine lost its \(token) half of the curl protocol"
            )
        }
    }

    /// A syntax error anywhere in the engine string kills the whole
    /// reader (no pages, no taps), so parse every flow/transition
    /// combination with JavaScriptCore. `new Function` parses without
    /// executing — no DOM stubs needed.
    func testEngineParsesAsValidJavaScript() {
        let context = JSContext()!
        for flow in PageFlow.allCases {
            for transition in PageTransition.allCases {
                let source = ReaderScripts.engine(
                    pageWidth: 393, flow: flow, transition: transition
                )
                context.setObject(
                    source, forKeyedSubscript: "src" as NSString
                )
                context.exception = nil
                context.evaluateScript("new Function(src)")
                XCTAssertNil(
                    context.exception,
                    "Engine JS fails to parse for \(flow)/\(transition): "
                    + "\(context.exception?.toString() ?? "")"
                )
            }
        }
    }

    func testScrubCommitReassertsOffsetAfterTouchEnds() {
        // The drag scrub jumps the live page while a finger is still
        // down; WebKit can defer painting that column until the visible
        // rect is stable again. The commit settle must re-post the
        // offset once the touch has ended so the destination can never
        // stay blank until the next interaction.
        // Two sites must post this jump: the settle-safety fallback and
        // the commit-completion re-assert added for the blank-page fix.
        let token = "type: \"scroll\", x: this.page * PW, animate: false"
        let count = engine.components(separatedBy: token).count - 1
        XCTAssertGreaterThanOrEqual(
            count, 2,
            "Curl scrub commit lost its post-touch offset re-assert"
        )
    }

    func testCurlUndersideShowsFaintInkBleedThrough() {
        // The sheet's back face samples its OWN texcoord: the folded
        // geometry mirrors it on screen, so this reads as ink bleeding
        // through the paper. Reflecting the texcoord across the fold
        // (a past bug: "vMirror") cancels that geometric mirror and
        // shows readable, merely shifted text — guard against it.
        XCTAssertFalse(
            engine.contains("vMirror"),
            "Curl underside re-introduced the texcoord reflection that"
            + " cancels the geometric mirror"
        )
        XCTAssertTrue(
            engine.contains("mix(ink.rgb, uPaper, 0.9)"),
            "Curl underside lost its faint paper blend"
        )
    }

    /// A selection handle dragged towards the screen edge makes WebKit
    /// autoscroll the column scroller, parking a paged chapter between two
    /// columns. Nothing else snaps it back — no native drag ever happened
    /// — so the engine has to settle it when the finger lifts.
    func testSelectionAutoscrollSettlesBackOnAColumn() {
        for token in [
            "snapToColumn()",         // the settle itself
            "settleSelectionScroll",  // hooked to touchend/touchcancel
            "sel.isCollapsed"         // only while a selection is live
        ] {
            XCTAssertTrue(
                engine.contains(token),
                "Paged flow lost its \(token) selection-scroll settle"
            )
        }
        // Scroll flow has no columns to land on: the settle must stay out.
        XCTAssertTrue(
            ReaderScripts.engine(
                pageWidth: 393, flow: .scroll, transition: .slide
            ).contains("MODE !== \"paged\""),
            "Selection settle lost its paged-only gate"
        )
    }

    /// A swipe past the chapter end used to do nothing on the first try:
    /// a settling curl swallowed it, and a quick flick never reached the
    /// 70px distance gate. The edge pull must start through a live turn
    /// and commit on speed like an in-chapter turn.
    func testChapterEdgePullSurvivesALiveCurlAndCommitsOnFlick() {
        for token in [
            "atChapterEdge(",                                     // edge check shared by drag start
            "if (lumen.curlLive && !lumen.atChapterEdge(dx < 0))", // live turn only blocks in-chapter drags
            "edgeSpeed > 0.3"                                     // flick commits the edge pull
        ] {
            XCTAssertTrue(
                engine.contains(token),
                "Chapter-edge pull lost its \(token) rule"
            )
        }
    }

    /// A translated chapter whose footnote block overflowed the last column
    /// left its last page unreachable: the target sat past the scroll
    /// range, WebKit parked short of it (page shifted, previous column
    /// showing) and the next sync rounded back a page, so turns bounced.
    /// The engine must count overflow as a page and pin the scroll extent
    /// to whole pages.
    func testPagedLayoutPinsScrollExtentToWholePages() {
        for token in [
            "Math.ceil(total / PW - 0.02)",  // overflow is a page, not a sliver
            "lumen-extent",                  // the extent spacer
            "(this.pageCount * PW - 1)"      // parked at the last page's far edge
        ] {
            XCTAssertTrue(
                engine.contains(token),
                "Paged layout lost its \(token) extent rule"
            )
        }
    }

    func testCurlTurnsNeverRequestAnimatedScrollDirectly() {
        // The curl's instant jump must ride animate:false so Swift's
        // spring path can't fight the overlay animation.
        XCTAssertTrue(
            engine.contains("type: \"scroll\", x: x, animate: false"),
            "Curl overlay lost its instant under-jump"
        )
    }
}
