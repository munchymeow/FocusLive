//
//  ProfileView.swift
//  FocusLive
//
//  Created by 赵豪伟 on 2026/1/14.
//

import SwiftUI
import ActivityKit
import StoreKit
import UIKit

struct ProfileView: View {
    private static let appGroupID = "group.com.QingTeng.FocusLive"
    private static let firstLaunchKey = "firstLaunchTimestamp"
    private static let proStatusKey = "isProUser"
    
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL
    @Environment(\.requestReview) private var requestReview
    @Environment(\.scenePhase) private var scenePhase
    @State private var areActivitiesEnabled = ActivityAuthorizationInfo().areActivitiesEnabled
    @State private var showSubscription = false
    
    @AppStorage(Self.firstLaunchKey, store: UserDefaults(suiteName: Self.appGroupID))
    private var firstLaunchTimestamp: Double = 0
    
    @AppStorage(Self.proStatusKey, store: UserDefaults(suiteName: Self.appGroupID))
    private var isProUser: Bool = false
    
    private var backgroundColor: Color {
        colorScheme == .dark
            ? Color(red: 0.08, green: 0.08, blue: 0.10)
            : Color(red: 0.96, green: 0.96, blue: 0.98)
    }
    
    private var cardBackground: Color {
        colorScheme == .dark
            ? Color(red: 0.15, green: 0.15, blue: 0.18)
            : Color.white
    }

