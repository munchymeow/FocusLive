//
//  BorderlessProfileView.swift
//  FocusLive
//
//  测试版无界我的页：Ambient Glass 设计语言
//  三层视觉：环境光晕 + 毛玻璃内容层 + 渐变交互层
//

import SwiftUI
import ActivityKit
import StoreKit
import UIKit

struct BorderlessProfileView: View {
    private static let firstLaunchKey = "firstLaunchTimestamp"
    private static let proStatusKey = "isProUser"

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL
    @Environment(\.requestReview) private var requestReview
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var uiStyle: UIStyleManager
    @State private var areActivitiesEnabled = ActivityAuthorizationInfo().areActivitiesEnabled
    @State private var showSubscription = false

    private var style: AppUIStyle { uiStyle.selectedStyle }

    @AppStorage(Self.firstLaunchKey, store: UserDefaults(suiteName: appGroupID))
    private var firstLaunchTimestamp: Double = 0

    @AppStorage(Self.proStatusKey, store: UserDefaults(suiteName: appGroupID))
    private var isProUser: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                style.background(for: colorScheme).ignoresSafeArea()
                AmbientBlobs(style: style)

                ScrollView {
                    VStack(alignment: .leading, spacing: style.sectionSpacing) {
                        borderlessHeader
                        borderlessMemberRow

                        borderlessSection(title: String(localized: "个性化")) {
                            borderlessNavigationRow(
                                title: String(localized: "修改锁屏卡片"),
                                subtitle: String(localized: "调整实时活动显示条数与透明度"),
                                icon: "square.grid.2x2.fill",
                                iconColor: .orange
                            ) {
                                LiveActivitySettingsView()
                            }
                        }

                        borderlessSection(title: String(localized: "通用")) {
                            borderlessActionRow(
                                title: areActivitiesEnabled
                                    ? String(localized: "实时活动已开启")
                                    : String(localized: "实时活动权限未开启"),
                                subtitle: areActivitiesEnabled
                                    ? String(localized: "可在系统设置中管理")
                                    : String(localized: "放心～更新频率低不耗电。"),
                                icon: areActivitiesEnabled ? "checkmark.circle.fill" : "exclamationmark.circle.fill",
                                iconColor: areActivitiesEnabled ? .green : .orange
                            ) {
                                openAppSettings()
                            }
                        }

                        borderlessSection(title: String(localized: "其他")) {
                            borderlessActionRow(title: String(localized: "语言设置"), icon: "globe", iconColor: .blue) { openAppSettings() }
                            borderlessActionRow(title: String(localized: "给个好评"), icon: "star.fill", iconColor: .blue) { requestReview() }
                            borderlessActionRow(title: String(localized: "问题反馈"), icon: "envelope.fill", iconColor: .blue) { openFeedbackSite() }
                        }

                        borderlessSection(title: String(localized: "实验室")) {
                            borderlessNavigationRow(
                                title: String(localized: "实验室"),
                                subtitle: String(localized: "体验实验性功能与新版 UI"),
                                icon: "flask.fill",
                                iconColor: .purple,
                                badge: String(localized: "Beta")
                            ) {
                                LabView()
                            }
                        }

                        borderlessSection(title: String(localized: "关于")) {
                            borderlessNavigationRow(title: String(localized: "软件说明"), icon: "doc.text.fill", iconColor: .blue) {
                                SoftwareInfoView()
                            }
                            borderlessActionRow(title: String(localized: "隐私声明"), icon: "hand.raised.fill", iconColor: .purple) { openPrivacyPolicy() }
                            borderlessActionRow(title: String(localized: "创作者激励"), icon: "heart.fill", iconColor: .pink) { openCreatorSupport() }
                        }

                        borderlessFooter
                    }
                    .padding(.horizontal, style.pagePadding)
                    .padding(.top, 12)
                    .padding(.bottom, 120)
                }
            }
            .navigationTitle("")
            .toolbar(.hidden, for: .navigationBar)
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

    // MARK: - 标题

    private var borderlessHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(String(localized: "感谢您使用 FocusScreen"))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Image(isProUser ? "logoPro" : "logo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 22)
            }
            Text(String(format: String(localized: "这是它陪伴你的第 %lld 天"), Int64(dayCount())))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - 会员

    private var borderlessMemberRow: some View {
        NavigationLink { SubscriptionView() } label: {
            HStack(spacing: 14) {
                iconBadge(systemName: "crown.fill", color: .blue)
                Text(String(localized: "成为会员"))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                chevron
            }
            .padding(14)
            .styledGlassCard(style)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }

    // MARK: - 分组

    private func borderlessSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
            VStack(alignment: .leading, spacing: 6) {
                content()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                    .fill(style.cardFill(for: colorScheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                            .stroke(style.cardBorder(for: colorScheme), lineWidth: 0.5)
                    )
            )
            .shadow(color: style.cardShadow(for: colorScheme), radius: 8, y: 3)
        }
    }

    // MARK: - 行

    private func borderlessNavigationRow<Destination: View>(
        title: String,
        subtitle: String? = nil,
        icon: String,
        iconColor: Color,
        badge: String? = nil,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink { destination() } label: {
            borderlessRowContent(title: title, subtitle: subtitle, icon: icon, iconColor: iconColor, badge: badge)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }

    private func borderlessActionRow(
        title: String,
        subtitle: String? = nil,
        icon: String,
        iconColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            borderlessRowContent(title: title, subtitle: subtitle, icon: icon, iconColor: iconColor, badge: nil)
        }
        .buttonStyle(.plain)
    }

    private func borderlessRowContent(title: String, subtitle: String?, icon: String, iconColor: Color, badge: String?) -> some View {
        HStack(spacing: 14) {
            iconBadge(systemName: icon, color: iconColor)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    if let badge {
                        Text(badge)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.purple.opacity(0.15), Color.purple.opacity(0.08)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                            .foregroundStyle(.purple)
                    }
                }
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            chevron
        }
        .padding(.vertical, 10)
    }

    // MARK: - 共享组件

    private func iconBadge(systemName: String, color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: style.cornerRadius * 0.5, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.9), color.opacity(0.55)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 36, height: 36)
            Image(systemName: systemName)
                .font(.system(size: 16))
                .foregroundStyle(.white)
        }
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.tertiary)
    }

    // MARK: - 底部

    private var borderlessFooter: some View {
        VStack(spacing: 6) {
            Text(String(localized: "Made By"))
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                Button("munchymeow") { openCreatorGitHub() }
                    .font(.caption.weight(.semibold))
                Text("×")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("QingTengStudio") { openStudioSite() }
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

    // MARK: - 辅助方法

    private func refreshActivityAuthorization() {
        areActivitiesEnabled = ActivityAuthorizationInfo().areActivitiesEnabled
    }

    private func ensureFirstLaunchTimestamp() {
        if firstLaunchTimestamp == 0 {
            firstLaunchTimestamp = Date().timeIntervalSince1970
        }
    }

    private func dayCount() -> Int {
        let startDate = Date(timeIntervalSince1970: firstLaunchTimestamp == 0 ? Date().timeIntervalSince1970 : firstLaunchTimestamp)
        let days = Calendar.current.dateComponents([.day], from: startDate, to: Date()).day ?? 0
        return max(days + 1, 1)
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }

    private func openFeedbackSite() {
        guard let url = URL(string: "https://qingtengstudio.com/") else { return }
        openURL(url)
    }

    private func openPrivacyPolicy() {
        guard let url = URL(string: "https://www.freeprivacypolicy.com/live/5daf2aaa-018e-4125-ab59-34e22297c747") else { return }
        openURL(url)
    }

    private func openCreatorSupport() {
        guard let url = URL(string: "https://buymeacoffee.com/munchymeow") else { return }
        openURL(url)
    }

    private func openCreatorGitHub() {
        guard let url = URL(string: "https://github.com/munchymeow/FocusLive") else { return }
        openURL(url)
    }

    private func openStudioSite() {
        guard let url = URL(string: "https://qingtengstudio.com/") else { return }
        openURL(url)
    }

    private func appVersionString() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return String(format: String(localized: "版本 %@（Build %@）"), version, build)
    }
}

#Preview {
    BorderlessProfileView()
}
