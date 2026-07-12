import UIKit
import XCTest
@testable import NativRead

/// The Define sheet's dictionary host must NOT build the reference
/// library during creation (that blocks the main thread mid-sheet
/// animation) and MUST embed it as a proper child once the view has
/// appeared — the regression was a blank dictionary until a scroll
/// forced layout.
@MainActor
final class SystemDictionaryHostTests: XCTestCase {

    func testNoDictionaryChildBeforeAppearance() {
        let host = SystemDictionaryHostController(term: "lantern")
        host.loadViewIfNeeded()
        XCTAssertTrue(
            host.children.isEmpty,
            "Reference library must not be built before the sheet settles"
        )
    }

    func testEmbedsReferenceLibraryOnceOnAppear() {
        let host = SystemDictionaryHostController(term: "lantern")
        host.loadViewIfNeeded()
        host.viewDidAppear(false)
        XCTAssertEqual(host.children.count, 1)
        XCTAssertTrue(
            host.children.first is UIReferenceLibraryViewController
        )
        XCTAssertEqual(
            host.children.first?.view.superview, host.view,
            "Child containment requires the child's view in the host"
        )
        // A second appearance (sheet detent change) must not stack a
        // duplicate dictionary.
        host.viewDidAppear(false)
        XCTAssertEqual(host.children.count, 1)
    }
}
