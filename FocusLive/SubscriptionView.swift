//
//  SubscriptionView.swift
//  FocusLive
//
//  Created by 赵豪伟 on 2026/1/14.
//  Redesigned 2026-04-01 — dark premium layout
//

import SwiftUI
import StoreKit

// MARK: - Main View

struct SubscriptionView: View {
    @EnvironmentObject private var storeKitManager: StoreKitManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var selectedPlanID: String = "com.qingteng.FocusLive.pro.yearly"

    private let bgTop    = Color(red: 0.04, green: 0.04, blue: 0.14)
    private let bgBottom = Color(red: 0.02, green: 0.02, blue: 0.08)

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [bgTop, bgBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    heroSection
                    mainContent
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            await storeKitManager.loadProducts()
            await storeKitManager.refreshEntitlements()
        }
    }

    // MARK: - Hero image + gradient fade

    private var heroSection: some View {
        ZStack(alignment: .bottom) {
            Image("去做订阅宣传")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity)
                .frame(height: 420)
                .clipped()

            // Gradient fade into background
            LinearGradient(
                colors: [.clear, bgTop.opacity(0.6), bgTop],
                startPoint: UnitPoint(x: 0.5, y: 0.3),
                endPoint: .bottom
            )
            .frame(height: 420)

            // Title overlay
            VStack(alignment: .leading, spacing: 4) {
                Text("选择您的")
                    .font(.title2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.82))
                Text("会员计划")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Scrollable main content

    private var mainContent: some View {
        VStack(spacing: 26) {
            if storeKitManager.isProUser {
                proUnlockedSection
            } else {
                planCardsSection
                ctaButton
            }

            featuresSection
            legalText
            bottomLinks
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 52)
    }

    // MARK: - Plan cards

    private var planCardsSection: some View {
        HStack(alignment: .top, spacing: 10) {
            FreePlanCard()

            SubscriptionPlanCard(
                productID: "com.qingteng.FocusLive.pro.yearly",
                isSelected: selectedPlanID == "com.qingteng.FocusLive.pro.yearly",
                isRecommended: true,
                badgeText: "推荐",
                storeKitManager: storeKitManager,
                onSelect: { selectedPlanID = "com.qingteng.FocusLive.pro.yearly" }
            )

            SubscriptionPlanCard(
                productID: "com.qingteng.FocusLive.pro.monthly",
                isSelected: selectedPlanID == "com.qingteng.FocusLive.pro.monthly",
                isRecommended: false,
                badgeText: nil,
                storeKitManager: storeKitManager,
                onSelect: { selectedPlanID = "com.qingteng.FocusLive.pro.monthly" }
            )
        }
    }

    // MARK: - Subscribe CTA Button

    private var ctaButton: some View {
        Button {
            Task { await storeKitManager.purchase(productID: selectedPlanID) }
        } label: {
            HStack(spacing: 6) {
                let label = selectedPlanID.contains("yearly") ? "立即开通年度会员" : "立即开通月度会员"
                Text(label)
                    .fontWeight(.semibold)
                if let price = storeKitManager.product(for: selectedPlanID)?.displayPrice {
                    Text("· \(price)")
                        .fontWeight(.regular)
                        .opacity(0.88)
                }
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.22, green: 0.44, blue: 0.95),
                        Color(red: 0.10, green: 0.62, blue: 0.96)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: Color(red: 0.1, green: 0.4, blue: 0.9).opacity(0.45), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Pro Unlocked Section

    private var proUnlockedSection: some View {
        VStack(spacing: 18) {
            ShinyText(
                text: "✦  已解锁 Pro 会员  ✦",
                font: .title2.weight(.bold)
            )
            .padding(.top, 16)

            Button {
                if let url = URL(string: "itms-apps://apps.apple.com/account/subscriptions") {
                    openURL(url)
                }
            } label: {
                Text("管理订阅")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(red: 0.45, green: 0.75, blue: 1.0))
                    .padding(.horizontal, 28)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .stroke(Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.45), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - Features Section

    private let featureItems: [(icon: String, color: Color, title: String, subtitle: String)] = [
        ("lock.shield.fill",      Color(red: 0.3, green: 0.6, blue: 1.0),  "隐私空间保护",      "Face ID 加密保护私密事项"),
        ("bell.badge.fill",       Color(red: 1.0, green: 0.55, blue: 0.2), "智能提醒通知",      "任务时间前 2 小时本地通知"),
        ("square.3.layers.3d",    Color(red: 0.25, green: 0.78, blue: 0.7),"多分组锁屏展示",    "锁屏同时显示最多 3 个分组"),
        ("list.number",           Color(red: 0.35, green: 0.85, blue: 0.45),"更多任务条目",     "锁屏最多同时显示 8 条任务"),
        ("calendar.badge.clock",  Color(red: 0.72, green: 0.45, blue: 1.0),"任务时间 & 重复",   "精确计划时间、灵活重复规则"),
        ("flag.fill",             Color(red: 1.0, green: 0.35, blue: 0.4), "优先级管理",        "为任务标记紧急 / 高 / 中 / 低")
    ]

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("专属会员权益")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .center)

            VStack(spacing: 13) {
                ForEach(featureItems, id: \.title) { item in
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(item.color.opacity(0.16))
                                .frame(width: 40, height: 40)
                            Image(systemName: item.icon)
                                .font(.system(size: 17))
                                .foregroundStyle(item.color)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                            Text(item.subtitle)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.48))
                        }
                        Spacer()
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.055))
        )
    }

    // MARK: - Legal text

    private var legalText: some View {
        Text("订阅将会自动续期，除非您在当前订阅结束前 24 小时以上取消续订。如需取消订阅，可手动在 iTunes/AppleID 设置管理中关闭自动续期功能。试用期内，iTunes 账户如不取消订阅，则会在试用期结束时自动开通订阅并扣款，未使用的试用时长在购买订阅之后将会自动作废。")
            .font(.system(size: 10))
            .foregroundStyle(.white.opacity(0.32))
            .multilineTextAlignment(.center)
            .lineSpacing(3)
    }

    // MARK: - Bottom links (兑换 | 恢复 | 隐私 | 续费)

    private var bottomLinks: some View {
        HStack(spacing: 0) {
            Button("兑换会员") {
                Task {
                    if let scene = UIApplication.shared.connectedScenes
                        .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                        try? await AppStore.presentOfferCodeRedeemSheet(in: scene)
                    }
                }
            }

            Divider()
                .frame(height: 11)
                .background(Color.white.opacity(0.25))
                .padding(.horizontal, 10)

            Button("恢复购买") {
                Task { await storeKitManager.syncPurchases() }
            }

            Divider()
                .frame(height: 11)
                .background(Color.white.opacity(0.25))
                .padding(.horizontal, 10)

            Button("隐私政策") {
                openURL(URL(string: "https://www.freeprivacypolicy.com/live/5daf2aaa-018e-4125-ab59-34e22297c747")!)
            }

            Divider()
                .frame(height: 11)
                .background(Color.white.opacity(0.25))
                .padding(.horizontal, 10)

            Button("续费协议") {
                openURL(URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
            }
        }
        .font(.system(size: 11))
        .foregroundStyle(.white.opacity(0.42))
        .padding(.bottom, 6)
    }
}