    private var ambientBackground: some View {
        ZStack {
            backgroundColor
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.cyan.opacity(0.25), Color.blue.opacity(0.18)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 240, height: 240)
                .blur(radius: 40)
                .offset(x: -140, y: -220)
            
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.mint.opacity(0.18), Color.blue.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 220, height: 220)
                .blur(radius: 50)
                .offset(x: 140, y: 260)
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                ambientBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        headerView
                        memberCard
                        sectionView(titleKey: "个性化") {
                            liveActivitySettingsRow
                        }
                        sectionView(titleKey: "通用") {
                            liveActivityRow
                        }
                        sectionView(titleKey: "其他") {
                            languageRow
                            reviewRow
                            feedbackRow
                        }
                        sectionView(titleKey: "实验室") {
                            labRow
                        }
                        sectionView(titleKey: "关于") {
                            softwareInfoRow
                            privacyPolicyRow
                            creatorSupportRow
                        }
                        footerView
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 120)
                }
            }
            .navigationTitle("我的")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                refreshActivityAuthorization()
                ensureFirstLaunchTimestamp()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    refreshActivityAuthorization()
                    ensureFirstLaunchTimestamp()
                }
            }
            .navigationDestination(isPresented: $showSubscription) {
                SubscriptionView()
            }
        }
    }
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("你好")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Image(isProUser ? "logoPro" : "logo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 22)
            }
            
            Text(String(format: String(localized: "感谢您使用 FocusScreen，这是它陪伴你的第 %lld 天"), Int64(dayCount())))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .multilineTextAlignment(.leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.6), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.08), radius: 14, x: 0, y: 6)
        )
    }
    
    private var memberCard: some View {
        NavigationLink {
            SubscriptionView()
        } label: {
            ProfileRow(
                item: ProfileItem(
                    titleKey: "成为会员",
                    subtitleKey: nil,
                    iconName: "crown.fill",
                    iconColor: .blue,
                    trailingTextKey: nil,
                    badgeTextKey: nil
                ),
                cardBackground: cardBackground
            )
        }
        .buttonStyle(.plain)
    }
    
    /// 构建个人中心分组视图
    /// - Parameters:
    ///   - titleKey: 分组标题本地化 Key
    ///   - content: 分组内内容
    /// - Returns: 分组视图
    private func sectionView<Content: View>(titleKey: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(LocalizedStringKey(titleKey))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 6)
            
            VStack(spacing: 10) {
                content()
            }
        }
    }
    
    private var liveActivityRow: some View {
        let item = ProfileItem(
            titleKey: areActivitiesEnabled ? "实时活动已开启" : "实时活动权限未开启",
            subtitleKey: areActivitiesEnabled
                ? "可在系统设置中管理实时活动权限"
                : "实时活动未开启，手机将无法实时显示任务。放心～更新频率低不耗电。",
            iconName: areActivitiesEnabled ? "checkmark.circle.fill" : "exclamationmark.circle.fill",
            iconColor: areActivitiesEnabled ? .green : .orange,
            trailingTextKey: areActivitiesEnabled ? "已开启" : "去开启",
            badgeTextKey: nil
        )
        
        return Button(action: openAppSettings) {
            ProfileRow(item: item, cardBackground: cardBackground)
        }
        .buttonStyle(.plain)
    }
    
    private var liveActivitySettingsRow: some View {
        let row = ProfileRow(
            item: ProfileItem(
                titleKey: "修改锁屏卡片",
                subtitleKey: "调整实时活动显示条数与透明度",
                iconName: "square.grid.2x2.fill",
                iconColor: .orange,
                trailingTextKey: nil,
                badgeTextKey: nil
            ),
            cardBackground: cardBackground
        )
        
        return NavigationLink {
            LiveActivitySettingsView()
        } label: {
            row
        }
        .buttonStyle(.plain)
    }
    
    private var languageRow: some View {
        Button(action: openAppSettings) {
            ProfileRow(
                item: ProfileItem(
                    titleKey: "语言设置",
                    subtitleKey: nil,
                    iconName: "globe",
                    iconColor: .blue,
                    trailingTextKey: nil,
                    badgeTextKey: nil
                ),
                cardBackground: cardBackground
            )
        }
        .buttonStyle(.plain)
    }
    
    private var reviewRow: some View {
        Button(action: requestAppReview) {
            ProfileRow(
                item: ProfileItem(
                    titleKey: "给个好评",
                    subtitleKey: nil,
                    iconName: "star.fill",
                    iconColor: .blue,
                    trailingTextKey: nil,
                    badgeTextKey: nil
                ),
                cardBackground: cardBackground
            )
        }
        .buttonStyle(.plain)
    }
    
    private var feedbackRow: some View {
        Button(action: openFeedbackSite) {
            ProfileRow(
                item: ProfileItem(
                    titleKey: "问题反馈",
                    subtitleKey: nil,
                    iconName: "envelope.fill",
                    iconColor: .blue,
                    trailingTextKey: nil,
                    badgeTextKey: nil
                ),
                cardBackground: cardBackground
            )
        }
        .buttonStyle(.plain)
    }

    private var softwareInfoRow: some View {
        NavigationLink {
            SoftwareInfoView()
        } label: {
            ProfileRow(
                item: ProfileItem(
                    titleKey: "软件说明",
                    subtitleKey: nil,
                    iconName: "doc.text.fill",
                    iconColor: .blue,
                    trailingTextKey: nil,
                    badgeTextKey: nil
                ),
                cardBackground: cardBackground
            )
        }
        .buttonStyle(.plain)
    }

    private var privacyPolicyRow: some View {
        Button(action: openPrivacyPolicy) {
            ProfileRow(
                item: ProfileItem(
                    titleKey: "隐私声明",
                    subtitleKey: nil,
                    iconName: "hand.raised.fill",
                    iconColor: .purple,
                    trailingTextKey: nil,
                    badgeTextKey: nil
                ),
                cardBackground: cardBackground
            )
        }
        .buttonStyle(.plain)
    }

    private var creatorSupportRow: some View {
        Button(action: openCreatorSupport) {
            ProfileRow(
                item: ProfileItem(
                    titleKey: "创作者激励",
                    subtitleKey: nil,
                    iconName: "heart.fill",
                    iconColor: .pink,
                    trailingTextKey: nil,
                    badgeTextKey: nil
                ),
                cardBackground: cardBackground
            )
        }
        .buttonStyle(.plain)
    }

    private var labRow: some View {
        NavigationLink {
            LabView()
        } label: {
            ProfileRow(
                item: ProfileItem(
                    titleKey: "实验室",
                    subtitleKey: "体验实验性功能与新版 UI",
                    iconName: "flask.fill",
                    iconColor: .purple,
                    trailingTextKey: nil,
                    badgeTextKey: "Beta"
                ),
                cardBackground: cardBackground
            )
        }
        .buttonStyle(.plain)
    }
    
    private var footerView: some View {
        VStack(spacing: 6) {
            Text("Made By")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 6) {
                Button("munchymeow", action: openCreatorGitHub)
                    .font(.caption.weight(.semibold))
                Text("×")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("QingTengStudio", action: openStudioSite)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(.blue)
            
            Text(appVersionString())
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
    }
    
    /// 刷新实时活动权限状态
    /// - Parameters: 无
    /// - Returns: Void
    private func refreshActivityAuthorization() {
        areActivitiesEnabled = ActivityAuthorizationInfo().areActivitiesEnabled
    }
    
    /// 初始化首次启动时间戳
    /// - Parameters: 无
    /// - Returns: Void
    private func ensureFirstLaunchTimestamp() {
        if firstLaunchTimestamp == 0 {
            firstLaunchTimestamp = Date().timeIntervalSince1970
        }
    }
    
    /// 计算当前使用天数（从首次启动起算）
    /// - Returns: 使用天数（最小为 1）
    private func dayCount() -> Int {
        let startDate = Date(timeIntervalSince1970: firstLaunchTimestamp == 0 ? Date().timeIntervalSince1970 : firstLaunchTimestamp)
        let days = Calendar.current.dateComponents([.day], from: startDate, to: Date()).day ?? 0
        return max(days + 1, 1)
    }
    
    /// 打开应用系统设置页
    /// - Parameters: 无
    /// - Returns: Void
    private func openAppSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(settingsURL)
    }
    
    /// 触发 App Store 评分弹窗
    /// - Parameters: 无
    /// - Returns: Void
    private func requestAppReview() {
        requestReview()
    }
    
    /// 打开反馈网站
    /// - Parameters: 无
    /// - Returns: Void
    private func openFeedbackSite() {
        guard let url = URL(string: "https://qingtengstudio.com/") else { return }
        openURL(url)
    }
    
    /// 打开隐私声明链接
    /// - Parameters: 无
    /// - Returns: Void
    private func openPrivacyPolicy() {
        guard let url = URL(string: "https://www.freeprivacypolicy.com/live/5daf2aaa-018e-4125-ab59-34e22297c747") else { return }
        openURL(url)
    }
    
    /// 打开创作者激励页面
    /// - Parameters: 无
    /// - Returns: Void
    private func openCreatorSupport() {
        guard let url = URL(string: "https://buymeacoffee.com/munchymeow") else { return }
        openURL(url)
    }
    
    /// 打开作者 GitHub 页面
    /// - Parameters: 无
    /// - Returns: Void
    private func openCreatorGitHub() {
        guard let url = URL(string: "https://github.com/munchymeow/FocusLive") else { return }
        openURL(url)
    }
    
    /// 打开工作室主页
    /// - Parameters: 无
    /// - Returns: Void
    private func openStudioSite() {
        guard let url = URL(string: "https://qingtengstudio.com/") else { return }
        openURL(url)
    }
    
    /// 获取当前 App 版本号展示文本
    /// - Returns: 版本号字符串
    private func appVersionString() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return String(format: String(localized: "版本 %@（Build %@）"), version, build)
    }
}

