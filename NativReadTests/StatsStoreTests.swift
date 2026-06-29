import XCTest
@testable import NativRead

@MainActor
final class StatsStoreTests: XCTestCase {

    private var root: URL!

    override func setUp() async throws {
        root = try EPUBFixtures.makeTempDirectory()
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func makeStore() -> StatsStore {
        StatsStore(rootDirectory: root.appendingPathComponent("stats"))
    }

    func testRecordAccumulatesAndIgnoresNonPositive() {
        let store = makeStore()
        store.record(seconds: 120)
        store.record(seconds: 0)
        store.record(seconds: -30)
        store.record(seconds: 60)

        XCTAssertEqual(store.stats.totalSeconds, 180, accuracy: 0.001)
    }

    func testRecordClampsAbsurdSession() {
        let store = makeStore()
        // Twelve hours — an app left open. Clamped to the cap.
        store.record(seconds: 12 * 60 * 60)

        XCTAssertEqual(
            store.stats.totalSeconds,
            StatsStore.maxSessionSeconds,
            accuracy: 0.001
        )
    }

    func testStatsStorePersistsAcrossInstances() {
        let store = makeStore()
        store.record(seconds: 300)

        let reloaded = makeStore()

        XCTAssertEqual(reloaded.stats.totalSeconds, 300, accuracy: 0.001)
    }
}
