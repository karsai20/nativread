import XCTest
import UIKit
@testable import NativRead

/// The welcome shelf draws cover art by asset name. A typo or a renamed
/// image fails silently at runtime — an empty gap drifting across the first
/// screen a reader ever sees — so the names are checked here instead.
final class OnboardingShelfTests: XCTestCase {

    /// The app bundle, not the test runner's: the covers live in the app's
    /// asset catalog.
    private let bundle = Bundle(for: LibraryStore.self)

    func testEveryCoverResolves() {
        for language in AppLanguage.allCases {
            let rows = OnboardingShelf.rows(for: language)
            for name in rows.top + rows.bottom {
                XCTAssertNotNil(
                    UIImage(named: name, in: bundle, compatibleWith: nil),
                    "Missing cover asset \(name) for \(language.rawValue)"
                )
            }
        }
    }

    /// The row widens a short list by repeating it, so any non-empty row
    /// drifts. Below four covers the repeat lands inside the screen and the
    /// same book is visible twice at once, which reads as a bug rather than
    /// as a shelf — three and three was tried on the Spanish shelf and had
    /// to be undone.
    func testEveryRowIsWideEnoughNotToRepeatOnScreen() {
        for language in AppLanguage.allCases {
            let rows = OnboardingShelf.rows(for: language)
            for (name, row) in [("top", rows.top), ("bottom", rows.bottom)] {
                XCTAssertGreaterThanOrEqual(
                    row.count, 4, "\(language.rawValue) \(name) row"
                )
                XCTAssertEqual(
                    Set(row).count, row.count,
                    "\(language.rawValue) \(name) row repeats a book"
                )
            }
        }
    }

    /// The demo only makes its point if the two languages differ: a page
    /// translated from English into English proves nothing.
    func testDemoAlwaysCrossesALanguageBoundary() {
        for language in AppLanguage.allCases {
            let passage = OnboardingDemoPassage.alice(readIn: language)
            XCTAssertNotEqual(
                passage.sourceEndonym,
                passage.targetEndonym,
                "\(language.rawValue) demo reads into its own language"
            )
            XCTAssertEqual(passage.lines.count, 3, "\(language.rawValue) demo lines")
            for line in passage.lines {
                XCTAssertNotEqual(line.source, line.target)
            }
        }
    }
}
