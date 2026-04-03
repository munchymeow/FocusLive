//
//  StoreKitManager.swift
//  FocusLive
//
//  Created by 赵豪伟 on 2026/1/14.
//

import Foundation
import StoreKit
import Combine

@MainActor
final class StoreKitManager: ObservableObject {
    static let shared = StoreKitManager()
    
    private let appGroupID = "group.com.QingTeng.FocusLive"
    private let proStatusKey = "isProUser"
    private let productIDs = [
        "com.qingteng.FocusLive.pro.monthly",
        "com.qingteng.FocusLive.pro.yearly"
    ]
    
    @Published private(set) var products: [Product] = []
    @Published private(set) var isProUser: Bool = false
    
    init() {
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }
    
    /// 加载订阅产品信息
    /// - Returns: Void
    func loadProducts() async {
        do {
            products = try await Product.products(for: productIDs)
        } catch {
            products = []
        }
    }
    
    /// 刷新订阅权限状态
    /// - Returns: Void
    func refreshEntitlements() async {
        var hasActiveSubscription = false
        
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard productIDs.contains(transaction.productID) else { continue }
            
            if let expirationDate = transaction.expirationDate, expirationDate < Date() {
                continue
            }
            
            if transaction.revocationDate == nil {
                hasActiveSubscription = true
                break
            }
        }
        
        updateProStatus(hasActiveSubscription)
    }
    
    /// 获取指定产品信息
    /// - Parameter productID: 产品 ID
    /// - Returns: 对应 Product
    func product(for productID: String) -> Product? {
        products.first { $0.id == productID }
    }
    
    /// 发起订阅购买
    /// - Parameter productID: 产品 ID
    /// - Returns: Void
    func purchase(productID: String) async {
        guard let product = product(for: productID) else { return }
        
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await refreshEntitlements()
                }
            default:
                break
            }
        } catch {
            return
        }
    }
    
    /// 同步恢复购买
    /// - Returns: Void
    func syncPurchases() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            return
        }
    }
    
    /// 更新会员状态并写入 App Group
    /// - Parameter isPro: 是否为会员
    /// - Returns: Void
    private func updateProStatus(_ isPro: Bool) {
        isProUser = isPro
        UserDefaults(suiteName: appGroupID)?.set(isPro, forKey: proStatusKey)
    }
}
