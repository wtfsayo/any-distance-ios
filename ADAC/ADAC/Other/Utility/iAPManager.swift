// Licensed under the Any Distance Source-Available License
//
//  iAPManager.swift
//  ADAC
//
//  Created by Daniel Kuntz on 12/15/21.
//

import Foundation
import Purchases
import StoreKit
import Combine
import Sentry

fileprivate let grandfatheredDate: Date = Date(timeIntervalSince1970: 1710721853)

final class iAPManager: NSObject, ObservableObject {

    // MARK: - Singleton

    static let shared = iAPManager()

    // MARK: - Constants

    let revenueCatAPIKey: String = ""
    let proEntitlementID: String = "Super Distance"

    // MARK: - Variables

    @Published var monthlyProduct: SKProduct?
    @Published var yearlyProduct: SKProduct?
    @Published var lifetimeProduct: SKProduct?
    @Published var isSubscribed: Bool = 
        (ADUser.current.subscriptionProductID != nil) ||
        ((ADUser.current.signupDate ?? Date()) <= grandfatheredDate)

    var subscribedProduct: ADProduct? {
        guard let subscriptionID = ADUser.current.subscriptionProductID,
              let monthly = monthlyProduct,
              let yearly = yearlyProduct,
              let lifetime = lifetimeProduct else {
            return nil
        }

        let skProduct = [monthly, yearly, lifetime].first(where: { $0.productIdentifier == subscriptionID })
        return ADProduct(skProduct: skProduct, productID: subscriptionID)
    }

    var hasSuperDistanceFeatures: Bool {
        return true // isSubscribed //  || ADUser.current.hasBetaMedal()
    }

    var expirationDate: Date? = nil

    var formattedExpirationDate: String {
        guard let expirationDate = expirationDate else {
            return ""
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: expirationDate)
    }

    var formattedDuration: String {
        switch ADUser.current.subscriptionProductID {
        case monthlyProduct?.productIdentifier:
            return "Per Month"
        case yearlyProduct?.productIdentifier:
            return "Per Year"
        case lifetimeProduct?.productIdentifier:
            return "Lifetime"
        case "rc_promo_Super Distance_three_month":
            return "3 Months"
        default:
            return ""
        }
    }

    var percentageSavedYearlyToMonthly: Int {
        guard let yearlyProduct = yearlyProduct,
              let monthlyProduct = monthlyProduct else {
            return 0
        }

        let monthlyYearPrice = monthlyProduct.price.doubleValue * 12
        let yearPrice = yearlyProduct.price.doubleValue
        return Int(100 * (monthlyYearPrice - yearPrice) / monthlyYearPrice)
    }

    var isSubscribedToLifetime: Bool {
        return subscribedProduct?.skProduct == lifetimeProduct
    }

    var subscriptionIsNotCancellable: Bool {
        return isSubscribedToLifetime || subscribedProduct?.productID == ADProduct.threeMonthSDPromoID
    }

    // MARK: - Setup

    override init() {
        super.init()

        configureWithCurrentUserDetails()
        Purchases.logLevel = .error
        Purchases.shared.delegate = self

        fetchProduct()
        Task {
            await fetchSubscriptionStatus()
        }
    }

    private func fetchProduct() {
        Purchases.shared.offerings { (offerings, error) in
            if let e = error {
                print("Error in fetchProduct: \(e.localizedDescription)")
                Analytics.logEvent("Retrieve Offerings Error", "iAPManager", .otherEvent, withParameters: ["error": e.localizedDescription])
            }

            if let packages = offerings?.current?.availablePackages {
                self.monthlyProduct = packages.first(where: { $0.product.productIdentifier == "super_distance_monthly" })?.product
                self.yearlyProduct = packages.first(where: { $0.product.productIdentifier == "super_distance_yearly" })?.product
                self.lifetimeProduct = packages.first(where: { $0.product.productIdentifier == "super_distance_lifetime" })?.product
                print("loaded packages")
            }
        }

        self.restorePurchases(completion: nil)
    }

