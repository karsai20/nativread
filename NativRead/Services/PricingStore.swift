import Foundation
import Observation

/// Holds the backend's price table so the translation sheet can name a book's
/// price the moment it opens, instead of after an upload.
///
/// Cached in `UserDefaults`: the table is a few hundred bytes and changes about
/// as often as prices do, so a reader who has opened the app once is never made
/// to wait for it again. Nothing is bundled as a fallback on purpose — a table
/// shipped in the binary would go stale silently, and showing a price that is
/// no longer the one charged is worse than showing none.
@MainActor
@Observable
final class PricingStore {

    /// How long a cached table is used before a refresh is attempted. Matches
    /// the `max-age` the endpoint itself sends.
    static let maximumAge: TimeInterval = 3600

    private(set) var pricing: TranslationPricing?

    private let defaults: UserDefaults
    private let makeClient: @MainActor () -> TranslationBackendClient?
    private var fetchedAt: Date?
    private var inFlight: Task<Void, Never>?

    private static let pricingKey = "nativread.pricing.v1"
    private static let fetchedAtKey = "nativread.pricing.fetchedAt.v1"

    init(
        defaults: UserDefaults = .standard,
        makeClient: @escaping @MainActor () -> TranslationBackendClient?
    ) {
        self.defaults = defaults
        self.makeClient = makeClient
        if let data = defaults.data(forKey: Self.pricingKey),
           let decoded = try? JSONDecoder().decode(
               TranslationPricing.self, from: data
           ) {
            pricing = decoded
            fetchedAt = defaults.object(forKey: Self.fetchedAtKey) as? Date
        }
    }

    /// The table to price with, or `nil` when there is nothing trustworthy to
    /// price with — no table yet, or one published for counting rules this
    /// build does not implement.
    var usablePricing: TranslationPricing? {
        guard let pricing, pricing.matchesLocalCounter else { return nil }
        return pricing
    }

    /// Fetches the table when there is none or the cached one has aged out.
    ///
    /// Awaitable on purpose: a caller that is about to price something has to
    /// be able to wait for the table, or it reads an empty one and falls back
    /// to an upload it did not need. A second caller joins the request already
    /// in flight rather than starting another.
    ///
    /// A failure is silent by design — the sheet falls back to quoting the book
    /// through an upload, which is the path that existed before this cache.
    func refreshIfStale() async {
        if let inFlight {
            await inFlight.value
            return
        }
        if let fetchedAt, Date.now.timeIntervalSince(fetchedAt) < Self.maximumAge,
           pricing != nil {
            return
        }
        guard let client = makeClient() else { return }
        let task = Task { [weak self] in
            guard let fetched = try? await client.pricing() else { return }
            self?.store(fetched)
        }
        inFlight = task
        await task.value
        inFlight = nil
    }

    private func store(_ fetched: TranslationPricing) {
        pricing = fetched
        fetchedAt = .now
        if let data = try? JSONEncoder().encode(fetched) {
            defaults.set(data, forKey: Self.pricingKey)
            defaults.set(fetchedAt, forKey: Self.fetchedAtKey)
        }
    }

    /// Wipes the cached table; used by the `-resetSettings` launch argument so
    /// UI tests start from a known state.
    static func resetPersisted(in defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: pricingKey)
        defaults.removeObject(forKey: fetchedAtKey)
    }
}
