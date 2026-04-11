import Foundation
import StoreKit
import SwiftUI

@MainActor
final class SubscriptionManager: ObservableObject {

    static let shared = SubscriptionManager()

    enum Constants {
        static let monthlyProductID = "com.flowapp.pro.monthly"
        static let yearlyProductID = "com.flowapp.pro.yearly"

        static let productIDs: Set<String> = [
            monthlyProductID,
            yearlyProductID
        ]

        static let cachedTierKey = "flow.cached.subscriptionTier"
        static let cachedHasProKey = "flow.cached.hasPro"
        static let cachedExpirationDateKey = "flow.cached.expirationDate"
        static let cachedProductIDKey = "flow.cached.productID"
        static let hasInitializedKey = "flow.subscription.hasInitialized"
    }

    @Published private(set) var tier: SubscriptionTier = .free
    @Published private(set) var products: [Product] = []
    @Published private(set) var monthlyProduct: Product?
    @Published private(set) var yearlyProduct: Product?

    @Published private(set) var isLoadingProducts = false
    @Published private(set) var isRefreshingEntitlements = false
    @Published private(set) var isPurchasing = false
    @Published private(set) var activeProductID: String?
    @Published private(set) var expirationDate: Date?
    @Published private(set) var lastErrorMessage: String?

    private var transactionListenerTask: Task<Void, Never>?
    private var hasStartedTransactionListener = false
    private var hasInitialized = false

    var isPro: Bool {
        tier == .pro
    }

    var isTestFlight: Bool {
        guard let receiptURL = Bundle.main.appStoreReceiptURL else {
            return false
        }
        return receiptURL.lastPathComponent == "sandboxReceipt"
    }

    var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    private init() {
        loadCachedState()
        startTransactionListenerIfNeeded()
    }

    deinit {
        transactionListenerTask?.cancel()
    }

    func initialize() async {
        guard !hasInitialized else { return }
        hasInitialized = true

        async let productsTask: Void = loadProducts()
        async let entitlementsTask: Void = refreshEntitlements()
        _ = await (productsTask, entitlementsTask)

        UserDefaults.standard.set(true, forKey: Constants.hasInitializedKey)
    }

    func loadProducts() async {
        isLoadingProducts = true
        lastErrorMessage = nil

        defer {
            isLoadingProducts = false
        }

        do {
            let fetchedProducts = try await Product.products(for: Array(Constants.productIDs))

            let sortedProducts = fetchedProducts.sorted { lhs, rhs in
                let lhsRank = sortRank(for: lhs.id)
                let rhsRank = sortRank(for: rhs.id)

                if lhsRank != rhsRank {
                    return lhsRank < rhsRank
                }

                return lhs.displayName < rhs.displayName
            }

            products = sortedProducts
            monthlyProduct = sortedProducts.first(where: { $0.id == Constants.monthlyProductID })
            yearlyProduct = sortedProducts.first(where: { $0.id == Constants.yearlyProductID })
        } catch {
            lastErrorMessage = "Failed to load subscription products: \(error.localizedDescription)"
        }
    }

    func refreshEntitlements() async {
        isRefreshingEntitlements = true
        lastErrorMessage = nil

        defer {
            isRefreshingEntitlements = false
        }

        // Simulator unlock for local Xcode testing
        if isSimulator {
          
            applyEntitlementState(
                hasPro: true,
                productID: Constants.yearlyProductID,
                expirationDate: .distantFuture
            )

            return
        }

        // TestFlight unlock for testers
        if isTestFlight {
            

            applyEntitlementState(
                hasPro: true,
                productID: Constants.yearlyProductID,
                expirationDate: .distantFuture
            )

            return
        }

        var hasActivePro = false
        var newestExpirationDate: Date?
        var newestProductID: String?

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else {
                continue
            }

            guard Constants.productIDs.contains(transaction.productID) else {
                continue
            }

            if transaction.revocationDate != nil {
                continue
            }

            if let expirationDate = transaction.expirationDate,
               expirationDate < Date() {
                continue
            }

            hasActivePro = true

            let candidateDate = transaction.expirationDate ?? .distantFuture
            let currentNewest = newestExpirationDate ?? .distantPast

            if candidateDate > currentNewest {
                newestExpirationDate = transaction.expirationDate
                newestProductID = transaction.productID
            }
        }

