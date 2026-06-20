//
//  ContentView.swift
//  FocusLive
//
//  Created by 赵豪伟 on 2026/1/13.
//

import SwiftUI
import Foundation
import SwiftData

    case all
    case privateSpace
    case completed
    
    var id: String { rawValue }
    
    /// 筛选标题（本地化 Key）
    var titleKey: String {
        switch self {
        case .incomplete:
            return "未完成"
        case .all:
            return "全部"
        case .privateSpace:
            return "隐私空间"
        case .completed:
            return "已完成"
        }
    }
    
    /// 筛选图标
    var iconName: String {
        switch self {
        case .incomplete:
            return "circle"
        case .all:
            return "list.bullet"
        case .privateSpace:
            return "lock.fill"
        case .completed:
            return "checkmark.circle.fill"
        }
    }
    
    /// 筛选显示顺序
    static var displayCases: [TaskFilter] {
        [.all, .incomplete, .completed, .privateSpace]
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query private var taskGroups: [TaskGroup]
    @Environment(\.scenePhase) private var scenePhase
    @State private var activeFilter: TaskFilter = .all
    @State private var isPrivacyUnlocked = false
    @State private var isPrivacyUnlocking = false
    @State private var showPrivacyAlert = false
    @State private var privacyAlertMessage = ""
    @State private var pendingPrivateGroupCreation = false
    @State private var showSubscriptionSheet = false
    @State private var lastNonPrivateFilter: TaskFilter = .all
    @State private var pendingAddTaskType: TaskType = .todo
    @State private var showFirstLaunchTutorial = false
    @State private var showMotivationEditor = false
    @State private var motivationDraftQuote = ""
    @State private var motivationDraftAuthor = ""
    @State private var dataErrorMessage = ""
    @State private var showDataErrorAlert = false
    
    @AppStorage("isProUser", store: UserDefaults(suiteName: appGroupID))
    private var isProUser: Bool = false

    @AppStorage("hasSeenFirstLaunchTutorial", store: UserDefaults(suiteName: appGroupID))
    private var hasSeenFirstLaunchTutorial: Bool = false

    @AppStorage("dailyMotivationEnabled", store: UserDefaults(suiteName: appGroupID))
    private var dailyMotivationEnabled: Bool = true

    @AppStorage(currentMotivationQuoteKey, store: UserDefaults(suiteName: appGroupID))
    private var currentMotivationQuote: String = ""

    @AppStorage(currentMotivationAuthorKey, store: UserDefaults(suiteName: appGroupID))
    private var currentMotivationAuthor: String = ""

    @AppStorage(useCustomMotivationQuoteKey, store: UserDefaults(suiteName: appGroupID))
    private var useCustomMotivationQuote: Bool = false

    @AppStorage(customMotivationQuoteKey, store: UserDefaults(suiteName: appGroupID))
    private var customMotivationQuote: String = ""

    @AppStorage(customMotivationAuthorKey, store: UserDefaults(suiteName: appGroupID))
    private var customMotivationAuthor: String = ""
    
    /// 排序后的分组列表
    private var sortedGroups: [TaskGroup] {
        taskGroups.sorted { ($0.sortOrder ?? 0) < ($1.sortOrder ?? 0) }
    }
    
    /// 背景色 - 适配深浅模式
    private var backgroundColor: Color {
        colorScheme == .dark 
            ? Color(red: 0.08, green: 0.08, blue: 0.10)
            : Color(red: 0.96, green: 0.96, blue: 0.98)
    }
    
    /// 卡片背景色 - 适配深浅模式
    private var cardBackground: Color {
        colorScheme == .dark
            ? Color(red: 0.15, green: 0.15, blue: 0.18)
            : Color.white
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
                backgroundColor
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        headerView
                        filterBar
                        
                        if taskGroups.isEmpty {
                            emptyStateView
                        } else if shouldShowPrivacyLock {
                            privacyLockedView
                        } else {
                            if shouldShowPrivacyBanner {
                                privacyBannerView
                            }
                            
                            statsCard
                            
                            if filteredGroupEntries.isEmpty {
                                filterEmptyStateView
                            } else {
                                ForEach(filteredGroupEntries, id: \.0.id) { group, tasks in
                                    TaskGroupCard(
                                        group: group,
                                        displayTasks: tasks,
                                        modelContext: modelContext,
                                        allowsTaskReorder: allowsTaskReorder,
                                        isProUser: isProUser,
                                        onRequireSubscription: { showSubscriptionSheet = true },
                                        onMoveUp: { moveGroupUp(group) },
                                        onMoveDown: { moveGroupDown(group) },
                                        canMoveUp: sortedGroups.first?.id != group.id,
                                        canMoveDown: sortedGroups.last?.id != group.id
                                    )
                                }
                            }
                        }

                        if shouldShowDailyMotivationCard {
                            dailyMotivationCard
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 120)
                }
            }
            .onAppear {
                // 🔑 核心：App 启动时自动同步 Live Activities
                resetDailyCheckInTasksIfNeeded()
                ensureDailyMotivationLoaded()
                syncPendingChanges()  // 先同步待处理的变更
                syncActivitiesWithGroups()
                presentFirstLaunchTutorialIfNeeded()
            }
            .onChange(of: taskGroups) { _, _ in
                // 当分组发生变化时，自动同步
                syncActivitiesWithGroups()
            }
            .onChange(of: scenePhase) { _, newPhase in
                // 当 App 从后台返回前台时，同步待处理的变更
                if newPhase == .active {
                    resetDailyCheckInTasksIfNeeded()
                    ensureDailyMotivationLoaded()
                    syncPendingChanges()
                    syncActivitiesWithGroups()
                }
                if newPhase != .active {
                    isPrivacyUnlocked = false
                }
            }
            .onChange(of: activeFilter) { _, newValue in
                if newValue == .privateSpace {
                    if !isProUser {
                        activeFilter = lastNonPrivateFilter
                        showSubscriptionSheet = true
                        return
                    }
                    requestPrivacyUnlockIfNeeded()
                } else {
                    lastNonPrivateFilter = newValue
                    isPrivacyUnlocked = false
                    pendingPrivateGroupCreation = false
                }
            }
            .alert(privacyAlertMessage, isPresented: $showPrivacyAlert) {
                Button("知道了", role: .cancel) { }
            }
            .alert("保存失败", isPresented: $showDataErrorAlert) {
                Button("知道了", role: .cancel) { }
            } message: {
                Text(dataErrorMessage)
            }
            .sheet(isPresented: $showSubscriptionSheet) {
                NavigationStack {
                    SubscriptionView()
                }
            }
            .sheet(isPresented: $showFirstLaunchTutorial, onDismiss: {
                hasSeenFirstLaunchTutorial = true
            }) {
                FirstLaunchTutorialView {
                    hasSeenFirstLaunchTutorial = true
                    showFirstLaunchTutorial = false
                    syncActivitiesWithGroups(refreshMotivationContent: true)
                }
            }
            .sheet(isPresented: $showMotivationEditor) {
                MotivationEditorView(
                    initialQuote: motivationDraftQuote,
                    initialAuthor: motivationDraftAuthor
                ) { quote, author in
                    saveCustomMotivation(quote: quote, author: author)
                }
            }
        }
    }
    
    // MARK: - 顶部与筛选视图
    private var headerView: some View {
        HStack(spacing: 12) {
            Text("📋")
                .font(.system(size: 22))
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(Color.blue.opacity(colorScheme == .dark ? 0.25 : 0.12))
                )
            
            VStack(alignment: .leading, spacing: 2) {
                (Text(LocalizedStringKey(activeFilter.titleKey)) + Text(" \(filteredGroupEntries.count)"))
                    .font(.system(size: 26, weight: .bold))
                Text("分组")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Menu {
                addGroupMenuActions
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.blue))
                    .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 3)
            }
            .buttonStyle(.plain)
        }
    }
    
    private var filterBar: some View {
        HStack(spacing: 12) {
            ForEach(TaskFilter.displayCases) { filter in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if filter == .privateSpace && !isProUser {
                            showSubscriptionSheet = true
                        } else {
                            activeFilter = filter
                            if filter != .privateSpace {
                                lastNonPrivateFilter = filter
                            }
                        }
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: filter.iconName)
                            .font(.system(size: 12, weight: .semibold))
                        Text(LocalizedStringKey(filter.titleKey))
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .allowsTightening(true)
                    }
                    .foregroundStyle(activeFilter == filter ? .white : .primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(activeFilter == filter ? Color.blue : cardBackground)
                    )
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.06), radius: 6, x: 0, y: 3)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var privacyLockedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.blue)
            
            Text("隐私空间已锁定")
                .font(.headline)
            
            Text("使用 Face ID 解锁以查看隐私事项")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Button(action: requestPrivacyUnlockIfNeeded) {
                HStack(spacing: 6) {
                    Image(systemName: "faceid")
                    Text("解锁")
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.blue))
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(isPrivacyUnlocking)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(cardBackground)
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.08), radius: 10, x: 0, y: 4)
        )
    }
    
    private var privacyBannerView: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .foregroundStyle(.blue)
            Text("隐私事项已隐藏")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Button(action: requestPrivacyUnlockIfNeeded) {
                Text("解锁")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.blue.opacity(0.12)))
            }
            .buttonStyle(.plain)
            .disabled(isPrivacyUnlocking)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(cardBackground)
        )
    }
    
    private var filterEmptyStateView: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text(filterEmptyStateTitle)
                .font(.headline)
            Text(filterEmptyStateSubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - 筛选逻辑
    /// 判断分组是否为隐私分组
    /// - Parameter group: 任务分组
    /// - Returns: 是否为隐私分组，用于筛选与展示逻辑
    private func isGroupPrivate(_ group: TaskGroup) -> Bool {
        group.isPrivate ?? false
    }
    
    /// 判断任务是否为隐私任务（包含分组级隐私）
    /// - Parameters:
    ///   - task: 任务
    ///   - group: 任务所属分组
    /// - Returns: 是否为隐私任务，用于筛选与锁屏过滤
    private func isTaskPrivate(_ task: TaskItem, in group: TaskGroup) -> Bool {
        (group.isPrivate ?? false) || (task.isPrivate ?? false)
    }

    /// 判断任务是否为提醒事项
    /// - Parameter task: 任务
    /// - Returns: 是否为提醒事项
    private func isReminderTask(_ task: TaskItem) -> Bool {
        task.taskType == .reminder
    }
    
    /// 判断分组在当前筛选下是否需要展示
    /// - Parameter group: 任务分组
    /// - Returns: 是否展示分组
    private func shouldDisplayGroup(_ group: TaskGroup) -> Bool {
        switch activeFilter {
        case .privateSpace:
            return isGroupPrivate(group) || group.tasks.contains { isTaskPrivate($0, in: group) }
        case .all, .incomplete, .completed:
            return !isGroupPrivate(group)
        }
    }
    
    private var filteredGroupEntries: [(TaskGroup, [TaskItem])] {
        sortedGroups.compactMap { group in
            guard shouldDisplayGroup(group) else { return nil }
            let tasks = filteredTasks(for: group)
            if tasks.isEmpty {
                return shouldIncludeEmptyGroup(group) ? (group, tasks) : nil
            }
            return (group, tasks)
        }
    }
    
    private var visibleTasks: [TaskItem] {
        filteredGroupEntries.flatMap { $0.1 }
    }
    
    private var hasPrivateTasks: Bool {
        taskGroups.contains { group in
            isGroupPrivate(group) || group.tasks.contains { $0.isPrivate ?? false }
        }
    }
    
    private var shouldShowPrivacyLock: Bool {
        activeFilter == .privateSpace && !isPrivacyUnlocked
    }
    
    private var shouldShowPrivacyBanner: Bool {
        !isPrivacyUnlocked && hasPrivateTasks && activeFilter != .privateSpace
    }

    private var allowsTaskReorder: Bool {
        activeFilter == .all && (isPrivacyUnlocked || !hasPrivateTasks)
    }
    
    private var filterEmptyStateTitle: String {
        switch activeFilter {
        case .incomplete:
            return "暂无未完成事项"
        case .all:
            return "暂无事项"
        case .privateSpace:
            return "暂无隐私事项"
        case .completed:
            return "暂无已完成事项"
        }
    }
    
    private var filterEmptyStateSubtitle: String {
        switch activeFilter {
        case .incomplete:
            return "完成任务后会自动移出未完成列表"
        case .all:
            return "创建任务开始你的计划"
        case .privateSpace:
            return "将重要事项设为隐私后会显示在这里"
        case .completed:
            return "完成任务后会显示在这里"
        }
    }

    /// 判断空分组在当前筛选下是否需要展示
    /// - Parameter group: 任务分组
    /// - Returns: 是否展示空分组
    private func shouldIncludeEmptyGroup(_ group: TaskGroup) -> Bool {
        switch activeFilter {
        case .all, .incomplete:
            return !isGroupPrivate(group) && group.tasks.isEmpty
        case .privateSpace:
            return isGroupPrivate(group) && group.tasks.isEmpty
        case .completed:
            return false
        }
    }
    
    /// 根据筛选与隐私状态返回分组内可展示的任务
    /// - Parameter group: 任务分组
    /// - Returns: 过滤后的任务列表
    private func filteredTasks(for group: TaskGroup) -> [TaskItem] {
        let sortedTasks = group.sortedTasks
        
        switch activeFilter {
        case .incomplete:
            return sortedTasks.filter { !isTaskPrivate($0, in: group) && (isReminderTask($0) || !$0.isCompleted) }
        case .all:
            return sortedTasks.filter { !isTaskPrivate($0, in: group) }
        case .privateSpace:
            return isPrivacyUnlocked ? sortedTasks.filter { isTaskPrivate($0, in: group) } : []
        case .completed:
            return sortedTasks.filter { !isTaskPrivate($0, in: group) && !isReminderTask($0) && $0.isCompleted }
        }
    }
    
    /// 请求隐私解锁（Face ID/设备验证）
    /// - Returns: Void
    private func requestPrivacyUnlockIfNeeded() {
        guard !isPrivacyUnlocked, !isPrivacyUnlocking else { return }
        isPrivacyUnlocking = true
        
        Task {
            let reason = String(localized: "请验证以查看隐私事项")
            let success = await PrivacyAuthService.shared.requestPrivacyUnlock(reason: reason)
            
            await MainActor.run {
                isPrivacyUnlocking = false
                if success {
                    isPrivacyUnlocked = true
                    if pendingPrivateGroupCreation {
                        pendingPrivateGroupCreation = false
                        createEntry(taskType: pendingAddTaskType, isPrivate: true)
                    }
                } else {
                    privacyAlertMessage = String(localized: "验证失败，请稍后重试")
                    showPrivacyAlert = true
                    pendingPrivateGroupCreation = false
                    pendingAddTaskType = .todo
                }
            }
        }
    }
    
    // MARK: - 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "tray")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            VStack(spacing: 8) {
                Text("还没有任务分组")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("创建你的第一个分组开始吧")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Menu {
                addGroupMenuActions
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                    Text("创建第一个分组")
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [.blue, .cyan],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundStyle(.white)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }
    
    // MARK: - 统计卡片
    private var statsCard: some View {
        let todoTasks = statsTodoTasks
        let totalTasks = todoTasks.count
        let completedTasks = todoTasks.filter { $0.isCompleted }.count
        let progress = totalTasks > 0 ? Double(completedTasks) / Double(totalTasks) : 0
        let groupCount = filteredGroupEntries.count
        
        return HStack(spacing: 16) {
            // 进度环
            ZStack {
                Circle()
                    .stroke(Color.blue.opacity(0.2), lineWidth: 6)
                    .frame(width: 56, height: 56)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 56, height: 56)
                    .rotationEffect(.degrees(-90))
                
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.blue)
            }
            
            VStack(alignment: .leading, spacing: 5) {
                Text("今日进度")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 4) {
                    Text("\(completedTasks)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(String(format: String(localized: "/ %lld 项"), Int64(totalTasks)))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 5) {
                Text("\(groupCount)")
                    .font(.system(size: 18, weight: .semibold))
                Text("个分组")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(cardBackground)
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.05), radius: 10, x: 0, y: 4)
        )
    }

    private var statsTodoTasks: [TaskItem] {
        sortedGroups.flatMap { group -> [TaskItem] in
            guard shouldDisplayGroup(group) else { return [] }
            return group.sortedTasks.filter { task in
                !isReminderTask(task) && isTaskInStatsScope(task, group: group)
            }
        }
    }

    private func isTaskInStatsScope(_ task: TaskItem, group: TaskGroup) -> Bool {
        switch activeFilter {
        case .all, .incomplete, .completed:
            return !isTaskPrivate(task, in: group)
        case .privateSpace:
            return isPrivacyUnlocked && isTaskPrivate(task, in: group)
        }
    }

    private var shouldShowDailyMotivationCard: Bool {
        dailyMotivationEnabled && activeFilter == .all
    }

    @ViewBuilder
    private var addGroupMenuActions: some View {
        Button {
            addNewGroup(taskType: .todo)
        } label: {
            Label("传统待办事项", systemImage: "checklist")
        }

        Button {
            addNewGroup(taskType: .dailyCheckIn)
        } label: {
            Label("每日打卡", systemImage: "calendar.badge.clock")
        }

        Button {
            addNewGroup(taskType: .reminder)
        } label: {
            Label("提醒事项", systemImage: "bell.badge")
        }
    }

    private var isUsingCustomMotivation: Bool {
        useCustomMotivationQuote && !trimmed(customMotivationQuote).isEmpty
    }

    private var displayedMotivationQuote: String {
        if isUsingCustomMotivation {
            return trimmed(customMotivationQuote)
        }

        let quote = trimmed(currentMotivationQuote)
        return quote.isEmpty ? String(localized: "愿你今天也保持专注。") : quote
    }

    private var displayedMotivationAuthor: String? {
        normalizedMotivationAuthor(isUsingCustomMotivation ? customMotivationAuthor : currentMotivationAuthor)
    }

    private var dailyMotivationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Label("每日鼓励", systemImage: "sparkles")
                    .font(.headline)
                    .foregroundStyle(.primary)

                if isUsingCustomMotivation {
                    Text("自定义")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.blue.opacity(colorScheme == .dark ? 0.18 : 0.10))
                        )
                }

                Spacer()
            }

            Text("“\(displayedMotivationQuote)”")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 6) {
                if let author = displayedMotivationAuthor {
                    Text("——\(author)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("每日鼓励会显示在“全部”页的底部，你可以手动换一句，或改成自己的文案。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                Button(action: {
                    refreshRandomMotivation()
                }) {
                    Label(isUsingCustomMotivation ? "使用随机" : "换一句", systemImage: isUsingCustomMotivation ? "shuffle" : "arrow.clockwise")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.blue.opacity(colorScheme == .dark ? 0.20 : 0.12))
                        )
                }
                .buttonStyle(.plain)

                Button(action: beginEditingMotivation) {
                    Label("自定义", systemImage: "square.and.pencil")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(
                            Capsule(style: .continuous)
                                .fill(cardBackground.opacity(colorScheme == .dark ? 0.95 : 1.0))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(cardBackground)
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.22 : 0.06), radius: 10, x: 0, y: 4)
        )
    }
    
    /// 同步 Live Activities
    private func syncActivitiesWithGroups(refreshMotivationContent: Bool = false) {
        Task { @MainActor in
            if refreshMotivationContent {
                ActivityManager.shared.syncActivities(groups: taskGroups)
                ActivityManager.shared.refreshMotivationActivityFromStoredContentIfNeeded()
            } else {
                ActivityManager.shared.scheduleSyncActivities(groups: taskGroups)
            }
        }
    }

    private func presentFirstLaunchTutorialIfNeeded() {
        guard !hasSeenFirstLaunchTutorial, !showFirstLaunchTutorial else { return }
        DispatchQueue.main.async {
            showFirstLaunchTutorial = true
        }
    }

    private func beginEditingMotivation() {
        motivationDraftQuote = isUsingCustomMotivation ? trimmed(customMotivationQuote) : displayedMotivationQuote
        motivationDraftAuthor = isUsingCustomMotivation ? (displayedMotivationAuthor ?? "") : (displayedMotivationAuthor ?? "")
        showMotivationEditor = true
    }

    private func ensureDailyMotivationLoaded() {
        if isUsingCustomMotivation {
            if currentMotivationQuote != displayedMotivationQuote || normalizedMotivationAuthor(currentMotivationAuthor) != displayedMotivationAuthor {
                currentMotivationQuote = displayedMotivationQuote
                currentMotivationAuthor = displayedMotivationAuthor ?? ""
            }
            return
        }

        let defaults = UserDefaults(suiteName: appGroupID)
        let today = Calendar.current.startOfDay(for: Date())
        let lastDate = defaults?.object(forKey: lastMotivationDateKey) as? Date
        let isToday = lastDate.map { Calendar.current.isDate($0, inSameDayAs: today) } ?? false
        let quote = trimmed(currentMotivationQuote)

        guard !isToday || quote.isEmpty else { return }
        refreshRandomMotivation(syncAfterUpdate: false)
    }

    private func refreshRandomMotivation(syncAfterUpdate: Bool = true) {
        let next = randomMotivationFromCSV() ?? (String(localized: "愿你今天也保持专注。"), nil)
        let today = Calendar.current.startOfDay(for: Date())

        useCustomMotivationQuote = false
        currentMotivationQuote = next.quote
        currentMotivationAuthor = next.author ?? ""
        UserDefaults(suiteName: appGroupID)?.set(today, forKey: lastMotivationDateKey)

        if syncAfterUpdate {
            syncActivitiesWithGroups(refreshMotivationContent: true)
        }
    }

    private func saveCustomMotivation(quote: String, author: String) {
        let normalizedQuote = trimmed(quote)
        guard !normalizedQuote.isEmpty else { return }

        let normalizedAuthor = normalizedMotivationAuthor(author)

        customMotivationQuote = normalizedQuote
        customMotivationAuthor = normalizedAuthor ?? ""
        useCustomMotivationQuote = true
        currentMotivationQuote = normalizedQuote
        currentMotivationAuthor = normalizedAuthor ?? ""
        UserDefaults(suiteName: appGroupID)?.set(Calendar.current.startOfDay(for: Date()), forKey: lastMotivationDateKey)

        syncActivitiesWithGroups(refreshMotivationContent: true)
    }

    private func randomMotivationFromCSV() -> (quote: String, author: String?)? {
        guard let url = Bundle.main.url(forResource: "motivational_quotes", withExtension: "csv"),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }

        let quotes = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard let line = quotes.randomElement() else { return nil }
        return parseMotivationLine(line)
    }

    private func parseMotivationLine(_ line: String) -> (quote: String, author: String?) {
        let trimmedLine = trimmed(line)
        guard let range = trimmedLine.range(of: "——", options: .backwards) else {
            return (cleanedMotivationQuote(trimmedLine), nil)
        }

        let rawQuote = String(trimmedLine[..<range.lowerBound])
        let rawAuthor = String(trimmedLine[range.upperBound...])

        return (
            cleanedMotivationQuote(rawQuote),
            normalizedMotivationAuthor(rawAuthor)
        )
    }

    private func cleanedMotivationQuote(_ raw: String) -> String {
        var text = trimmed(raw)
        if text.hasPrefix("\""), text.hasSuffix("\""), text.count >= 2 {
            text.removeFirst()
            text.removeLast()
        }
        return text.trimmingCharacters(in: CharacterSet(charactersIn: "“”\""))
    }

    private func normalizedMotivationAuthor(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let value = trimmed(raw)
        return value.isEmpty ? nil : value
    }

    private func trimmed(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @discardableResult
    private func saveChanges(failureMessage: String) -> Bool {
        saveModelContext(modelContext, failureMessage: failureMessage) { message in
            dataErrorMessage = message
            showDataErrorAlert = true
        }
    }
    
    /// 从 App Groups 同步待处理的变更（锁屏上的操作）
    private func syncPendingChanges() {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        guard let pendingChanges = defaults.array(forKey: "pendingTaskChanges") as? [[String: Any]] else { return }
        
        guard !pendingChanges.isEmpty else { return }
        
        debugLog("📥 发现 \(pendingChanges.count) 个待同步的变更")
        
        for change in pendingChanges {
            guard let groupIDStr = change["groupID"] as? String,
                  let taskIDStr = change["taskID"] as? String,
                  let isCompleted = change["isCompleted"] as? Bool else {
                continue
            }
            
            let timestamp = change["timestamp"] as? TimeInterval ?? Date().timeIntervalSince1970
            let changeDate = Date(timeIntervalSince1970: timestamp)
            
            // 查找对应的分组和任务
            if let group = taskGroups.first(where: { $0.id.uuidString == groupIDStr }),
               let task = group.tasks.first(where: { $0.id.uuidString == taskIDStr }) {
                if task.taskType == .reminder {
                    continue
                }
                
                // 如果是每日打卡任务，且变更发生在今天之前，则忽略该变更
                if task.taskType == .dailyCheckIn {
                    let today = Calendar.current.startOfDay(for: Date())
                    if changeDate < today {
                        continue
                    }
                }
                
                // 更新任务状态
                if task.isCompleted != isCompleted {
                    task.isCompleted = isCompleted
                    debugLog("   ✅ 同步任务 '\(task.title)' 状态为: \(isCompleted)")
                }
            }
        }
        
        guard saveChanges(failureMessage: "同步锁屏变更失败") else { return }

        defaults.removeObject(forKey: "pendingTaskChanges")
        debugLog("📥 待处理变更已全部同步")
    }
    
    /// 检查并重置每日打卡任务
    private func resetDailyCheckInTasksIfNeeded() {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        let today = Calendar.current.startOfDay(for: Date())
        
        let lastResetDate = defaults.object(forKey: lastDailyCheckInResetDateKey) as? Date
        
        if lastResetDate == nil || lastResetDate! < today {
            var hasChanges = false
            for group in taskGroups {
                for task in group.tasks {
                    if task.taskType == .dailyCheckIn && task.isCompleted {
                        task.isCompleted = false
                        hasChanges = true
                    }
                }
            }
            
            if hasChanges {
                guard saveChanges(failureMessage: "重置每日打卡失败") else { return }
                debugLog("🔄 每日打卡任务已重置")
            }
            
            defaults.set(today, forKey: lastDailyCheckInResetDateKey)
        }
    }
    
    /// 添加新组件（传统待办分组 / 提醒事项分组）
    /// - Returns: Void
    private func addNewGroup(taskType: TaskType) {
        if activeFilter == .privateSpace {
            if !isProUser {
                showSubscriptionSheet = true
                return
            }
            if isPrivacyUnlocked {
                createEntry(taskType: taskType, isPrivate: true)
            } else {
                pendingPrivateGroupCreation = true
                pendingAddTaskType = taskType
                requestPrivacyUnlockIfNeeded()
            }
        } else {
            createEntry(taskType: taskType, isPrivate: false)
        }
    }

    /// 根据任务类型创建对应入口
    /// - Parameters:
    ///   - taskType: 任务类型
    ///   - isPrivate: 是否为隐私分组
    private func createEntry(taskType: TaskType, isPrivate: Bool) {
        switch taskType {
        case .todo:
            createGroup(isPrivate: isPrivate)
        case .dailyCheckIn:
            createDailyCheckInGroup(isPrivate: isPrivate)
        case .reminder:
            createReminderGroup(isPrivate: isPrivate)
        }
    }
    
    /// 创建新分组并写入数据库
    /// - Parameter isPrivate: 是否为隐私分组
    /// - Returns: Void
    private func createGroup(isPrivate: Bool) {
        let maxOrder = taskGroups.compactMap { $0.sortOrder }.max() ?? -1
        let title = String(format: String(localized: "新分组 %lld"), Int64(taskGroups.count + 1))
        let newGroup = TaskGroup(
            title: title,
            iconName: "📁",
            isPrivate: isPrivate,
            sortOrder: maxOrder + 1,
            tasks: []
        )
        modelContext.insert(newGroup)
        saveChanges(failureMessage: "创建分组失败")
    }

    /// 创建每日打卡分组
    /// - Parameter isPrivate: 是否为隐私分组
    private func createDailyCheckInGroup(isPrivate: Bool) {
        let maxOrder = taskGroups.compactMap { $0.sortOrder }.max() ?? -1
        let title = String(format: String(localized: "新打卡分组 %lld"), Int64(taskGroups.count + 1))
        let checkInGroup = TaskGroup(
            title: title,
            iconName: "📅",
            isPrivate: isPrivate,
            sortOrder: maxOrder + 1,
            tasks: []
        )
        let checkInTask = TaskItem(
            title: String(localized: "新打卡"),
            isCompleted: false,
            isPrivate: isPrivate,
            taskType: .dailyCheckIn,
            sortOrder: 0
        )
        checkInGroup.tasks.append(checkInTask)
        modelContext.insert(checkInGroup)
        saveChanges(failureMessage: "创建打卡分组失败")
    }

    /// 创建提醒事项分组，并自动创建一条提醒事项
    /// - Parameter isPrivate: 是否为隐私分组
    private func createReminderGroup(isPrivate: Bool) {
        let maxOrder = taskGroups.compactMap { $0.sortOrder }.max() ?? -1
        let title = String(format: String(localized: "新提醒分组 %lld"), Int64(taskGroups.count + 1))
        let reminderGroup = TaskGroup(
            title: title,
            iconName: "🔔",
            isPrivate: isPrivate,
            sortOrder: maxOrder + 1,
            tasks: []
        )
        let reminderTask = TaskItem(
            title: String(localized: "新提醒"),
            isCompleted: false,
            isPrivate: isPrivate,
            taskType: .reminder,
            sortOrder: 0
        )
        reminderGroup.tasks.append(reminderTask)
        modelContext.insert(reminderGroup)
        saveChanges(failureMessage: "创建提醒分组失败")
    }
    
    /// 上移分组
    private func moveGroupUp(_ group: TaskGroup) {
        let sorted = sortedGroups
        guard let index = sorted.firstIndex(where: { $0.id == group.id }), index > 0 else { return }
        let prevGroup = sorted[index - 1]
        let tempOrder = group.sortOrder ?? 0
        group.sortOrder = prevGroup.sortOrder ?? 0
        prevGroup.sortOrder = tempOrder
        if saveChanges(failureMessage: "调整分组顺序失败") {
            syncActivitiesWithGroups()
        }
    }

    /// 下移分组
    private func moveGroupDown(_ group: TaskGroup) {
        let sorted = sortedGroups
        guard let index = sorted.firstIndex(where: { $0.id == group.id }), index < sorted.count - 1 else { return }
        let nextGroup = sorted[index + 1]
        let tempOrder = group.sortOrder ?? 0
        group.sortOrder = nextGroup.sortOrder ?? 0
        nextGroup.sortOrder = tempOrder
        if saveChanges(failureMessage: "调整分组顺序失败") {
            syncActivitiesWithGroups()
        }
    }
    
    /// 结束所有 Live Activities
    private func endAllActivities() {
        ActivityManager.shared.endAllActivities()
    }
    
}

#Preview {
    ContentView()
        .modelContainer(for: TaskGroup.self, inMemory: true)
}
