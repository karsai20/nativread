import XCTest
@testable import NativRead

/// CEO D3.3 / E8: the review prompt fires only at peak-happiness (first
/// finished translated book, or third finished book for just-readers),
/// at most once ever, and never from error paths (callers only invoke it
/// on the not-finished → finished transition).
final class ReviewPromptPolicyTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "review-prompt-tests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private var policy: ReviewPromptPolicy {
        ReviewPromptPolicy(defaults: defaults)
    }

    func testFiresOnFirstFinishedTranslatedBook() {
        XCTAssertTrue(policy.registerFinishedBook(isTranslated: true))
    }

    func testDoesNotFireOnFirstOrSecondOriginalBook() {
        XCTAssertFalse(policy.registerFinishedBook(isTranslated: false))
        XCTAssertFalse(policy.registerFinishedBook(isTranslated: false))
    }

    func testFiresOnThirdFinishedBookForJustReaders() {
        XCTAssertFalse(policy.registerFinishedBook(isTranslated: false))
        XCTAssertFalse(policy.registerFinishedBook(isTranslated: false))
        XCTAssertTrue(policy.registerFinishedBook(isTranslated: false))
    }

    func testFiresOnceEver() {
        XCTAssertTrue(policy.registerFinishedBook(isTranslated: true))
        XCTAssertFalse(policy.registerFinishedBook(isTranslated: true))
        XCTAssertFalse(policy.registerFinishedBook(isTranslated: false))
        XCTAssertFalse(policy.registerFinishedBook(isTranslated: false))
        XCTAssertFalse(policy.registerFinishedBook(isTranslated: false))
    }

    func testFiredStatePersistsAcrossInstances() {
        XCTAssertTrue(policy.registerFinishedBook(isTranslated: true))

        let fresh = ReviewPromptPolicy(defaults: defaults)
        XCTAssertFalse(fresh.registerFinishedBook(isTranslated: true))
    }

    // MARK: - Picker gating (E8's other half)

    func testPickerOffersOnlyQualityGatePassedLanguages() {
        // Hungarian is the only language with a dated go/no-go pass.
        // Adding a language here is a deliberate release decision
        // (blueprint §3), never a side effect.
        XCTAssertEqual(TranslationTargetLanguage.passed, [.hu])
    }
}
