import Foundation
import Observation
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
    private(set) var status: PurchaseStatus = .idle

    @ObservationIgnored
    private var hasPrepared = false

    @ObservationIgnored
    private let entitlementOverride: Bool

    init(isPro: Bool = false) {
        self.isPro = isPro
        self.entitlementOverride = isPro
    }

    func prepare() async {
        guard !hasPrepared else { return }
        hasPrepared = true
        isLoading = true

        do {
            product = try await Product.products(for: [Self.proProductID]).first
        } catch {
            product = nil
        }

        await refreshEntitlements()
        isLoading = false
    }

    func observeTransactionUpdates() async {
        for await result in Transaction.updates {
            guard case let .verified(transaction) = result else { continue }
            await refreshEntitlements()
            await transaction.finish()
        }
    }

    func purchase() async throws {
        guard let product else { throw PurchaseIssue.productUnavailable }
        isPurchasing = true
        status = .idle
        defer { isPurchasing = false }

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
}

extension PurchaseManager {
    static var previewFree: PurchaseManager { PurchaseManager() }
    static var previewPro: PurchaseManager { PurchaseManager(isPro: true) }
}
