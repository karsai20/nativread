import Foundation
import StoreKit

/// Buys one book's translation and hands the receipt to the backend.
///
/// The server is the only authority on what was bought: it verifies the
/// transaction with Apple and records the entitlement. A transaction is finished
/// only after the server confirms it, so a purchase interrupted by a dead network
/// is replayed on the next launch instead of being lost.
@MainActor
@Observable
final class BookPurchaseStore {
    enum PurchaseOutcome: Equatable {
        case entitled
        case cancelled
        /// Ask to Buy or another deferred approval; the entitlement arrives later.
        case pending
    }

    enum PurchaseError: LocalizedError {
        case productUnavailable
        case unverifiedTransaction

        var errorDescription: String? {
            switch self {
            case .productUnavailable:
                return String(
                    localized: "This translation is not available for purchase right now."
                )
            case .unverifiedTransaction:
                return String(
                    localized: "The App Store could not verify this purchase."
                )
            }
        }
    }

    private(set) var isPurchasing = false

    private var updates: Task<Void, Never>?
    private let makeClient: @MainActor () -> TranslationBackendClient?
    private let defaults: UserDefaults

    /// What a transaction paid for. A receipt names only a price tier, so
    /// without this a purchase interrupted by a relaunch could never be matched
    /// back to its book. It outlives the process for exactly that reason.
    private static let pendingKey = "nativread.pendingPurchases.v2"
    /// Transaction → job id, written by builds that uploaded before paying.
    /// Read so their unfinished purchases still reach the backend.
    private static let legacyPendingKey = "nativread.pendingPurchases.v1"

    init(
        defaults: UserDefaults = .standard,
        makeClient: @escaping @MainActor () -> TranslationBackendClient?
    ) {
        self.defaults = defaults
        self.makeClient = makeClient
    }

    func product(for productID: String) async throws -> Product {
        guard let product = try await Product.products(for: [productID]).first else {
            throw PurchaseError.productUnavailable
        }
        return product
    }

    func purchase(
        _ product: Product,
        for target: PurchaseTarget,
        appAccountToken: UUID
    ) async throws -> PurchaseOutcome {
        isPurchasing = true
        defer { isPurchasing = false }

        let result = try await product.purchase(
            options: [.appAccountToken(appAccountToken)]
        )
        switch result {
        case .success(let verification):
            let transaction = try verified(verification)
            rememberTarget(target, for: transaction.id)
            try await confirm(transaction, target: target)
            return .entitled
        case .userCancelled:
            return .cancelled
        case .pending:
            return .pending
        @unknown default:
            return .pending
        }
    }

    /// Replays anything the App Store still considers unfinished — a purchase
    /// approved after Ask to Buy, or one whose confirmation never reached us.
    func startObservingTransactions() {
        guard updates == nil else { return }
        updates = Task { [weak self] in
            await self?.confirmUnfinishedTransactions()
            for await update in Transaction.updates {
                guard let self else { return }
                guard let transaction = try? self.verified(update) else { continue }
                try? await self.confirm(transaction, target: nil)
            }
        }
    }

    /// Hands the backend any purchase the App Store charged but we never
    /// confirmed. Run before a new purchase: without it, a receipt lost to a
    /// dropped connection leaves the book looking unowned, and paying "again"
    /// charges the reader twice.
    func confirmUnfinishedTransactions() async {
        for await unfinished in Transaction.unfinished {
            guard let transaction = try? verified(unfinished) else { continue }
            try? await confirm(transaction, target: nil)
        }
    }

    /// Finishing before the server has the receipt would drop the only proof the
    /// customer paid, so the order here is deliberate.
    private func confirm(_ transaction: Transaction, target: PurchaseTarget?) async throws {
        guard let target = target ?? pendingTarget(for: transaction.id) else {
            // Nothing local ties this transaction to a book. Leaving it
            // unfinished keeps it in Transaction.unfinished for a later attempt.
            return
        }
        guard let client = makeClient() else { return }
        _ = try await client.confirmPurchase(
            for: target,
            transactionID: String(transaction.id)
        )
        await transaction.finish()
        forgetTarget(for: transaction.id)
    }

    func pendingTarget(for transactionID: UInt64) -> PurchaseTarget? {
        let key = String(transactionID)
        if let target = pendingTargets[key] { return target }
        let legacy = defaults.dictionary(forKey: Self.legacyPendingKey) as? [String: String]
        return legacy?[key].map(PurchaseTarget.job)
    }

    func rememberTarget(_ target: PurchaseTarget, for transactionID: UInt64) {
        storePendingTargets(pendingTargets.merging([String(transactionID): target]) { _, new in new })
    }

    func forgetTarget(for transactionID: UInt64) {
        let key = String(transactionID)
        storePendingTargets(pendingTargets.filter { $0.key != key })
        if var legacy = defaults.dictionary(forKey: Self.legacyPendingKey) as? [String: String] {
            legacy.removeValue(forKey: key)
            defaults.set(legacy, forKey: Self.legacyPendingKey)
        }
    }

    private var pendingTargets: [String: PurchaseTarget] {
        guard let data = defaults.data(forKey: Self.pendingKey) else { return [:] }
        return (try? JSONDecoder().decode([String: PurchaseTarget].self, from: data)) ?? [:]
    }

    private func storePendingTargets(_ targets: [String: PurchaseTarget]) {
        // An encoding failure would lose the only link from a paid receipt to
        // its book, so it is not swallowed silently in a debug build.
        do {
            defaults.set(try JSONEncoder().encode(targets), forKey: Self.pendingKey)
        } catch {
            assertionFailure("Pending purchases failed to encode: \(error)")
        }
    }

    private func verified(_ result: VerificationResult<Transaction>) throws -> Transaction {
        switch result {
        case .verified(let transaction):
            return transaction
        case .unverified:
            throw PurchaseError.unverifiedTransaction
        }
    }
}
