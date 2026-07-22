//
//  StoreKitManager.swift
//  FocusLive
//
//  Created by 赵豪伟 on 2026/1/14.
//

import Foundation
import StoreKit
import Combine
import os

@MainActor
final class StoreKitManager: ObservableObject {
    private let appGroupID = "group.com.QingTeng.FocusLive"
    private let proStatusKey = "isProUser"

    /// 与 App Store Connect / 本地 Products.storekit 保持一致。
    static let monthlyProductID = "com.qingteng.FocusLive.pro.monthly"
    static let yearlyProductID = "com.qingteng.FocusLive.pro.yearly"

    private let productIDs: Set<String> = [
        monthlyProductID,
        yearlyProductID
    ]

    @Published private(set) var products: [Product] = []
    @Published private(set) var isProUser: Bool = false
    @Published private(set) var isLoadingProducts: Bool = false
    @Published private(set) var isPurchasing: Bool = false
    /// 给 UI 展示的最近一次可恢复错误（产品加载失败 / 购买失败 / 产品缺失）。
    @Published var lastErrorMessage: String?

    private var transactionListener: Task<Void, Never>?

    init() {
        // 监听后续交易更新（续订、撤销、Ask to Buy 批准等）。
        transactionListener = listenForTransactions()
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Products

    /// 从 App Store / StoreKit Configuration 拉取订阅产品。
    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            let loaded = try await Product.products(for: productIDs)
            // 稳定排序：年付在前，便于 UI 默认展示。
            products = loaded.sorted { lhs, rhs in
                if lhs.id == Self.yearlyProductID { return true }
                if rhs.id == Self.yearlyProductID { return false }
                return lhs.id < rhs.id
            }

            if products.isEmpty {
                lastErrorMessage = String(localized: "未能加载订阅商品。请确认 Xcode 已选择 StoreKit Configuration（Products.storekit），或 App Store Connect 中已配置对应产品 ID。")
                debugLog("StoreKit: Product.products returned empty for \(productIDs)")
            } else {
                // 加载成功时清掉「产品缺失」类提示，避免误伤。
                if lastErrorMessage?.contains("未能加载") == true
                    || lastErrorMessage?.contains("商品尚未就绪") == true {
                    lastErrorMessage = nil
                }
                debugLog("StoreKit: loaded \(products.map(\.id))")
            }
        } catch {
            products = []
            lastErrorMessage = String(localized: "加载订阅商品失败：\(error.localizedDescription)")
            debugLog("StoreKit: loadProducts error \(error)")
        }
    }

    func product(for productID: String) -> Product? {
        products.first { $0.id == productID }
    }

    var hasLoadedProducts: Bool { !products.isEmpty }

    // MARK: - Purchase

    /// 发起订阅购买。产品未就绪时会先尝试重新加载，而不是静默 return。
    func purchase(productID: String) async {
        lastErrorMessage = nil

        if product(for: productID) == nil {
            await loadProducts()
        }

        guard let product = product(for: productID) else {
            lastErrorMessage = String(localized: "商品尚未就绪，请稍后重试。若在模拟器/开发调试，请在 Scheme → Run → Options 中选择 Products.storekit。")
            debugLog("StoreKit: purchase aborted, product missing: \(productID)")
            return
        }

        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    await refreshEntitlements()
                    debugLog("StoreKit: purchase verified \(transaction.productID)")
                case .unverified(_, let error):
                    lastErrorMessage = String(localized: "购买校验失败：\(error.localizedDescription)")
                    debugLog("StoreKit: purchase unverified \(error)")
                }
            case .userCancelled:
                // 用户取消不提示错误。
                debugLog("StoreKit: user cancelled")
            case .pending:
                lastErrorMessage = String(localized: "购买待确认（例如需要家长批准）。批准后会员会自动生效。")
                debugLog("StoreKit: purchase pending")
            @unknown default:
                lastErrorMessage = String(localized: "未知的购买结果，请稍后在「恢复购买」中重试。")
            }
        } catch {
            lastErrorMessage = String(localized: "购买失败：\(error.localizedDescription)")
            debugLog("StoreKit: purchase error \(error)")
        }
    }

    /// 同步恢复购买（会弹出 Apple ID 登录框）。
    func syncPurchases() async {
        lastErrorMessage = nil
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            // 用户取消登录时也走这里，不必吓人。
            let nsError = error as NSError
            if nsError.domain == "ASDErrorDomain", nsError.code == 509 {
                return
            }
            lastErrorMessage = String(localized: "恢复购买失败：\(error.localizedDescription)")
            debugLog("StoreKit: sync error \(error)")
        }
    }

    /// 刷新订阅权限状态并写入 App Group。
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

    // MARK: - Private

    private func listenForTransactions() -> Task<Void, Never> {
        Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await self.refreshEntitlements()
                }
            }
        }
    }

    private func updateProStatus(_ isPro: Bool) {
        isProUser = isPro
        UserDefaults(suiteName: appGroupID)?.set(isPro, forKey: proStatusKey)
        // 同步到 standard，兼容旧读取路径。
        UserDefaults.standard.set(isPro, forKey: proStatusKey)
    }
}