    func configureWithCurrentUserDetails() {
        if !ADUser.current.hasRegistered  {
            Purchases.configure(withAPIKey: revenueCatAPIKey)
        } else {
            Purchases.configure(withAPIKey: revenueCatAPIKey, appUserID: ADUser.current.id)
        }
        Purchases.shared.setDisplayName(ADUser.current.name)
        Purchases.shared.setEmail(ADUser.current.email)
        Purchases.shared.setAttributes(["totalDistanceTrackedMeters": String(ADUser.current.totalDistanceTrackedMeters ?? 0)])
    }

    func grantThreeMonthSuperDistancePromo() async throws {
        let info = try await Purchases.shared.purchaserInfo()
        guard !info.allPurchasedProductIdentifiers.contains(ADProduct.threeMonthSDPromoID) else {
            throw InviteCodeError.alreadyUsed
        }

        let secretAPIKey = ""
        let appUserID = Purchases.shared.appUserID
        let entitlementID = "Super%20Distance"

        let headers = [
            "accept": "application/json",
            "Content-Type": "application/json",
            "Authorization": "Bearer \(secretAPIKey)"
        ]
        let parameters = ["duration": "three_month"] as [String : Any]
        let postData = try? JSONSerialization.data(withJSONObject: parameters, options: [])

        let request = NSMutableURLRequest(url: NSURL(string: "https://api.revenuecat.com/v1/subscribers/\(appUserID)/entitlements/\(entitlementID)/promotional")! as URL,
                                          cachePolicy: .useProtocolCachePolicy,
                                          timeoutInterval: 10.0)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = headers
        request.httpBody = postData

        let _: Void = try await withCheckedThrowingContinuation { continuation in
            let session = URLSession.shared
            let dataTask = session.dataTask(with: request as URLRequest,
                                            completionHandler: { (data, response, error) -> Void in
                if let error = error {
                    print(error as Any)
                    continuation.resume(throwing: error)
                } else {
                    let httpResponse = response as? HTTPURLResponse
                    print(httpResponse)
                    continuation.resume()
                }
            })

            dataTask.resume()
        }

        ADUser.current.subscriptionProductID = ADProduct.threeMonthSDPromoID
        DispatchQueue.main.async {
            self.isSubscribed = true
            self.expirationDate = Calendar.current.date(byAdding: DateComponents(month: 3, day: 2), to: Date())
            self.objectWillChange.send()
            NSUbiquitousKeyValueStore.default.shouldShowAnyDistanceBranding = false
        }

        await UserManager.shared.updateCurrentUser()
    }

    func fetchSubscriptionStatus() async {
        return await withCheckedContinuation { continuation in
            Purchases.shared.purchaserInfo { (purchaserInfo, error) in
                Task {
                    if let e = error {
                        print("Error fetching subscription status - \(e.localizedDescription)")
                    } else if let purchaserInfo = purchaserInfo {
                        await self.updateSubscriptionState(withInfo: purchaserInfo)
                    }
                    continuation.resume()
                }
            }
        }
    }

    private func updateSubscriptionState(withInfo purchaserInfo: Purchases.PurchaserInfo) async {
        let prevSubscriptionProductID = ADUser.current.subscriptionProductID
        if purchaserInfo.entitlements.active.isEmpty {
            await MainActor.run {
                ADUser.current.subscriptionProductID = nil
            }
        } else {
            for entitlement in purchaserInfo.entitlements.active {
                await MainActor.run {
                    ADUser.current.subscriptionProductID = entitlement.value.productIdentifier
                }
                if entitlement.value.productIdentifier == self.lifetimeProduct?.productIdentifier {
                    break
                }
            }
        }

        DispatchQueue.main.async {
            self.isSubscribed = (ADUser.current.subscriptionProductID != nil) ||
                                ((ADUser.current.signupDate ?? Date()) <= grandfatheredDate)
            self.expirationDate = purchaserInfo.expirationDate(forEntitlement: self.proEntitlementID)
            if !self.hasSuperDistanceFeatures {
                NSUbiquitousKeyValueStore.default.shouldShowAnyDistanceBranding = true
            }

            if self.isSubscribed {
                CollectibleManager.grantSuperDistanceCollectible()
            }
        }

        if ADUser.current.subscriptionProductID != prevSubscriptionProductID {
            await UserManager.shared.updateCurrentUser()
        }
    }

