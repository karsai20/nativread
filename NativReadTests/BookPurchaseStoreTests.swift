import XCTest
@testable import NativRead

/// What a StoreKit transaction paid for has to survive a relaunch, or an
/// interrupted purchase can never be handed to the backend.
@MainActor
final class BookPurchaseStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suite = "BookPurchaseStoreTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    private func makeStore() -> BookPurchaseStore {
        BookPurchaseStore(defaults: defaults, makeClient: { nil })
    }

    func testABookPaidForBeforeUploadIsRememberedAcrossLaunches() {
        let target = PurchaseTarget.book(
            sourceHash: String(repeating: "c", count: 64),
            targetLanguage: "hu",
            productID: "com.karsai.nativread.book.t3"
        )
        makeStore().rememberTarget(target, for: 42)

        XCTAssertEqual(makeStore().pendingTarget(for: 42), target)
        XCTAssertNil(makeStore().pendingTarget(for: 43))
    }

    func testAJobRememberedByAnOlderBuildIsStillReplayed() {
        defaults.set(["7": "job-7"], forKey: "nativread.pendingPurchases.v1")

        XCTAssertEqual(makeStore().pendingTarget(for: 7), .job("job-7"))
    }

    func testForgettingATransactionDropsIt() {
        let store = makeStore()
        store.rememberTarget(.job("job-1"), for: 1)
        store.forgetTarget(for: 1)

        XCTAssertNil(makeStore().pendingTarget(for: 1))
    }
}
