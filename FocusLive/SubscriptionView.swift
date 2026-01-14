//
//  SubscriptionView.swift
//  FocusLive
//
//  Created by 赵豪伟 on 2026/1/14.
//

import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var storeKitManager: StoreKitManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedPlanID: String? = "com.qingteng.FocusLive.pro.yearly"
    
    private let plans: [SubscriptionPlan] = [
        SubscriptionPlan(
            titleKey: "免费版",
            subtitleKey: "基础功能与锁屏实时活动",
            fallbackPriceKey: "免费",
            productID: nil,
            isRecommended: false
        ),
        SubscriptionPlan(
            titleKey: "月度会员",
            subtitleKey: "解锁全部功能，按月订阅",
            fallbackPriceKey: "月度",
            productID: "com.qingteng.FocusLive.pro.monthly",
            isRecommended: false
        ),
        SubscriptionPlan(
            titleKey: "年度会员",
            subtitleKey: "解锁全部功能，年度更优惠",
            fallbackPriceKey: "年度",
            productID: "com.qingteng.FocusLive.pro.yearly",
            isRecommended: true
        )
    ]
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color.black : Color(uiColor: .systemGroupedBackground)
    }
    
    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    headerView
                    featureList
                    
                    VStack(spacing: 12) {
                        ForEach(plans) { plan in
                            SubscriptionPlanCard(
                                plan: plan,
                                product: plan.productID.flatMap { storeKitManager.product(for: $0) },
                                isSelected: selectedPlanID == plan.productID,
                                onSelect: { selectedPlanID = plan.productID }
                            )
                        }
                    }
                    
                    Button(action: handlePrimaryAction) {
                        Text(primaryActionTitle)
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                Capsule()
                                    .fill(primaryActionEnabled ? Color.blue : Color.gray.opacity(0.3))
                            )
                            .foregroundStyle(primaryActionEnabled ? .white : .secondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(!primaryActionEnabled)
                    
                    VStack(spacing: 10) {
                        Button(action: restorePurchases) {
                            SubscriptionActionRow(
                                titleKey: "恢复购买",
                                iconName: "arrow.clockwise.circle.fill"
                            )
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: openUserService) {
                            SubscriptionActionRow(
                                titleKey: "用户服务",
                                iconName: "person.fill.checkmark"
                            )
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: openPrivacyPolicy) {
                            SubscriptionActionRow(
                                titleKey: "隐私声明",
                                iconName: "hand.raised.fill"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 4)
                }
                .padding(16)
            }
        }
        .navigationTitle("成为会员")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await storeKitManager.loadProducts()
            await storeKitManager.refreshEntitlements()
        }
    }
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("FocusLive Pro")
                .font(.title2.weight(.bold))
            
            Text("解锁隐私空间与锁屏卡片设置")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.85), Color.cyan.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .foregroundStyle(.white)
    }
    
    private var featureList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("选择你的版本")
                .font(.headline)
            Text("订阅后可解锁更多功能与持续更新支持。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    private var selectedPlan: SubscriptionPlan? {
        plans.first { $0.productID == selectedPlanID }
    }
    
    private var primaryActionTitle: String {
        if storeKitManager.isProUser {
            return String(localized: "已解锁会员")
        }
        guard let selectedPlan else {
            return String(localized: "选择计划")
        }
        if selectedPlan.productID == nil {
            return String(localized: "当前免费版")
        }
        let price = priceText(for: selectedPlan)
        return String(format: String(localized: "继续订阅 %@"), price)
    }
    
    private var primaryActionEnabled: Bool {
        if storeKitManager.isProUser {
            return false
        }
        return selectedPlan?.productID != nil
    }
    
    /// 获取计划价格文本
    /// - Parameter plan: 订阅计划
    /// - Returns: 价格显示文本
    private func priceText(for plan: SubscriptionPlan) -> String {
        if let productID = plan.productID, let product = storeKitManager.product(for: productID) {
            return product.displayPrice
        }
        return plan.fallbackPriceKey
    }
    
    /// 处理订阅按钮点击
    /// - Returns: Void
    private func handlePrimaryAction() {
        guard let selectedPlan, let productID = selectedPlan.productID else { return }
        Task {
            await storeKitManager.purchase(productID: productID)
        }
    }
    
    /// 触发 App Store 恢复购买流程
    /// - Parameters: 无
    /// - Returns: Void
    private func restorePurchases() {
        Task {
            await storeKitManager.syncPurchases()
        }
    }
    
    /// 打开用户服务页面
    /// - Parameters: 无
    /// - Returns: Void
    private func openUserService() {
        guard let url = URL(string: "https://qingtengstudio.com/") else { return }
        openURL(url)
    }
    
    /// 打开隐私声明页面
    /// - Parameters: 无
    /// - Returns: Void
    private func openPrivacyPolicy() {
        guard let url = URL(string: "https://www.freeprivacypolicy.com/live/5daf2aaa-018e-4125-ab59-34e22297c747") else { return }
        openURL(url)
    }
}

struct SubscriptionPlan: Identifiable {
    let id = UUID()
    let titleKey: String
    let subtitleKey: String
    let fallbackPriceKey: String
    let productID: String?
    let isRecommended: Bool
}

struct SubscriptionPlanCard: View {
    let plan: SubscriptionPlan
    let product: Product?
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(plan.titleKey)
                        .font(.headline)
                    if plan.isRecommended {
                        Text("推荐")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.blue.opacity(0.15)))
                            .foregroundStyle(.blue)
                    }
                    Spacer()
                    Text(priceText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.blue)
                }
                
                Text(plan.subtitleKey)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(uiColor: .secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var priceText: String {
        if let product = product {
            return product.displayPrice
        }
        return plan.fallbackPriceKey
    }
}

struct SubscriptionActionRow: View {
    let titleKey: String
    let iconName: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .foregroundStyle(.blue)
                .frame(width: 24, height: 24)
            
            Text(titleKey)
                .font(.subheadline.weight(.semibold))
            
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }
}

#Preview {
    NavigationStack {
        SubscriptionView()
    }
    .environmentObject(StoreKitManager())
}
