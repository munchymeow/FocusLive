//
//  BorderlessProfileView.swift
//  FocusLive
//
//  测试版无界我的页：无卡片、无边框、大留白的极简设计
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
    @State private var areActivitiesEnabled = ActivityAuthorizationInfo().areActivitiesEnabled
    @State private var showSubscription = false

    @AppStorage(Self.firstLaunchKey, store: UserDefaults(suiteName: appGroupID))
    private var firstLaunchTimestamp: Double = 0

    @AppStorage(Self.proStatusKey, store: UserDefaults(suiteName: appGroupID))
    private var isProUser: Bool = false

    private var backgroundColor: Color {
        colorScheme == .dark
            ? Color(red: 0.06, green: 0.06, blue: 0.08)
            : Color(red: 0.97, green: 0.97, blue: 0.99)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        // 标题
                        borderlessHeader

                        // 会员
                        borderlessMemberRow

                        // 个性化
                        borderlessSection(title: "个性化") {
                            borderlessNavigationRow(
                                title: "修改锁屏卡片",
                                subtitle: "调整实时活动显示条数与透明度",
                                icon: "square.grid.2x2.fill",
                                iconColor: .orange
                            ) {
                                LiveActivitySettingsView()
                            }
                        }

                        // 通用
                        borderlessSection(title: "通用") {
                            borderlessActionRow(
                                title: areActivitiesEnabled ? "实时活动已开启" : "实时活动权限未开启",
                                subtitle: areActivitiesEnabled ? "可在系统设置中管理" : "实时活动未开启，手机将无法实时显示任务",
                                icon: areActivitiesEnabled ? "checkmark.circle.fill" : "exclamationmark.circle.fill",
                                iconColor: areActivitiesEnabled ? .green : .orange
                            ) {
                                openAppSettings()
                            }
                        }

                        // 其他
                        borderlessSection(title: "其他") {
                            borderlessActionRow(title: "语言设置", icon: "globe", iconColor: .blue) { openAppSettings() }
                            borderlessActionRow(title: "给个好评", icon: "star.fill", iconColor: .blue) { requestReview() }
                            borderlessActionRow(title: "问题反馈", icon: "envelope.fill", iconColor: .blue) { openFeedbackSite() }
                        }

                        // 实验室
                        borderlessSection(title: "实验室") {
                            borderlessNavigationRow(
                                title: "实验室",
                                subtitle: "体验实验性功能与新版 UI",
                                icon: "flask.fill",
                                iconColor: .purple,
                                badge: "Beta"
                            ) {
                                LabView()
                            }
                        }

                        // 关于
                        borderlessSection(title: "关于") {
                            borderlessNavigationRow(title: "软件说明", icon: "doc.text.fill", iconColor: .blue) {
                                SoftwareInfoView()
                            }
                            borderlessActionRow(title: "隐私声明", icon: "hand.raised.fill", iconColor: .purple) { openPrivacyPolicy() }
                            borderlessActionRow(title: "创作者激励", icon: "heart.fill", iconColor: .pink) { openCreatorSupport() }
                        }

                        // 底部
                        borderlessFooter
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 120)
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
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
                Text("你好")
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
                Image(systemName: "crown.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.blue)
                    .frame(width: 36, height: 36)
                Text("成为会员")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - 分组

    private func borderlessSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 0) {
                content()
            }
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
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(iconColor)
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    if let badge {
                        Text(badge)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.purple.opacity(0.1)))
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
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 8)
    }

    // MARK: - 底部

    private var borderlessFooter: some View {
        VStack(spacing: 6) {
            Text("Made By")
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
