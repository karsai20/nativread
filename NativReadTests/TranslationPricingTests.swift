import XCTest
@testable import NativRead

/// The price table is what lets the sheet name a price without an upload, so
/// these pin the two things that would make it lie: the tier boundaries the
/// server also uses, and the version gate that stops a stale port from pricing
/// anything at all.
final class TranslationPricingTests: XCTestCase {

    /// The exact body `GET /api/pricing` returns — field names included, since
    /// a rename on either side silently costs every reader their instant price.
    private static let payload = """
    {
      "quoteVersion": "source-chars-v1",
      "charactersPerCredit": 1000,
      "tiers": [
        {"tier": 1, "maxSourceCharacters": 150000, "productId": "com.karsai.nativread.book.t1"},
        {"tier": 2, "maxSourceCharacters": 300000, "productId": "com.karsai.nativread.book.t2"},
        {"tier": 3, "maxSourceCharacters": 500000, "productId": "com.karsai.nativread.book.t3"},
        {"tier": 4, "maxSourceCharacters": 800000, "productId": "com.karsai.nativread.book.t4"},
        {"tier": 5, "maxSourceCharacters": 1200000, "productId": "com.karsai.nativread.book.t5"},
        {"tier": 6, "maxSourceCharacters": 3000000, "productId": "com.karsai.nativread.book.t6"}
      ]
    }
    """

    private func decoded() throws -> TranslationPricing {
        try JSONDecoder().decode(
            TranslationPricing.self,
            from: XCTUnwrap(Self.payload.data(using: .utf8))
        )
    }

    func testDecodesTheEndpointPayload() throws {
        let pricing = try decoded()

        XCTAssertEqual(pricing.quoteVersion, "source-chars-v1")
        XCTAssertEqual(pricing.charactersPerCredit, 1_000)
        XCTAssertEqual(pricing.tiers.count, 6)
        XCTAssertEqual(pricing.productIDs.first, "com.karsai.nativread.book.t1")
        XCTAssertEqual(pricing.productIDs.last, "com.karsai.nativread.book.t6")
    }

    /// Mirrors `bookTierFor` in the Worker: the first tier the book fits into,
    /// with the limit itself still inside the cheaper tier.
    func testPicksTheFirstTierTheBookFitsInto() throws {
        let pricing = try decoded()

        XCTAssertEqual(pricing.tier(forSourceCharacters: 1)?.tier, 1)
        XCTAssertEqual(pricing.tier(forSourceCharacters: 150_000)?.tier, 1)
        XCTAssertEqual(pricing.tier(forSourceCharacters: 150_001)?.tier, 2)
        XCTAssertEqual(pricing.tier(forSourceCharacters: 3_000_000)?.tier, 6)
    }

    func testHasNoTierForABookLongerThanTheTopBand() throws {
        let pricing = try decoded()

        XCTAssertNil(pricing.tier(forSourceCharacters: 3_000_001))
        XCTAssertTrue(pricing.exceedsLongestTier(sourceCharacters: 3_000_001))
        XCTAssertFalse(pricing.exceedsLongestTier(sourceCharacters: 3_000_000))
    }

    /// A book 483 characters over the first boundary is a real Gutenberg
    /// edition of Alice, not a contrived case — so the boundary is pinned with
    /// its actual number.
    func testPricesTheBookThatSitsJustOverTheFirstBoundary() throws {
        let pricing = try decoded()

        XCTAssertEqual(
            pricing.tier(forSourceCharacters: 150_483)?.productId,
            "com.karsai.nativread.book.t2"
        )
    }

    func testMatchesTheCounterOnlyWhenTheVersionsAgree() throws {
        XCTAssertTrue(try decoded().matchesLocalCounter)

        let stale = TranslationPricing(
            quoteVersion: "source-chars-v0",
            charactersPerCredit: 1_000,
            tiers: try decoded().tiers
        )

        XCTAssertFalse(stale.matchesLocalCounter)
    }
}

/// The pricing copy is the one place a Hungarian reader is told what they are
/// about to pay, so an untranslated fallback there is a real defect. These
/// assert the catalog key the compiler generates actually resolves — the two
/// drift apart silently whenever an interpolation is added or reworded.
final class PricingCopyLocalizationTests: XCTestCase {

    private func hungarian(_ key: String) throws -> String {
        let path = try XCTUnwrap(
            Bundle.main.path(forResource: "hu", ofType: "lproj"),
            "the Hungarian bundle is missing"
        )
        let bundle = try XCTUnwrap(Bundle(path: path))
        return bundle.localizedString(forKey: key, value: "MISSING", table: nil)
    }

    func testPricingCopyIsTranslated() throws {
        for key in [
            "This book is longer than we can translate.",
            "This book's price is %@. Tap again to buy it.",
            "Books cost %@ to %@, by length.",
            "up to ~%@ pages",
        ] {
            let translated = try hungarian(key)
            XCTAssertNotEqual(
                translated, "MISSING", "\(key) has no Hungarian translation"
            )
            XCTAssertNotEqual(
                translated, key, "\(key) fell back to the English source"
            )
        }
    }
}

@MainActor
final class PricingStoreTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() async throws {
        suiteName = "pricing-store-\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func makeStore() -> PricingStore {
        PricingStore(defaults: defaults) { nil }
    }

    private func pricing(quoteVersion: String) -> TranslationPricing {
        TranslationPricing(
            quoteVersion: quoteVersion,
            charactersPerCredit: 1_000,
            tiers: [
                .init(
                    tier: 1, maxSourceCharacters: 150_000,
                    productId: "com.karsai.nativread.book.t1"
                )
            ]
        )
    }

    private func persist(_ pricing: TranslationPricing) throws {
        defaults.set(
            try JSONEncoder().encode(pricing), forKey: "nativread.pricing.v1"
        )
        defaults.set(Date.now, forKey: "nativread.pricing.fetchedAt.v1")
    }

    func testHasNothingToPriceWithBeforeAnythingIsFetched() {
        XCTAssertNil(makeStore().usablePricing)
    }

    func testUsesACachedTableWithoutTheNetwork() throws {
        try persist(pricing(quoteVersion: TranslationQuote.version))

        XCTAssertEqual(makeStore().usablePricing?.tiers.count, 1)
    }

    /// The gate that matters: a table published for counting rules this build
    /// does not implement must not price anything, or the reader is quoted a
    /// number the server will not honour.
    func testRefusesToPriceWhenTheServerChangedTheCountingRules() throws {
        try persist(pricing(quoteVersion: "source-chars-v99"))

        let store = makeStore()

        XCTAssertNotNil(store.pricing, "the table is still cached")
        XCTAssertNil(store.usablePricing, "but nothing may be priced with it")
    }

    func testResetClearsTheCachedTable() throws {
        try persist(pricing(quoteVersion: TranslationQuote.version))

        PricingStore.resetPersisted(in: defaults)

        XCTAssertNil(makeStore().pricing)
    }
}