// MARK: - Free Plan Card

private struct FreePlanCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("免费版")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.9))

            Text("永久免费")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.42))
                .padding(.top, 4)

            Spacer()

            Text("¥ 0")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
                .padding(.top, 8)

            Text("基础功能")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.32))
                .padding(.top, 2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.07))
        )
    }
}

// MARK: - Subscription Plan Card

private struct SubscriptionPlanCard: View {
    let productID: String
    let isSelected: Bool
    let isRecommended: Bool
    let badgeText: String?
    let storeKitManager: StoreKitManager
    let onSelect: () -> Void

    private var isYearly: Bool { productID.contains("yearly") }

    var body: some View {
        Button(action: onSelect) {
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(isYearly ? "按年订阅" : "按月订阅")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)

                    Text(isYearly ? "更实惠" : "灵活续订")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.55))
                        .padding(.top, 4)

                    Spacer()

                    if let product = storeKitManager.product(for: productID) {
                        Text(product.displayPrice)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.top, 8)
                        Text(isYearly ? "/年" : "/月")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.55))
                            .padding(.top, 1)
                    } else {
                        Text(isYearly ? "年度订阅" : "月度订阅")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.top, 8)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            isRecommended
                                ? LinearGradient(
                                    colors: [
                                        Color(red: 0.18, green: 0.38, blue: 0.88),
                                        Color(red: 0.08, green: 0.52, blue: 0.90)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                : LinearGradient(
                                    colors: [Color.white.opacity(0.09), Color.white.opacity(0.06)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isSelected ? Color.white.opacity(0.75) : Color.clear,
                            lineWidth: 1.5
                        )
                )

                // Badge + checkmark
                VStack(alignment: .trailing, spacing: 4) {
                    if let badge = badgeText {
                        Text(badge)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.orange))
                    }
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.white)
                    }
                }
                .padding(8)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Shiny Text (Swift 复刻 reactbits.dev/text-animations/shiny-text)

struct ShinyText: View {
    let text: String
    var font: Font = .headline
    /// 扫光位置 0→1.4 循环
    @State private var phase: CGFloat = -0.2

    var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(Color.white.opacity(0.42))
            .overlay(
                LinearGradient(
                    stops: [
                        .init(color: .clear,             location: max(0, phase - 0.28)),
                        .init(color: .white.opacity(0.9), location: phase),
                        .init(color: .clear,             location: min(1, phase + 0.28))
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .mask(
                    Text(text).font(font)
                )
            )
            .onAppear {
                withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                    phase = 1.4
                }
            }
    }
}


#Preview {
    NavigationStack {
        SubscriptionView()
            .environmentObject(StoreKitManager())
    }
}