    private func purchaserIsSubscribed(_ purchaserInfo: Purchases.PurchaserInfo?) -> Bool {
        guard let info = purchaserInfo else {
            return false
        }

        return info.entitlements.active.first != nil
    }

    // MARK: - Functions

    func buyMonthlyProduct(completion: @escaping (_ state: PurchaseCompletionState) -> Void) {
        guard let product = monthlyProduct else {
            completion(.failed)
            return
        }

        purchaseProduct(product, completion: completion)
    }

    func buyYearlyProduct(completion: @escaping (_ state: PurchaseCompletionState) -> Void) {
        guard let product = yearlyProduct else {
            completion(.failed)
            return
        }

        purchaseProduct(product, completion: completion)
    }

    func buyLifetimeProduct(completion: @escaping (_ state: PurchaseCompletionState) -> Void) {
        guard let product = lifetimeProduct else {
            return
        }

        purchaseProduct(product, completion: completion)
    }

    private func purchaseProduct(_ product: SKProduct, completion: @escaping (_ state: PurchaseCompletionState) -> Void) {
        Purchases.shared.purchaseProduct(product) { (transaction, purchaserInfo, error, userCancelled) in
            if let e = error {
                print("PURCHASE ERROR: - \(e.localizedDescription)")
                completion(.failed)
            } else if self.purchaserIsSubscribed(purchaserInfo) {
                print("Purchased Super Distance 🎉")
                CollectibleManager.grantSuperDistanceCollectible()
                if let info = purchaserInfo {
                    Task {
                        await self.updateSubscriptionState(withInfo: info)
                    }
                }
                completion(.completedSuccessfully)
            } else {
                print("Purchase Failed")
                completion(.failed)
            }
        }
    }

    func restorePurchases(completion: ((_ state: PurchaseCompletionState) -> Void)?) {
        Purchases.shared.restoreTransactions { (purchaserInfo, error) in
            if let e = error {
                print("RESTORE ERROR: - \(e.localizedDescription)")
                completion?(.failed)
            } else if self.purchaserIsSubscribed(purchaserInfo) {
                print("Restored Super Distance 🎉")
                completion?(.restoredSuccessfully)
            } else {
                print("Restore Failed")
                completion?(.restoredWithoutSubscription)
            }
        }
    }
}

extension iAPManager: PurchasesDelegate {
    func purchases(_ purchases: Purchases, didReceiveUpdated purchaserInfo: Purchases.PurchaserInfo) {
        Task {
            await self.updateSubscriptionState(withInfo: purchaserInfo)
        }
    }
}

enum PurchaseCompletionState {
    case completedSuccessfully
    case failed
    case restoredSuccessfully
    case restoredWithoutSubscription
}

extension SKProduct {
    var localizedPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.roundingMode = .up
        formatter.usesSignificantDigits = false
        formatter.maximumFractionDigits = 0
        formatter.locale = Locale.current
        return formatter.string(from: price)!
    }

    var hasTrial: Bool {
        return introductoryPrice != nil
    }

    var trialLengthDays: Int {
        guard let introductoryPrice = introductoryPrice else {
            return 0
        }

        let period = introductoryPrice.subscriptionPeriod
        let periodLengthDays: Int = {
            switch period.unit {
            case .day:
                return 1
            case .week:
                return 7
            case .month:
                return 30
            case .year:
                return 365
            @unknown default:
                return 0
            }
        }()

        return introductoryPrice.numberOfPeriods * period.numberOfUnits * periodLengthDays
    }
}