        applyEntitlementState(
            hasPro: hasActivePro,
            productID: newestProductID,
            expirationDate: newestExpirationDate
        )
    }

    func purchaseMonthly() async -> Bool {
        guard let product = monthlyProduct else {
            lastErrorMessage = "Monthly subscription product is not available."
            return false
        }

        return await purchase(product)
    }

    func purchaseYearly() async -> Bool {
        guard let product = yearlyProduct else {
            lastErrorMessage = "Yearly subscription product is not available."
            return false
        }

        return await purchase(product)
    }

    func purchase(_ product: Product) async -> Bool {
        isPurchasing = true
        lastErrorMessage = nil

        defer {
            isPurchasing = false
        }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verificationResult):
                switch verificationResult {
                case .verified(let transaction):
                    await transaction.finish()
                    await refreshEntitlements()
                    return true

                case .unverified(_, let verificationError):
                    lastErrorMessage = "Purchase could not be verified: \(verificationError.localizedDescription)"
                    return false
                }

            case .pending:
                lastErrorMessage = "Purchase is pending approval."
                await refreshEntitlements()
                return false

            case .userCancelled:
                return false

            @unknown default:
                lastErrorMessage = "Unknown purchase result."
                return false
            }
        } catch {
            lastErrorMessage = "Purchase failed: \(error.localizedDescription)"
            return false
        }
    }

    func restorePurchases() async {
        lastErrorMessage = nil

        if isSimulator || isTestFlight {
            await refreshEntitlements()
            return
        }

        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            lastErrorMessage = "Restore failed: \(error.localizedDescription)"
        }
    }

    func clearLastError() {
        lastErrorMessage = nil
    }

    func hasLoadedProducts() -> Bool {
        monthlyProduct != nil || yearlyProduct != nil
    }

    func displayPrice(for productID: String) -> String {
        products.first(where: { $0.id == productID })?.displayPrice ?? ""
    }

    private func startTransactionListenerIfNeeded() {
        guard !hasStartedTransactionListener else { return }
        hasStartedTransactionListener = true

        transactionListenerTask = Task.detached(priority: .background) { [weak self] in
            guard let self else { return }

            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else {
                    continue
                }

                guard Self.Constants.productIDs.contains(transaction.productID) else {
                    continue
                }

                await transaction.finish()
                await self.refreshEntitlements()
            }
        }
    }

    private func applyEntitlementState(
        hasPro: Bool,
        productID: String?,
        expirationDate: Date?
    ) {
        tier = hasPro ? .pro : .free
        activeProductID = hasPro ? productID : nil
        self.expirationDate = hasPro ? expirationDate : nil

        UserDefaults.standard.set(hasPro, forKey: Constants.cachedHasProKey)
        UserDefaults.standard.set(hasPro ? "pro" : "free", forKey: Constants.cachedTierKey)
        UserDefaults.standard.set(hasPro ? productID : nil, forKey: Constants.cachedProductIDKey)
        UserDefaults.standard.set(hasPro ? expirationDate : nil, forKey: Constants.cachedExpirationDateKey)
    }

    private func loadCachedState() {
        let hasPro = UserDefaults.standard.bool(forKey: Constants.cachedHasProKey)
        let cachedTier = UserDefaults.standard.string(forKey: Constants.cachedTierKey)
        let cachedProductID = UserDefaults.standard.string(forKey: Constants.cachedProductIDKey)
        let cachedExpirationDate = UserDefaults.standard.object(forKey: Constants.cachedExpirationDateKey) as? Date

        if hasPro || cachedTier == "pro" {
            tier = .pro
            activeProductID = cachedProductID
            expirationDate = cachedExpirationDate
        } else {
            tier = .free
            activeProductID = nil
            expirationDate = nil
        }
    }

    private func sortRank(for productID: String) -> Int {
        switch productID {
        case Constants.yearlyProductID:
            return 0
        case Constants.monthlyProductID:
            return 1
        default:
            return 999
        }
    }
}
