//
//  BorderlessContentView.swift
//  FocusLive
//
//  测试版无界首页：无卡片、无边框、大留白的极简设计
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

    @AppStorage("isProUser", store: UserDefaults(suiteName: appGroupID))
    private var isProUser: Bool = false

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

    // MARK: - 无界设计 token

    private var backgroundColor: Color {
        colorScheme == .dark
            ? Color(red: 0.06, green: 0.06, blue: 0.08)
            : Color(red: 0.97, green: 0.97, blue: 0.99)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        // 标题区域
                        borderlessHeader

                        // 筛选栏
                        borderlessFilterBar

                        // 内容
                        if taskGroups.isEmpty {
                            borderlessEmptyState
                        } else if shouldShowPrivacyLock {
                            borderlessPrivacyLock
                        } else {
                            // 统计
                            borderlessStats

                            // 分组列表
                            ForEach(filteredGroupEntries, id: \.0.id) { group, tasks in
                                borderlessGroupSection(group: group, tasks: tasks)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 120)
                }
            }
            .onAppear {
                resetDailyCheckInTasksIfNeeded()
                syncActivitiesWithGroups()
            }
            .onChange(of: taskGroups) { _, _ in
                syncActivitiesWithGroups()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    resetDailyCheckInTasksIfNeeded()
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
            .sheet(isPresented: $showSubscriptionSheet) {
                NavigationStack { SubscriptionView() }
            }
        }
    }

    // MARK: - 无界标题

    private var borderlessHeader: some View {
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey(activeFilter.titleKey))
                    .font(.system(size: 28, weight: .bold))
                Text("\(filteredGroupEntries.count) 个分组")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()

            Menu {
                Button { addNewGroup(taskType: .todo) } label: {
                    Label("传统待办事项", systemImage: "checklist")
                }
                Button { addNewGroup(taskType: .dailyCheckIn) } label: {
                    Label("每日打卡", systemImage: "calendar.badge.clock")
                }
                Button { addNewGroup(taskType: .reminder) } label: {
                    Label("提醒事项", systemImage: "bell.badge.fill")
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.blue))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 无界筛选栏

    private var borderlessFilterBar: some View {
        HStack(spacing: 8) {
            ForEach(TaskFilter.displayCases) { filter in
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
                        .font(.subheadline.weight(activeFilter == filter ? .semibold : .regular))
                        .foregroundStyle(activeFilter == filter ? .blue : .secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            activeFilter == filter
                                ? Capsule().fill(Color.blue.opacity(0.1))
                                : Capsule().fill(Color.clear)
                        )
                }
                .buttonStyle(.plain)
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
                    .stroke(Color.blue.opacity(0.15), lineWidth: 5)
                    .frame(width: 44, height: 44)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(-90))
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.blue)
            }
            Text("\(completed)/\(total) 已完成")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - 无界分组

    private func borderlessGroupSection(group: TaskGroup, tasks: [TaskItem]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // 分组标题
            HStack(spacing: 12) {
                GroupIcon(name: group.iconName, size: 18, tint: .blue)
                Text(group.title)
                    .font(.system(size: 22, weight: .bold))
                Spacer()
                let completed = tasks.filter { $0.isCompleted }.count
                Text("\(completed)/\(tasks.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // 任务列表
            VStack(alignment: .leading, spacing: 12) {
                ForEach(tasks) { task in
                    borderlessTaskRow(task: task, group: group)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func borderlessTaskRow(task: TaskItem, group: TaskGroup) -> some View {
        HStack(spacing: 14) {
            // 完成状态圆点
            Button {
                toggleTask(task)
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(task.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)

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
    }

    // MARK: - 空状态

    private var borderlessEmptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("还没有任务分组")
                .font(.title3.weight(.semibold))
            Text("点击右上角 + 创建你的第一个分组")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    private var borderlessPrivacyLock: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 32))
                .foregroundStyle(.blue)
            Text("隐私空间已锁定")
                .font(.headline)
            Button {
                requestPrivacyUnlockIfNeeded()
            } label: {
                Label("解锁", systemImage: "faceid")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.blue))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(isPrivacyUnlocking)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - 操作

    private func toggleTask(_ task: TaskItem) {
        task.isCompleted.toggle()
        saveModelContext(modelContext, failureMessage: "更新任务状态失败") { _ in }
        WidgetCenter.shared.reloadAllTimelines()
        syncActivitiesWithGroups()
    }

    private func addNewGroup(taskType: TaskType) {
        let defaultIcon: String
        switch taskType {
        case .todo: defaultIcon = "folder.fill"
        case .dailyCheckIn: defaultIcon = "calendar"
        case .reminder: defaultIcon = "bell.badge.fill"
        }

        let group = TaskGroup(
            title: taskType == .todo ? "新待办分组" : (taskType == .dailyCheckIn ? "新打卡分组" : "新提醒分组"),
            iconName: defaultIcon
        )
        modelContext.insert(group)
        saveModelContext(modelContext, failureMessage: "创建分组失败") { _ in }
        syncActivitiesWithGroups()
    }

    private func syncActivitiesWithGroups() {
        Task { @MainActor in
            ActivityManager.shared.scheduleSyncActivities(groups: taskGroups)
        }
    }

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
        saveModelContext(modelContext, failureMessage: "重置每日打卡失败") { _ in }
    }

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
}

#Preview {
    BorderlessContentView()
        .modelContainer(for: TaskGroup.self, inMemory: true)
}
