//
//  BorderlessContentView.swift
//  FocusLive
//
//  测试版无界首页：Ambient Glass 设计语言
//  三层视觉：环境光晕 + 毛玻璃内容层 + 渐变交互层
//

import SwiftUI
import SwiftData
import WidgetKit

struct BorderlessContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Query private var taskGroups: [TaskGroup]

    @State private var activeFilter: TaskFilter = .all
    @State private var isPrivacyUnlocked = false
    @State private var isPrivacyUnlocking = false
    @State private var showPrivacyAlert = false
    @State private var privacyAlertMessage = ""
    @State private var showSubscriptionSheet = false
    @State private var lastNonPrivateFilter: TaskFilter = .all
    @State private var pendingAddTaskType: TaskType = .todo
    @State private var pendingPrivateGroupCreation = false

    // 首次启动教程
    @State private var showFirstLaunchTutorial = false

    // 每日激励
    @State private var showMotivationEditor = false
    @State private var motivationDraftQuote = ""
    @State private var motivationDraftAuthor = ""

    // 数据错误
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

    // MARK: - 数据流（复用 ContentView 的筛选逻辑）

    private var sortedGroups: [TaskGroup] {
        taskGroups.sorted { ($0.sortOrder ?? 0) < ($1.sortOrder ?? 0) }
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

    private func isGroupPrivate(_ group: TaskGroup) -> Bool {
        group.isPrivate ?? false
    }

    private func isTaskPrivate(_ task: TaskItem, in group: TaskGroup) -> Bool {
        (group.isPrivate ?? false) || (task.isPrivate ?? false)
    }

    private func shouldDisplayGroup(_ group: TaskGroup) -> Bool {
        switch activeFilter {
        case .privateSpace:
            return isGroupPrivate(group) || group.tasks.contains { isTaskPrivate($0, in: group) }
        case .all, .incomplete, .completed:
            return !isGroupPrivate(group)
        }
    }

    private func filteredTasks(for group: TaskGroup) -> [TaskItem] {
        let sorted = group.sortedTasks
        switch activeFilter {
        case .incomplete:
            return sorted.filter { !isTaskPrivate($0, in: group) && ($0.taskType == .reminder || !$0.isCompleted) }
        case .all:
            return sorted.filter { !isTaskPrivate($0, in: group) }
        case .privateSpace:
            return isPrivacyUnlocked ? sorted.filter { isTaskPrivate($0, in: group) } : []
        case .completed:
            return sorted.filter { !isTaskPrivate($0, in: group) && $0.taskType != .reminder && $0.isCompleted }
        }
    }

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

    // 筛选空状态文案
    private var filterEmptyStateTitle: String {
        switch activeFilter {
        case .incomplete: return String(localized: "暂无未完成事项")
        case .all: return String(localized: "暂无事项")
        case .privateSpace: return String(localized: "暂无隐私事项")
        case .completed: return String(localized: "暂无已完成事项")
        }
    }

    private var filterEmptyStateSubtitle: String {
        switch activeFilter {
        case .incomplete: return String(localized: "完成任务后会自动移出未完成列表")
        case .all: return String(localized: "创建任务开始你的计划")
        case .privateSpace: return String(localized: "将重要事项设为隐私后会显示在这里")
        case .completed: return String(localized: "完成任务后会显示在这里")
        }
    }

    // 每日激励
    private var shouldShowDailyMotivationCard: Bool {
        dailyMotivationEnabled && activeFilter == .all && !taskGroups.isEmpty
    }

    private var isUsingCustomMotivation: Bool {
        useCustomMotivationQuote && !customMotivationQuote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var displayedMotivationQuote: String {
        if isUsingCustomMotivation {
            return trimmed(customMotivationQuote)
        }
        let quote = trimmed(currentMotivationQuote)
        return quote.isEmpty ? String(localized: "愿你今天也保持专注。") : quote
    }

    private var displayedMotivationAuthor: String? {
        let raw: String = isUsingCustomMotivation ? customMotivationAuthor : currentMotivationAuthor
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            mainContent
        }
    }

    private var mainContent: some View {
        ZStack {
            AmbientGlass.background(for: colorScheme).ignoresSafeArea()
            AmbientBlobs()

            ScrollView {
                VStack(alignment: .leading, spacing: AmbientGlass.sectionSpacing) {
                    borderlessHeader
                    borderlessFilterBar

                    if taskGroups.isEmpty {
                        borderlessEmptyState
                    } else if shouldShowPrivacyLock {
                        borderlessPrivacyLock
                    } else {
                        mainContentBody
                    }
                }
                .padding(.horizontal, AmbientGlass.pagePadding)
                .padding(.top, 12)
                .padding(.bottom, 120)
            }
        }
        .onAppear(perform: handleAppear)
        .onChange(of: taskGroups) { _, _ in syncActivitiesWithGroups() }
        .onChange(of: scenePhase) { _, newPhase in handleScenePhaseChange(newPhase) }
        .onChange(of: activeFilter) { _, newValue in handleFilterChange(newValue) }
        .modifier(BorderlessAlerts(
            privacyAlertMessage: privacyAlertMessage,
            showPrivacyAlert: $showPrivacyAlert,
            dataErrorMessage: dataErrorMessage,
            showDataErrorAlert: $showDataErrorAlert,
            showSubscriptionSheet: $showSubscriptionSheet,
            showFirstLaunchTutorial: $showFirstLaunchTutorial,
            hasSeenFirstLaunchTutorial: $hasSeenFirstLaunchTutorial,
            showMotivationEditor: $showMotivationEditor,
            motivationDraftQuote: motivationDraftQuote,
            motivationDraftAuthor: motivationDraftAuthor,
            onTutorialDismiss: { [self] in
                self.syncActivitiesWithGroups()
            },
            onSaveMotivation: { quote, author in
                saveCustomMotivation(quote: quote, author: author)
            }
        ))
    }

    @ViewBuilder
    private var mainContentBody: some View {
        if shouldShowPrivacyBanner {
            borderlessPrivacyBanner
        }

        borderlessStats

        groupListContent

        if shouldShowDailyMotivationCard {
            borderlessMotivationCard
        }
    }

    private func handleAppear() {
        resetDailyCheckInTasksIfNeeded()
        ensureDailyMotivationLoaded()
        syncPendingChanges()
        syncActivitiesWithGroups()
        presentFirstLaunchTutorialIfNeeded()
    }

    // MARK: - 无界标题

    private var borderlessHeader: some View {
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey(activeFilter.titleKey))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text(String(format: String(localized: "%lld 个分组"), Int64(filteredGroupEntries.count)))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()

            Menu {
                Button { addNewGroup(taskType: .todo) } label: {
                    Label(String(localized: "传统待办事项"), systemImage: "checklist")
                }
                Button { addNewGroup(taskType: .dailyCheckIn) } label: {
                    Label(String(localized: "每日打卡"), systemImage: "calendar.badge.clock")
                }
                Button { addNewGroup(taskType: .reminder) } label: {
                    Label(String(localized: "提醒事项"), systemImage: "bell.badge.fill")
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(AmbientGlass.accentGradient))
                    .shadow(color: Color.blue.opacity(0.3), radius: 8, y: 4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "添加新分组"))
        }
    }

    // MARK: - 无界筛选栏

    private var borderlessFilterBar: some View {
        HStack(spacing: 8) {
            ForEach(TaskFilter.displayCases) { filter in
                let isActive = activeFilter == filter
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if filter == .privateSpace && !isProUser {
                            showSubscriptionSheet = true
                        } else {
                            activeFilter = filter
                            if filter != .privateSpace { lastNonPrivateFilter = filter }
                        }
                    }
                } label: {
                    Text(LocalizedStringKey(filter.titleKey))
                        .font(.subheadline.weight(isActive ? .semibold : .regular))
                        .foregroundStyle(isActive ? .white : .secondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            Group {
                                if isActive {
                                    Capsule()
                                        .fill(AmbientGlass.accentGradientHorizontal)
                                        .shadow(color: Color.blue.opacity(0.25), radius: 6, y: 3)
                                } else {
                                    Capsule()
                                        .fill(AmbientGlass.glassFill(for: colorScheme))
                                        .overlay(Capsule().stroke(AmbientGlass.glassBorder(for: colorScheme), lineWidth: 0.5))
                                }
                            }
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(LocalizedStringKey(filter.titleKey))
                .accessibilityAddTraits(isActive ? .isSelected : [])
            }
            Spacer()
        }
    }

    // MARK: - 无界统计

    private var borderlessStats: some View {
        let todoTasks = sortedGroups.flatMap { group -> [TaskItem] in
            guard shouldDisplayGroup(group) else { return [] }
            return group.sortedTasks.filter { $0.taskType != .reminder && !isTaskPrivate($0, in: group) }
        }
        let total = todoTasks.count
        let completed = todoTasks.filter { $0.isCompleted }.count
        let progress = total > 0 ? Double(completed) / Double(total) : 0

        return HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.blue.opacity(colorScheme == .dark ? 0.15 : 0.12), lineWidth: 5)
                    .frame(width: 48, height: 48)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(AmbientGlass.accentGradient, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 48, height: 48)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.4), value: progress)
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(AmbientGlass.accentGradientHorizontal)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: String(localized: "%lld/%lld 已完成"), Int64(completed), Int64(total)))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                Text(String(format: String(localized: "%lld 个分组"), Int64(filteredGroupEntries.count)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .glassCard()
    }

    // MARK: - 分组列表

    @ViewBuilder
    private var groupListContent: some View {
        if filteredGroupEntries.isEmpty {
            filterEmptyStateView
        } else {
            ForEach(filteredGroupEntries, id: \.0.id) { entry in
                borderlessGroupSection(group: entry.0, tasks: entry.1)
            }
        }
    }

    // MARK: - 无界分组

    private func borderlessGroupSection(group: TaskGroup, tasks: [TaskItem]) -> some View {
        VStack(alignment: .leading, spacing: AmbientGlass.groupSpacing) {
            // 分组标题
            HStack(spacing: 12) {
                GroupIcon(name: group.iconName, size: 18, tint: .blue)
                Text(group.title)
                    .font(.system(size: 20, weight: .bold))
                Spacer()
                let completed = tasks.filter { $0.isCompleted }.count
                Text("\(completed)/\(tasks.count)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            // 任务列表
            VStack(alignment: .leading, spacing: 2) {
                ForEach(tasks) { task in
                    borderlessTaskRow(task: task, group: group)
                }
            }
        }
        .padding(16)
        .glassCard()
    }

    private func borderlessTaskRow(task: TaskItem, group: TaskGroup) -> some View {
        HStack(spacing: AmbientGlass.rowSpacing) {
            // 渐变完成按钮
            Button {
                withAnimation(.spring(duration: 0.25)) {
                    toggleTask(task)
                }
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            } label: {
                ZStack {
                    if task.isCompleted {
                        Circle()
                            .fill(AmbientGlass.successGradient)
                            .frame(width: 24, height: 24)
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    } else {
                        Circle()
                            .stroke(AmbientGlass.glassBorder(for: colorScheme), lineWidth: 1.5)
                            .frame(width: 24, height: 24)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(task.isCompleted ? String(localized: "标记为未完成") : String(localized: "标记为已完成"))

            // 标题与元信息
            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .font(.system(size: 16, weight: .medium))
                    .strikethrough(task.isCompleted && task.taskType != .reminder)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)

                if let scheduledTime = task.scheduledTime {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 11))
                        Text(scheduledTime, style: .date)
                        Text(scheduledTime, style: .time)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let priority = task.priority, priority == .urgent || priority == .high {
                Image(systemName: priority == .urgent ? "exclamationmark.3" : "exclamationmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(priority == .urgent ? .red : .orange)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
    }

    // MARK: - 隐私横幅

    private var borderlessPrivacyBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .foregroundStyle(.blue)
            Text(String(localized: "隐私事项已隐藏"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Button(action: requestPrivacyUnlockIfNeeded) {
                Text(String(localized: "解锁"))
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
            RoundedRectangle(cornerRadius: AmbientGlass.smallCornerRadius, style: .continuous)
                .fill(AmbientGlass.glassFill(for: colorScheme))
        )
    }

    // MARK: - 筛选空状态

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

    // MARK: - 空状态

    private var borderlessEmptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.12), Color.cyan.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                Image(systemName: "tray")
                    .font(.system(size: 32))
                    .foregroundStyle(AmbientGlass.accentGradient)
            }
            VStack(spacing: 8) {
                Text(String(localized: "还没有任务分组"))
                    .font(.title3.weight(.semibold))
                Text(String(localized: "点击右上角 + 创建你的第一个分组"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    private var borderlessPrivacyLock: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.12), Color.cyan.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 72, height: 72)
                Image(systemName: "lock.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(AmbientGlass.accentGradient)
            }
            Text(String(localized: "隐私空间已锁定"))
                .font(.headline)
            Button {
                requestPrivacyUnlockIfNeeded()
            } label: {
                Label(String(localized: "解锁"), systemImage: "faceid")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(AmbientGlass.accentGradient))
                    .foregroundStyle(.white)
                    .shadow(color: Color.blue.opacity(0.3), radius: 8, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(isPrivacyUnlocking)
            .overlay {
                if isPrivacyUnlocking {
                    ProgressView()
                        .tint(.white)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - 每日激励卡片

    private var borderlessMotivationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Label(String(localized: "每日鼓励"), systemImage: "sparkles")
                    .font(.headline)
                    .foregroundStyle(.primary)

                if isUsingCustomMotivation {
                    Text(String(localized: "自定义"))
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

            Text("\"\(displayedMotivationQuote)\"")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            if let author = displayedMotivationAuthor {
                Text("——\(author)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                Button(action: refreshRandomMotivation) {
                    Label(isUsingCustomMotivation ? String(localized: "使用随机") : String(localized: "换一句"),
                          systemImage: isUsingCustomMotivation ? "shuffle" : "arrow.clockwise")
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
                    Label(String(localized: "自定义"), systemImage: "square.and.pencil")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(
                            Capsule(style: .continuous)
                                .fill(AmbientGlass.glassFill(for: colorScheme))
                                .overlay(Capsule().stroke(AmbientGlass.glassBorder(for: colorScheme), lineWidth: 0.5))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .glassCard()
    }

    // MARK: - 场景切换

    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
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

    // MARK: - 筛选切换

    private func handleFilterChange(_ newValue: TaskFilter) {
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

    // MARK: - 操作

    private func toggleTask(_ task: TaskItem) {
        task.isCompleted.toggle()
        saveModelContext(modelContext, failureMessage: String(localized: "更新任务状态失败")) { message in
            dataErrorMessage = message
            showDataErrorAlert = true
        }
        WidgetCenter.shared.reloadAllTimelines()
        syncActivitiesWithGroups()
    }

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

    private func createGroup(isPrivate: Bool) {
        let maxOrder = taskGroups.compactMap { $0.sortOrder }.max() ?? -1
        let title = String(format: String(localized: "新分组 %lld"), Int64(taskGroups.count + 1))
        let newGroup = TaskGroup(
            title: title,
            iconName: "folder.fill",
            isPrivate: isPrivate,
            sortOrder: maxOrder + 1,
            tasks: []
        )
        modelContext.insert(newGroup)
        saveModelContext(modelContext, failureMessage: String(localized: "创建分组失败")) { message in
            dataErrorMessage = message
            showDataErrorAlert = true
        }
    }

    private func createDailyCheckInGroup(isPrivate: Bool) {
        let maxOrder = taskGroups.compactMap { $0.sortOrder }.max() ?? -1
        let title = String(format: String(localized: "新打卡分组 %lld"), Int64(taskGroups.count + 1))
        let checkInGroup = TaskGroup(
            title: title,
            iconName: "calendar",
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
        saveModelContext(modelContext, failureMessage: String(localized: "创建打卡分组失败")) { message in
            dataErrorMessage = message
            showDataErrorAlert = true
        }
    }

    private func createReminderGroup(isPrivate: Bool) {
        let maxOrder = taskGroups.compactMap { $0.sortOrder }.max() ?? -1
        let title = String(format: String(localized: "新提醒分组 %lld"), Int64(taskGroups.count + 1))
        let reminderGroup = TaskGroup(
            title: title,
            iconName: "bell.badge.fill",
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
        saveModelContext(modelContext, failureMessage: String(localized: "创建提醒分组失败")) { message in
            dataErrorMessage = message
            showDataErrorAlert = true
        }
    }

    private func syncActivitiesWithGroups() {
        Task { @MainActor in
            ActivityManager.shared.scheduleSyncActivities(groups: taskGroups)
        }
    }

    // MARK: - 锁屏变更同步

    private func syncPendingChanges() {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        guard let pendingChanges = defaults.array(forKey: "pendingTaskChanges") as? [[String: Any]] else { return }
        guard !pendingChanges.isEmpty else { return }

        for change in pendingChanges {
            guard let groupIDStr = change["groupID"] as? String,
                  let taskIDStr = change["taskID"] as? String,
                  let isCompleted = change["isCompleted"] as? Bool else {
                continue
            }

            let timestamp = change["timestamp"] as? TimeInterval ?? Date().timeIntervalSince1970
            let changeDate = Date(timeIntervalSince1970: timestamp)

            if let group = taskGroups.first(where: { $0.id.uuidString == groupIDStr }),
               let task = group.tasks.first(where: { $0.id.uuidString == taskIDStr }) {
                if task.taskType == .reminder { continue }
                if task.taskType == .dailyCheckIn {
                    let today = Calendar.current.startOfDay(for: Date())
                    if changeDate < today { continue }
                }
                if task.isCompleted != isCompleted {
                    task.isCompleted = isCompleted
                }
            }
        }

        saveModelContext(modelContext, failureMessage: String(localized: "同步锁屏变更失败")) { message in
            dataErrorMessage = message
            showDataErrorAlert = true
        }
        defaults.removeObject(forKey: "pendingTaskChanges")
    }

    // MARK: - 每日打卡重置

    private func resetDailyCheckInTasksIfNeeded() {
        let defaults = UserDefaults(suiteName: appGroupID)
        let lastReset = defaults?.object(forKey: lastDailyCheckInResetDateKey) as? Date
        let today = Calendar.current.startOfDay(for: Date())

        if let lastReset, Calendar.current.isDate(lastReset, inSameDayAs: today) { return }

        for group in taskGroups {
            for task in group.tasks where task.taskType == .dailyCheckIn {
                task.isCompleted = false
            }
        }
        defaults?.set(today, forKey: lastDailyCheckInResetDateKey)
        saveModelContext(modelContext, failureMessage: String(localized: "重置每日打卡失败")) { message in
            dataErrorMessage = message
            showDataErrorAlert = true
        }
    }

    // MARK: - 隐私解锁

    private func requestPrivacyUnlockIfNeeded() {
        guard !isPrivacyUnlocked, !isPrivacyUnlocking else { return }
        isPrivacyUnlocking = true
        Task {
            let success = await PrivacyAuthService.shared.requestPrivacyUnlock(reason: String(localized: "请验证以查看隐私事项"))
            await MainActor.run {
                isPrivacyUnlocking = false
                if success {
                    isPrivacyUnlocked = true
                    if pendingPrivateGroupCreation {
                        pendingPrivateGroupCreation = false
                        addNewGroup(taskType: pendingAddTaskType)
                    }
                } else {
                    privacyAlertMessage = String(localized: "验证失败，请稍后重试")
                    showPrivacyAlert = true
                    pendingPrivateGroupCreation = false
                }
            }
        }
    }

    // MARK: - 首次启动教程

    private func presentFirstLaunchTutorialIfNeeded() {
        if !hasSeenFirstLaunchTutorial {
            showFirstLaunchTutorial = true
        }
    }

    // MARK: - 每日激励

    private func ensureDailyMotivationLoaded() {
        guard !isUsingCustomMotivation else { return }
        guard !dailyMotivationEnabled else { return }
        // 如果激励未启用但有自定义内容，保持现状
    }

    private func refreshRandomMotivation() {
        if isUsingCustomMotivation {
            useCustomMotivationQuote = false
        }
        let quotes = motivationQuotes
        guard let line = quotes.randomElement() else { return }
        let (quote, author) = parseMotivationLine(line)
        currentMotivationQuote = quote
        currentMotivationAuthor = author ?? ""
    }

    private var motivationQuotes: [String] {
        (try? String(contentsOfFile: motivationFilePath, encoding: .utf8))?
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty } ?? []
    }

    private var motivationFilePath: String {
        Bundle.main.path(forResource: "Motivation", ofType: "txt") ?? ""
    }

    private func parseMotivationLine(_ line: String) -> (quote: String, author: String?) {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let range = trimmedLine.range(of: "——", options: .backwards) else {
            return (cleanedMotivationQuote(trimmedLine), nil)
        }
        let rawQuote = String(trimmedLine[..<range.lowerBound])
        let rawAuthor = String(trimmedLine[range.upperBound...])
        return (cleanedMotivationQuote(rawQuote), normalizedMotivationAuthor(rawAuthor))
    }

    private func cleanedMotivationQuote(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("\""), text.hasSuffix("\""), text.count >= 2 {
            text.removeFirst()
            text.removeLast()
        }
        return text.trimmingCharacters(in: CharacterSet(charactersIn: "\u{201C}\u{201D}\""))
    }

    private func normalizedMotivationAuthor(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private func beginEditingMotivation() {
        motivationDraftQuote = isUsingCustomMotivation ? customMotivationQuote : currentMotivationQuote
        motivationDraftAuthor = isUsingCustomMotivation ? customMotivationAuthor : currentMotivationAuthor
        showMotivationEditor = true
    }

    private func saveCustomMotivation(quote: String, author: String) {
        customMotivationQuote = quote
        customMotivationAuthor = author
        useCustomMotivationQuote = true
    }

    private func trimmed(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Alert/Sheet 修饰符

private struct BorderlessAlerts: ViewModifier {
    let privacyAlertMessage: String
    @Binding var showPrivacyAlert: Bool
    let dataErrorMessage: String
    @Binding var showDataErrorAlert: Bool
    @Binding var showSubscriptionSheet: Bool
    @Binding var showFirstLaunchTutorial: Bool
    @Binding var hasSeenFirstLaunchTutorial: Bool
    @Binding var showMotivationEditor: Bool
    let motivationDraftQuote: String
    let motivationDraftAuthor: String
    let onTutorialDismiss: () -> Void
    let onSaveMotivation: (String, String) -> Void

    func body(content: Content) -> some View {
        content
            .alert(privacyAlertMessage, isPresented: $showPrivacyAlert) {
                Button(String(localized: "知道了"), role: .cancel) { }
            }
            .alert(String(localized: "保存失败"), isPresented: $showDataErrorAlert) {
                Button(String(localized: "知道了"), role: .cancel) { }
            } message: {
                Text(dataErrorMessage)
            }
            .sheet(isPresented: $showSubscriptionSheet) {
                NavigationStack { SubscriptionView() }
            }
            .sheet(isPresented: $showFirstLaunchTutorial, onDismiss: {
                hasSeenFirstLaunchTutorial = true
            }) {
                FirstLaunchTutorialView {
                    hasSeenFirstLaunchTutorial = true
                    showFirstLaunchTutorial = false
                    onTutorialDismiss()
                }
            }
            .sheet(isPresented: $showMotivationEditor) {
                MotivationEditorView(
                    initialQuote: motivationDraftQuote,
                    initialAuthor: motivationDraftAuthor
                ) { quote, author in
                    onSaveMotivation(quote, author)
                }
            }
    }
}

#Preview {
    BorderlessContentView()
        .modelContainer(for: TaskGroup.self, inMemory: true)
}
