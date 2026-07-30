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

    /// Which book a transaction paid for. A receipt names only a price tier, so
    /// without this a purchase interrupted by a relaunch could never be matched
    /// back to its book. It outlives the process for exactly that reason.
    private static let pendingKey = "nativread.pendingPurchases.v1"

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
        jobID: String,
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
            rememberJob(jobID, for: transaction.id)
            try await confirm(transaction, jobID: jobID)
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
                try? await self.confirm(transaction, jobID: nil)
            }
        }
    }

    private func confirmUnfinishedTransactions() async {
        for await unfinished in Transaction.unfinished {
            guard let transaction = try? verified(unfinished) else { continue }
            try? await confirm(transaction, jobID: nil)
        }
    }

    /// Finishing before the server has the receipt would drop the only proof the
    /// customer paid, so the order here is deliberate.
    private func confirm(_ transaction: Transaction, jobID: String?) async throws {
        guard let jobID = jobID ?? pendingJobs[String(transaction.id)] else {
            // Nothing local ties this transaction to a book. Leaving it
            // unfinished keeps it in Transaction.unfinished for a later attempt.
            return
        }
        guard let client = makeClient() else { return }
        _ = try await client.confirmPurchase(
            jobID: jobID,
            transactionID: String(transaction.id)
        )
        await transaction.finish()
        forgetJob(for: transaction.id)
    }

    private var pendingJobs: [String: String] {
        defaults.dictionary(forKey: Self.pendingKey) as? [String: String] ?? [:]
    }

    private func rememberJob(_ jobID: String, for transactionID: UInt64) {
        defaults.set(
            pendingJobs.merging([String(transactionID): jobID]) { _, new in new },
            forKey: Self.pendingKey
        )
    }

    private func forgetJob(for transactionID: UInt64) {
        var pending = pendingJobs
        pending.removeValue(forKey: String(transactionID))
        defaults.set(pending, forKey: Self.pendingKey)
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
