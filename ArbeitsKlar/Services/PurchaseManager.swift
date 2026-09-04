import Foundation
import Observation
import OSLog
import StoreKit

enum PurchaseIssue: Error {
    case productUnavailable
    case purchaseFailed
    case verificationFailed
    case restoreFailed

    var message: LocalizedStringResource {
        switch self {
        case .productUnavailable:
            return "pro.error.unavailable"
        case .purchaseFailed:
            return "pro.error.purchase"
        case .verificationFailed:
            return "pro.error.verification"
        case .restoreFailed:
            return "pro.error.restore"
        }
    }
}

enum PurchaseStatus: Equatable {
    case idle
    case pending
    case purchased
    case restored
}

@MainActor
@Observable
final class PurchaseManager {
    static let proProductID = "de.kamilunavo.arbeitsklar.pro.lifetime"

    private(set) var product: Product?
    private(set) var isPro: Bool
    private(set) var isLoading = false
    private(set) var isPurchasing = false
    private(set) var isPrepared = false
    private(set) var status: PurchaseStatus = .idle

    @ObservationIgnored
    private var hasPrepared = false

    @ObservationIgnored
    private let entitlementOverride: Bool

    @ObservationIgnored
    private let logger = Logger(
        subsystem: "de.kamilunavo.arbeitsklar",
        category: "StoreKit"
    )

    init(isPro: Bool = false) {
        self.isPro = isPro
        self.entitlementOverride = isPro
    }

    func prepare() async {
        guard !hasPrepared || product == nil else { return }
        hasPrepared = true
        isLoading = true

        await loadProduct()

        await refreshEntitlements()
        isLoading = false
        isPrepared = true
    }

    func observeTransactionUpdates() async {
        for await result in Transaction.updates {
            guard case let .verified(transaction) = result else { continue }
            await refreshEntitlements()
            await transaction.finish()
        }
    }

    func purchase() async throws {
        isPurchasing = true
        status = .idle
        defer { isPurchasing = false }

        // App Store sandbox metadata can briefly become stale after a build or
        // IAP change. Resolve a fresh Product immediately before presenting the
        // system purchase sheet instead of reusing launch-time metadata.
        await loadProduct()
        guard let product else { throw PurchaseIssue.productUnavailable }

        do {
            let result = try await product.purchase()
            switch result {
            case let .success(verification):
                guard case let .verified(transaction) = verification else {
                    throw PurchaseIssue.verificationFailed
                }
                await transaction.finish()
                await refreshEntitlements()
                status = .purchased
            case .pending:
                status = .pending
            case .userCancelled:
                status = .idle
            @unknown default:
                status = .idle
            }
        } catch let issue as PurchaseIssue {
            throw issue
        } catch {
            logger.error("Purchase failed: \(String(describing: error), privacy: .public)")
            throw PurchaseIssue.purchaseFailed
        }
    }

    func restore() async throws {
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            try await AppStore.sync()
            await refreshEntitlements()
            status = .restored
        } catch {
            throw PurchaseIssue.restoreFailed
        }
    }

    private func refreshEntitlements() async {
        var hasProEntitlement = false

        for await result in Transaction.currentEntitlements {
            guard case let .verified(transaction) = result else { continue }
            guard transaction.productID == Self.proProductID else { continue }
            guard transaction.revocationDate == nil, !transaction.isUpgraded else { continue }
            hasProEntitlement = true
        }

        isPro = hasProEntitlement || entitlementOverride
    }

    private func loadProduct() async {
        do {
            let products = try await Product.products(for: [Self.proProductID])
            product = products.first { $0.id == Self.proProductID }
            if product == nil {
                logger.error("Configured Pro product was not returned by the App Store")
            }
        } catch {
            product = nil
            logger.error("Product loading failed: \(String(describing: error), privacy: .public)")
        }
    }
}

extension PurchaseManager {
    static var previewFree: PurchaseManager { PurchaseManager() }
    static var previewPro: PurchaseManager { PurchaseManager(isPro: true) }
}
