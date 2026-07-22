//
//  AISummaryView.swift
//  FocusLive
//
//  Created by 赵豪伟 on 2026/1/22.
//

import SwiftUI
import SwiftData

struct AISummaryView: View {
    @Query private var taskGroups: [TaskGroup]
    @StateObject private var aiService = AISummaryService.shared
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var uiStyle: UIStyleManager
    @EnvironmentObject private var storeKitManager: StoreKitManager

    @AppStorage("aiSummaryEnabled", store: UserDefaults(suiteName: appGroupID))
    private var aiSummaryEnabled: Bool = false

    @AppStorage("isProUser", store: UserDefaults(suiteName: appGroupID))
    private var isProUser: Bool = false

    @AppStorage("aiSummaryTrialUsed", store: UserDefaults(suiteName: appGroupID))
    private var trialUsed: Bool = false

    @State private var showSubscriptionSheet: Bool = false

    private var style: AppUIStyle { uiStyle.selectedStyle }

    private var publicIncompleteGroups: [(group: TaskGroup, tasks: [TaskItem])] {
        taskGroups.compactMap { group in
            guard !(group.isPrivate ?? false) else { return nil }
            let tasks = group.sortedTasks.filter { !($0.isPrivate ?? false) && !$0.isCompleted }
            return tasks.isEmpty ? nil : (group, tasks)
        }
    }

    private var totalIncompleteCount: Int {
        publicIncompleteGroups.reduce(0) { $0 + $1.tasks.count }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // MARK: 1. AI 一句话总结核心卡片
                    summaryHeaderCard

                    // MARK: 2. 锁屏快捷状态卡片
                    lockScreenToggleBanner

                    // MARK: 3. 待办任务清单明细 (AI 总结上下文)
                    taskContextSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .navigationTitle(String(localized: "AI 总结"))
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .sheet(isPresented: $showSubscriptionSheet) {
                SubscriptionView()
                    .environmentObject(storeKitManager)
            }
            .onChange(of: aiService.shouldShowPaywall) { _, newValue in
                if newValue {
                    showSubscriptionSheet = true
                    aiService.shouldShowPaywall = false
                }
            }
            .onAppear {
                // 仅在本地无缓存总结且具备试用/会员权限时尝试初始化生成
                if aiService.latestSummary.isEmpty && !publicIncompleteGroups.isEmpty && aiService.canGenerateSummary() {
                    Task {
                        await aiService.generateSummary(groups: taskGroups)
                    }
                }
            }
        }
    }

    // MARK: - AI 总结核心大卡片（Apple Design 优雅设计）

    private var summaryHeaderCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [Color.blue.opacity(0.9), Color.indigo.opacity(0.9)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 30, height: 30)
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(String(localized: "AI 核心工作重心"))
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.primary)
                            
                            // 会员权益/试用状态 Badge
                            if isProUser {
                                Text("Pro 无限用")
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.orange.opacity(0.15)))
                                    .foregroundStyle(.orange)
                            } else if !trialUsed {
                                Text("免费试用 1 次")
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.blue.opacity(0.12)))
                                    .foregroundStyle(.blue)
                            } else {
                                Button {
                                    showSubscriptionSheet = true
                                } label: {
                                    HStack(spacing: 2) {
                                        Text("试用已用完 · 升级 Pro")
                                        Image(systemName: "chevron.right")
                                    }
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.purple.opacity(0.15)))
                                    .foregroundStyle(.purple)
                                }
                            }
                        }

                        if let date = aiService.lastUpdatedDate {
                            Text(date, style: .time)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                Button {
                    if !isProUser && trialUsed {
                        showSubscriptionSheet = true
                    } else {
                        Task {
                            await aiService.generateSummary(groups: taskGroups, force: true)
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: !isProUser && trialUsed ? "lock.fill" : "arrow.triangle.2.circlepath")
                            .font(.system(size: 12, weight: .semibold))
                            .rotationEffect(.degrees(aiService.isLoading ? 360 : 0))
                            .animation(aiService.isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: aiService.isLoading)
                        Text(aiService.isLoading ? String(localized: "总结中...") : (!isProUser && trialUsed ? String(localized: "解锁 Pro") : String(localized: "重新生成")))
                            .font(.caption.weight(.semibold))
                    }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(!isProUser && trialUsed ? Color.orange.opacity(0.12) : Color.primary.opacity(0.06)))
                    .foregroundStyle(!isProUser && trialUsed ? Color.orange : Color.primary)
                }
                .disabled(aiService.isLoading)
            }

            if aiService.isLoading && aiService.latestSummary.isEmpty {
                HStack(spacing: 12) {
                    ProgressView()
                    Text(String(localized: "AI 正在阅读分析您的待办事项..."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 10)
            } else if let error = aiService.lastError, aiService.latestSummary.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Label(String(localized: "生成总结失败"), systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            } else {
                HStack(alignment: .top, spacing: 12) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(LinearGradient(colors: [.blue, .indigo], startPoint: .top, endPoint: .bottom))
                        .frame(width: 3.5)

                    Text(aiService.latestSummary.isEmpty ? String(localized: "暂无待办事项，无需总结。") : aiService.latestSummary)
                        .font(.system(size: 16, weight: .semibold, design: .default))
                        .lineSpacing(6)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 4)
            }
        }
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.04), radius: 8, y: 3)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
        }
    }

    // MARK: - 锁屏显示控制条

    private var lockScreenToggleBanner: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(aiSummaryEnabled ? Color.blue.opacity(0.12) : Color.secondary.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: aiSummaryEnabled ? "lock.applewatch" : "lock.slash")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(aiSummaryEnabled ? .blue : .secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "锁屏同步 AI 总结"))
                    .font(.subheadline.weight(.semibold))
                Text(aiSummaryEnabled ? String(localized: "已开启，总结内容会自动显示在锁屏与灵动岛") : String(localized: "开启后自动把 AI 总结推送到锁屏实时活动卡片"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: $aiSummaryEnabled)
                .labelsHidden()
                .onChange(of: aiSummaryEnabled) { _, _ in
                    ActivityManager.shared.syncActivities(groups: taskGroups)
                }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.03), radius: 6, y: 2)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
        )
    }

    // MARK: - 参与 AI 总结的任务明细

    private var taskContextSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(String(localized: "分析的待办任务"))
                    .font(.headline)
                Spacer()
                Text(String(format: String(localized: "共 %lld 条待办"), Int64(totalIncompleteCount)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if publicIncompleteGroups.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.green)
                    Text(String(localized: "所有任务均已完成！"))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                        )
                )
            } else {
                ForEach(publicIncompleteGroups, id: \.group.id) { item in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            GroupIcon(name: item.group.iconName, size: 14)
                            Text(item.group.title)
                                .font(.subheadline.weight(.bold))
                            Spacer()
                            Text("\(item.tasks.count)")
                                .font(.caption.weight(.bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.blue.opacity(0.12)))
                                .foregroundStyle(.blue)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(item.tasks, id: \.id) { task in
                                HStack(spacing: 8) {
                                    Image(systemName: "circle")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                    Text(task.title)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                    Spacer()
                                }
                            }
                        }
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(.secondarySystemGroupedBackground))
                            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.03), radius: 6, y: 2)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                            )
                    )
                }
            }
        }
    }
}
