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
            "captureCurl",   // JS → Swift: photograph the outgoing page
            "curlBegin(",    // Swift → JS: bitmap delivery entry point
            "curlFailed(",   // Swift → JS: capture failed, fall back
            "curlStart()"    // movePaged routes curl turns here
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

    func testCurlTurnsNeverRequestAnimatedScrollDirectly() {
        // The curl's instant jump must ride animate:false so Swift's
        // spring path can't fight the overlay animation.
        XCTAssertTrue(
            engine.contains("type: \"scroll\", x: x, animate: false"),
            "Curl overlay lost its instant under-jump"
        )
    }
}