struct ProfileItem: Identifiable {
    let id = UUID()
    let titleKey: String
    let subtitleKey: String?
    let iconName: String
    let iconColor: Color
    let trailingTextKey: String?
    let badgeTextKey: String?
}

struct ProfileRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let item: ProfileItem
    let cardBackground: Color
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [item.iconColor.opacity(0.9), item.iconColor.opacity(0.55)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)
                Image(systemName: item.iconName)
                    .foregroundStyle(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(LocalizedStringKey(item.titleKey))
                        .font(.subheadline.weight(.semibold))
                    
                    if let badgeText = item.badgeTextKey {
                        Text(LocalizedStringKey(badgeText))
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.blue.opacity(0.12)))
                            .foregroundStyle(.blue)
                    }
                }
                
                if let subtitle = item.subtitleKey {
                    Text(LocalizedStringKey(subtitle))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            if let trailing = item.trailingTextKey {
                Text(LocalizedStringKey(trailing))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
            }
            
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.6), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.06), radius: 10, x: 0, y: 4)
        )
    }
}

struct ProfilePlaceholderView: View {
    let titleKey: String
    
    var body: some View {
        VStack(spacing: 12) {
            Text(LocalizedStringKey(titleKey))
                .font(.title2.weight(.semibold))
            Text("该功能正在准备中")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(Color(.systemGroupedBackground))
    }
}

#Preview {
    ProfileView()
}
