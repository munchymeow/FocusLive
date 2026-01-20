//
//  SubscriptionView.swift
//  FocusLive
//
//  Created by 赵豪伟 on 2026/1/14.
//

import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @EnvironmentObject private var storeKitManager: StoreKitManager
    @State private var selectedPlanID: String? = "com.qingteng.FocusLive.pro.yearly"
    @State private var shimmerPhase: Double = 0
    
    private let freeFeatures = [
        "最多 2 个分组",
        "锁屏显示最多 3 个任务",
        "基础任务管理",
        "每日励志名言"
    ]
    
    private let proFeatures = [
        "最多 3 个分组",
        "锁屏显示最多 8 个任务",
        "隐私空间保护",
        "智能提醒功能",
        "任务时间 & 重复",
        "任务优先级管理",
        "任务附件支持",
        "高级分组管理"
    ]
    
    var body: some View {
        ZStack {
            // 背景流光效果
            BackgroundShimmerView(shimmerPhase: shimmerPhase)
                .ignoresSafeArea()
            ScrollView {
                LazyVStack(spacing: 32, pinnedViews: []) {
                    HeaderView()
                    
                    if !storeKitManager.isProUser {
                        FreePlanView(features: freeFeatures)
                    }
                    
                    ProPlanView(features: proFeatures)
                    
                    if !storeKitManager.isProUser {
                        SubscriptionOptionsView(
                            selectedPlanID: $selectedPlanID,
                            storeKitManager: storeKitManager
                        )
                    } else {
                        ProUnlockedView()
                    }
                    
                    BottomLinksView(storeKitManager: storeKitManager)
                }
                .padding(.horizontal, 24)
                .padding(.top, 32)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("成为会员")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await storeKitManager.loadProducts()
                await storeKitManager.refreshEntitlements()
            }
        }
    }
}

struct BackgroundShimmerView: View {
    let shimmerPhase: Double
    
    var body: some View {
        LinearGradient(
            colors: [
                Color.clear,
                Color.accentColor.opacity(0.05),
                Color.clear
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .offset(x: shimmerPhase * 400)
        .mask(
            LinearGradient(
                colors: [
                    Color.black.opacity(0.3),
                    Color.black,
                    Color.black.opacity(0.3)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

struct HeaderView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("升级到 Pro")
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)
            
            Text("解锁更多功能，提升效率")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

struct FreePlanView: View {
    let features: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("免费版")
                    .font(.title2.weight(.semibold))
                Spacer()
                Text("当前版本")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                ForEach(features, id: \.self) { feature in
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle")
                            .foregroundStyle(Color.green)
                            .font(.title3)
                        Text(feature)
                            .font(.body)
                    }
                }
            }
        }
        .padding(24)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

struct ProPlanView: View {
    let features: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Pro 会员")
                    .font(.title2.weight(.semibold))
                Spacer()
                Text("推荐")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.2))
                    .foregroundStyle(Color.accentColor)
                    .clipShape(Capsule())
            }
            
            VStack(alignment: .leading, spacing: 12) {
                ForEach(features, id: \.self) { feature in
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.accentColor)
                            .font(.title3)
                        Text(feature)
                            .font(.body.weight(.medium))
                    }
                }
            }
        }
        .padding(24)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
        )
    }
}

struct SubscriptionOptionsView: View {
    @Binding var selectedPlanID: String?
    let storeKitManager: StoreKitManager
    
    private func periodDescription(_ period: Product.SubscriptionPeriod) -> String {
        switch period.unit {
        case .month:
            let value = String(period.value)
            return period.value == 1 ? "每月" : "\(value)个月"
        case .year:
            let value = String(period.value)
            return period.value == 1 ? "每年" : "\(value)年"
        default:
            return "按周期"
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text("选择订阅周期")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 12) {
                ForEach(["com.qingteng.FocusLive.pro.monthly", "com.qingteng.FocusLive.pro.yearly"], id: \.self) { productID in
                    Button {
                        selectedPlanID = productID
                    } label: {
                        HStack {
                            if let product = storeKitManager.product(for: productID) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(product.displayName)
                                        .font(.headline)
                                    Text(product.displayPrice)
                                        .font(.title2.weight(.bold))
                                    if let period = product.subscription?.subscriptionPeriod {
                                        Text(periodDescription(period))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            } else {
                                let title = productID.contains("monthly") ? "月度订阅" : "年度订阅"
                                Text(title)
                                    .font(.headline)
                            }
                            
                            Spacer()
                            
                            if selectedPlanID == productID {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(selectedPlanID == productID ? Color.accentColor.opacity(0.1) : Color(.systemGray6))
                        )
                    }
                }
            }
            
            Button("立即订阅") {
                if let productID = selectedPlanID {
                    Task {
                        await storeKitManager.purchase(productID: productID)
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .font(.headline.weight(.semibold))
            .disabled(selectedPlanID == nil)
        }
    }
}

struct ProUnlockedView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("已解锁 Pro 会员")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.green)
            
            Button("管理订阅") {
                // TODO: 实现管理订阅
            }
            .buttonStyle(.bordered)
        }
    }
}

struct BottomLinksView: View {
    let storeKitManager: StoreKitManager
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        HStack(spacing: 16) {
            Button("恢复购买") {
                Task {
                    await storeKitManager.syncPurchases()
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            
            Button("用户服务条款") {
                if let url = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") {
                    openURL(url)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            
            Button("隐私政策") {
                if let url = URL(string: "https://www.freeprivacypolicy.com/live/5daf2aaa-018e-4125-ab59-34e22297c747") {
                    openURL(url)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    SubscriptionView()
        .environmentObject(StoreKitManager())
}
