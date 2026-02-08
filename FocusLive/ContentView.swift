//
//  ContentView.swift
//  FocusLive
//
//  Created by 赵豪伟 on 2026/1/13.
//

import SwiftUI
import Foundation
import SwiftData

/// App Group 标识符
private let appGroupID = "group.com.QingTeng.FocusLive"

/// 任务筛选类型
enum TaskFilter: String, CaseIterable, Identifiable {
    case incomplete
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
        [.incomplete, .all, .privateSpace, .completed]
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query private var taskGroups: [TaskGroup]
    @Environment(\.scenePhase) private var scenePhase
    @State private var showAboutSheet = false
    @State private var activeFilter: TaskFilter = .incomplete
    @State private var isPrivacyUnlocked = false
    @State private var isPrivacyUnlocking = false
    @State private var showPrivacyAlert = false
    @State private var privacyAlertMessage = ""
    @State private var pendingPrivateGroupCreation = false
    @State private var showSubscriptionSheet = false
    @State private var lastNonPrivateFilter: TaskFilter = .incomplete
    @State private var showAddTypeDialog = false
    @State private var pendingAddTaskType: TaskType = .todo
    
    @AppStorage("isProUser", store: UserDefaults(suiteName: appGroupID))
    private var isProUser: Bool = false
    
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
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 120)
                }
            }
            .onAppear {
                // 🔑 核心：App 启动时自动同步 Live Activities
                syncPendingChanges()  // 先同步待处理的变更
                syncActivitiesWithGroups()
            }
            .onChange(of: taskGroups) { _, _ in
                // 当分组发生变化时，自动同步
                syncActivitiesWithGroups()
            }
            .onChange(of: scenePhase) { _, newPhase in
                // 当 App 从后台返回前台时，同步待处理的变更
                if newPhase == .active {
                    syncPendingChanges()
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
                NavigationStack {
                    SubscriptionView()
                }
            }
            .confirmationDialog("添加组件", isPresented: $showAddTypeDialog, titleVisibility: .visible) {
                Button("传统待办事项") {
                    addNewGroup(taskType: .todo)
                }
                Button("提醒事项") {
                    addNewGroup(taskType: .reminder)
                }
                Button("取消", role: .cancel) { }
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
            
            Button(action: { showAddTypeDialog = true }) {
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
            
            Button(action: addSampleData) {
                HStack(spacing: 24) {
                    Image(systemName: "sparkles")
                    Text("添加示例数据")
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
        let visibleTodoTasks = visibleTasks.filter { !isReminderTask($0) }
        let totalTasks = visibleTodoTasks.count
        let completedTasks = visibleTodoTasks.filter { $0.isCompleted }.count
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
    
    /// 同步 Live Activities
    private func syncActivitiesWithGroups() {
        Task { @MainActor in
            ActivityManager.shared.syncActivities(groups: taskGroups)
        }
    }
    
    /// 从 App Groups 同步待处理的变更（锁屏上的操作）
    private func syncPendingChanges() {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        guard let pendingChanges = defaults.array(forKey: "pendingTaskChanges") as? [[String: Any]] else { return }
        
        guard !pendingChanges.isEmpty else { return }
        
        print("📥 发现 \(pendingChanges.count) 个待同步的变更")
        
        for change in pendingChanges {
            guard let groupIDStr = change["groupID"] as? String,
                  let taskIDStr = change["taskID"] as? String,
                  let isCompleted = change["isCompleted"] as? Bool else {
                continue
            }
            
            // 查找对应的分组和任务
            if let group = taskGroups.first(where: { $0.id.uuidString == groupIDStr }),
               let task = group.tasks.first(where: { $0.id.uuidString == taskIDStr }) {
                if task.taskType == .reminder {
                    continue
                }
                // 更新任务状态
                if task.isCompleted != isCompleted {
                    task.isCompleted = isCompleted
                    print("   ✅ 同步任务 '\(task.title)' 状态为: \(isCompleted)")
                }
            }
        }
        
        // 清空待处理变更
        defaults.removeObject(forKey: "pendingTaskChanges")
        
        // 保存更改
        try? modelContext.save()
        print("📥 待处理变更已全部同步")
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
        try? modelContext.save()
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
        try? modelContext.save()
    }
    
    /// 上移分组
    private func moveGroupUp(_ group: TaskGroup) {
        let sorted = sortedGroups
        guard let index = sorted.firstIndex(where: { $0.id == group.id }), index > 0 else { return }
        let prevGroup = sorted[index - 1]
        let tempOrder = group.sortOrder ?? 0
        group.sortOrder = prevGroup.sortOrder ?? 0
        prevGroup.sortOrder = tempOrder
        try? modelContext.save()
    }
    
    /// 下移分组
    private func moveGroupDown(_ group: TaskGroup) {
        let sorted = sortedGroups
        guard let index = sorted.firstIndex(where: { $0.id == group.id }), index < sorted.count - 1 else { return }
        let nextGroup = sorted[index + 1]
        let tempOrder = group.sortOrder ?? 0
        group.sortOrder = nextGroup.sortOrder ?? 0
        nextGroup.sortOrder = tempOrder
        try? modelContext.save()
    }
    
    /// 结束所有 Live Activities
    private func endAllActivities() {
        ActivityManager.shared.endAllActivities()
    }
    
    /// 添加示例数据
    private func addSampleData() {
        // 工作分组
        let workGroup = TaskGroup(
            title: String(localized: "工作"),
            iconName: "💼",
            sortOrder: 0,
            tasks: [
                TaskItem(title: String(localized: "完成项目方案"), isCompleted: false, sortOrder: 0),
                TaskItem(title: String(localized: "回复邮件"), isCompleted: true, sortOrder: 1),
                TaskItem(title: String(localized: "团队会议"), isCompleted: false, sortOrder: 2),
                TaskItem(title: String(localized: "代码审查"), isCompleted: false, sortOrder: 3),
            ]
        )
        
        // 晚自修分组
        let studyGroup = TaskGroup(
            title: String(localized: "晚自修"),
            iconName: "🌙",
            sortOrder: 1,
            tasks: [
                TaskItem(title: String(localized: "复习数学"), isCompleted: true, sortOrder: 0),
                TaskItem(title: String(localized: "写英语作业"), isCompleted: false, sortOrder: 1),
                TaskItem(title: String(localized: "物理练习题"), isCompleted: false, sortOrder: 2),
            ]
        )
        
        // 生活分组
        let lifeGroup = TaskGroup(
            title: String(localized: "生活"),
            iconName: "❤️",
            sortOrder: 2,
            tasks: [
                TaskItem(title: String(localized: "买菜"), isCompleted: false, sortOrder: 0),
                TaskItem(title: String(localized: "健身"), isCompleted: false, sortOrder: 1),
                TaskItem(title: String(localized: "阅读30分钟"), isCompleted: true, sortOrder: 2),
            ]
        )
        
        modelContext.insert(workGroup)
        modelContext.insert(studyGroup)
        modelContext.insert(lifeGroup)
        
        try? modelContext.save()
    }
}

// MARK: - 常用Emoji列表（适合提醒事项）
let commonEmojis = [
    // 工作/办公
    "💼", "🗂️", "📁", "📋", "📊", "📈", "💹", "🖥️",
    "💻", "⌨️", "🖨️", "Fax", "📞", "☎️", "📧", "✉️",
    "📝", "✍️", "🖊️", "📌", "📍", "🗓️", "📅", "📆",
    // 学习/教育
    "📚", "📖", "📕", "📗", "📘", "📙", "📓", "📔",
    "✏️", "🎓", "🏫", "🧮", "🔬", "🔭", "🧪", "🧠",
    // 时间/日程
    "⏰", "⏱️", "⌚️", "🕐", "🕑", "🕒", "⏳", "⌛️",
    // 重要/优先
    "⭐️", "🌟", "💡", "🔥", "❗️", "‼️", "❓", "💎",
    "🎯", "🏆", "🥇", "✅", "☑️", "✔️", "🔔", "🔊",
    // 生活/家庭
    "🏠", "🏡", "🛋️", "🛏️", "🚿", "🧹", "🧺", "🧼",
    "👨‍👩‍👧", "👶", "🐶", "🐱", "🌱", "🪴", "🌸", "🌺",
    // 健康/运动
    "🏃", "🚴", "🏋️", "🧘", "🏊", "⚽️", "🏀", "🎾",
    "💪", "🩺", "💊", "🏥", "❤️", "🧘‍♀️", "🥗", "🍎",
    // 购物/财务
    "🛒", "🛍️", "💳", "💰", "💵", "🏦", "🧾", "📦",
    // 出行/交通
    "🚗", "🚕", "🚌", "🚇", "✈️", "🚀", "🛫", "🧳",
    "🗺️", "🧭", "⛽️", "🅿️", "🚦", "🛣️", "🏨", "🎫",
    // 社交/沟通
    "💬", "🗣️", "👥", "🤝", "📱", "📲", "💌", "🎂",
    "🎉", "🎁", "🎊", "🥳", "👋", "🙏", "❤️‍🔥", "💕",
    // 娱乐/休闲
    "🎮", "🎬", "🎵", "🎸", "🎨", "📷", "📺", "🎭",
    "☕️", "🍽️", "🍿", "🎤", "🎧", "📻", "🎲", "🃏",
    // 天气/自然
    "☀️", "🌙", "⭐️", "🌈", "☁️", "🌧️", "❄️", "🌊"
]

// MARK: - 任务分组卡片
struct TaskGroupCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var group: TaskGroup
    let displayTasks: [TaskItem]
    let modelContext: ModelContext
    let allowsTaskReorder: Bool
    let isProUser: Bool
    let onRequireSubscription: () -> Void
    var onMoveUp: () -> Void = {}    // 修复：语法正确应该是闭包类型，如 {} 或 { _: TaskGroup in }
    var onMoveDown: () -> Void = {}
    var canMoveUp: Bool = true
    var canMoveDown: Bool = true
    
    @State private var isExpanded = true
    @State private var isEditingTitle = false
    @State private var editedTitle = ""
    @State private var showIconPicker = false
    @State private var showAdvancedGroupEditor = false
    
    /// 排序后的任务列表
    private var sortedTasks: [TaskItem] {
        displayTasks
    }

    /// 普通待办列表（用于进度统计）
    private var todoTasks: [TaskItem] {
        displayTasks.filter { $0.taskType != .reminder }
    }

    /// 提醒事项数量（用于展示）
    private var reminderCount: Int {
        displayTasks.filter { $0.taskType == .reminder }.count
    }
    
    /// 计算进度（0.0 ~ 1.0）
    private var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }
    
    /// 已完成任务数量（当前展示）
    private var completedCount: Int {
        todoTasks.filter { $0.isCompleted }.count
    }
    
    /// 总任务数量（当前展示）
    private var totalCount: Int {
        todoTasks.count
    }
    
    /// 未完成任务数量（当前展示）
    private var incompleteCount: Int {
        todoTasks.filter { !$0.isCompleted }.count
    }
    
    /// 卡片背景色
    private var cardBackground: Color {
        colorScheme == .dark
            ? Color(red: 0.15, green: 0.15, blue: 0.18)
            : Color.white
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 头部：图标 + 标题 + 进度
            HStack(spacing: 12) {
                // Emoji图标（可点击编辑）
                Button(action: { showIconPicker = true }) {
                    Text(group.iconName)
                        .font(.system(size: 32))
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(Color.blue.opacity(colorScheme == .dark ? 0.2 : 0.1))
                        )
                }
                .buttonStyle(.plain)
                
                // 标题（可编辑）
                if isEditingTitle {
                    TextField(String(localized: "分组名称"), text: $editedTitle)
                        .font(.system(size: 18, weight: .semibold))
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            saveGroupTitle()
                        }
                        .onAppear {
                            editedTitle = group.title
                        }
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.title)
                            .font(.system(size: 18, weight: .semibold))
                            .lineLimit(1)
                        
                        if totalCount > 0 {
                            Text(String(format: String(localized: "%lld 项待办"), Int64(incompleteCount)))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text(String(format: String(localized: "提醒 %lld"), Int64(reminderCount)))
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                    .onTapGesture {
                        editedTitle = group.title
                        isEditingTitle = true
                    }
                }
                
                Spacer()
                
                // 进度徽章
                HStack(spacing: 4) {
                    if totalCount > 0 && progress == 1 {
                        Text("✅")
                            .font(.system(size: 14))
                    }
                    if totalCount > 0 {
                        Text("\(completedCount)/\(totalCount)")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(progress == 1 ? .green : .blue)
                    } else {
                        Text("🔔\(reminderCount)")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.orange)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(
                            totalCount > 0
                                ? (progress == 1 ? Color.green.opacity(0.15) : Color.blue.opacity(0.15))
                                : Color.orange.opacity(0.15)
                        )
                )
                
                // 编辑完成按钮
                if isEditingTitle {
                    Button(action: saveGroupTitle) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.green)
                    }
                    .buttonStyle(.plain)
                } else {
                    // 展开/收起按钮
                    Button(action: { withAnimation(.spring(duration: 0.3)) { isExpanded.toggle() } }) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(isExpanded ? 0 : -90))
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Color.gray.opacity(0.15)))
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // 进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: progress == 1 ? [.green, .mint] : [.blue, .cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progress, height: 6)
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
            }
            .frame(height: 6)
            
            // 任务列表（可折叠）
            if isExpanded {
                Divider()
                    .padding(.vertical, 6)
                
                if displayTasks.isEmpty {
                    Text("暂无任务，点击下方添加")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
                } else {
                    VStack(spacing: 10) {
                        ForEach(sortedTasks) { task in
                            TaskRow(
                                task: task,
                                group: group,
                                modelContext: modelContext,
                                onUpdate: { updateLiveActivity() },
                                isProUser: isProUser,
                                onRequireSubscription: onRequireSubscription,
                                onMoveUp: { moveTaskUp(task) },
                                onMoveDown: { moveTaskDown(task) },
                                canMoveUp: allowsTaskReorder && sortedTasks.first?.id != task.id,
                                canMoveDown: allowsTaskReorder && sortedTasks.last?.id != task.id
                            )
                        }
                    }
                }
                
                // 添加任务按钮
                Button(action: { addTask(to: group) }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18))
                        Text(defaultTaskTypeForAdd == .reminder ? "添加提醒" : "添加任务")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.blue)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.blue.opacity(0.1))
                    )
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(cardBackground)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.06), radius: 12, x: 0, y: 4)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: deleteGroup) {
                Label("删除", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button(action: { showAdvancedGroupEditor = true }) {
                Label("高级设置", systemImage: "gear")
            }
            .tint(.blue)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .contextMenu {
            Button(action: { showIconPicker = true }) {
                Label("更换图标", systemImage: "face.smiling")
            }
            
            Button(action: {
                editedTitle = group.title
                isEditingTitle = true
            }) {
                Label("编辑名称", systemImage: "pencil")
            }
            
            Button(action: { showAdvancedGroupEditor = true }) {
                Label("高级设置", systemImage: "gear")
            }
            
            if canMoveUp {
                Button(action: onMoveUp) {
                    Label("上移", systemImage: "arrow.up")
                }
            }
            
            if canMoveDown {
                Button(action: onMoveDown) {
                    Label("下移", systemImage: "arrow.down")
                }
            }
            
            Button(role: .destructive, action: deleteGroup) {
                Label("删除分组", systemImage: "trash")
            }
        }
    }
    
    private func saveGroupTitle() {
        if !editedTitle.trimmingCharacters(in: .whitespaces).isEmpty {
            group.title = editedTitle
            try? modelContext.save()
            updateLiveActivity()
        }
        isEditingTitle = false
    }
    
    private func deleteGroup() {
        // 先结束对应的 Live Activity
        Task { @MainActor in
            ActivityManager.shared.endActivity(groupID: group.id.uuidString)
        }
        
        // 删除分组
        modelContext.delete(group)
        try? modelContext.save()
    }
    
    private func updateLiveActivity() {
        Task { @MainActor in
            ActivityManager.shared.updateActivity(
                groupID: group.id.uuidString,
                group: group
            )
        }
    }
    
    /// 添加任务到指定分组
    /// - Parameter group: 任务分组
    /// - Returns: Void
    private func addTask(to group: TaskGroup) {
        let maxOrder = group.tasks.compactMap { $0.sortOrder }.max() ?? -1
        let taskType = defaultTaskTypeForAdd
        let newTask = TaskItem(
            title: String(localized: taskType == .reminder ? "新提醒" : "新任务"),
            isCompleted: false,
            isPrivate: group.isPrivate ?? false,
            taskType: taskType,
            sortOrder: maxOrder + 1
        )
        group.tasks.append(newTask)
        try? modelContext.save()
        updateLiveActivity()
    }

    private var defaultTaskTypeForAdd: TaskType {
        if group.tasks.contains(where: { $0.taskType == .reminder }) && !group.tasks.contains(where: { $0.taskType != .reminder }) {
            return .reminder
        }
        return .todo
    }
    
    private func moveTaskUp(_ task: TaskItem) {
        guard let index = sortedTasks.firstIndex(where: { $0.id == task.id }), index > 0 else { return }
        let prevTask = sortedTasks[index - 1]
        let tempOrder = task.sortOrder ?? 0
        task.sortOrder = prevTask.sortOrder ?? 0
        prevTask.sortOrder = tempOrder
        try? modelContext.save()
        updateLiveActivity()
    }
    
    private func moveTaskDown(_ task: TaskItem) {
        guard let index = sortedTasks.firstIndex(where: { $0.id == task.id }), index < sortedTasks.count - 1 else { return }
        let nextTask = sortedTasks[index + 1]
        let tempOrder = task.sortOrder ?? 0
        task.sortOrder = nextTask.sortOrder ?? 0
        nextTask.sortOrder = tempOrder
        try? modelContext.save()
        updateLiveActivity()
    }
}

// MARK: - Emoji选择器
struct IconPickerView: View {
    @Binding var selectedIcon: String
    var onDismiss: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    let columns = [
        GridItem(.adaptive(minimum: 52))
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(commonEmojis, id: \.self) { emoji in
                        Button(action: {
                            selectedIcon = emoji
                            onDismiss()
                            dismiss()
                        }) {
                            Text(emoji)
                                .font(.system(size: 30))
                                .frame(width: 52, height: 52)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(selectedIcon == emoji ? Color.blue.opacity(0.2) : Color.gray.opacity(0.08))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(selectedIcon == emoji ? Color.blue : Color.clear, lineWidth: 2)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("选择图标")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - 任务行
struct TaskRow: View {
    @Bindable var task: TaskItem
    var group: TaskGroup
    let modelContext: ModelContext
    let onUpdate: () -> Void
    let isProUser: Bool
    let onRequireSubscription: () -> Void
    var onMoveUp: () -> Void = {}
    var onMoveDown: () -> Void = {}
    var canMoveUp: Bool = false
    var canMoveDown: Bool = false
    
    @State private var isEditing = false
    @State private var editedTitle = ""
    @State private var showDatePicker = false
    @State private var showAdvancedEditor = false
    
    /// 格式化日期
    private var formattedDate: String? {
        guard let date = task.dueDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d HH:mm"
        return formatter.string(from: date)
    }
    
    /// 格式化计划时间
    private var formattedScheduledTime: String? {
        guard let date = task.scheduledTime else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d HH:mm"
        return formatter.string(from: date)
    }
    
    var body: some View {
        HStack(spacing: 14) {
            if task.taskType == .reminder {
                Image(systemName: "bell.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.orange)
                    .frame(width: 26, height: 26)
            } else {
                // 完成按钮
                Button(action: toggleTask) {
                    ZStack {
                        Circle()
                            .stroke(
                                task.isCompleted ? Color.green : Color.gray.opacity(0.3),
                                lineWidth: 2.5
                            )
                            .frame(width: 26, height: 26)
                        
                        if task.isCompleted {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.green, .green.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 26, height: 26)
                            
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            
            // 任务标题（可编辑）
            if isEditing {
                TextField("任务名称", text: $editedTitle)
                    .font(.body)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        saveTaskTitle()
                    }
                    .onAppear {
                        editedTitle = task.title
                    }
                
                Button(action: saveTaskTitle) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.green)
                }
                .buttonStyle(.plain)
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    Text(task.title)
                        .font(.system(size: 16))
                        .foregroundStyle((task.isCompleted && task.taskType != .reminder) ? .secondary : .primary)
                        .strikethrough(task.isCompleted && task.taskType != .reminder, color: .secondary)
                        .lineLimit(2)
                    
                    // 显示截止日期
                    if let dateStr = formattedDate {
                        HStack(spacing: 4) {
                            Text("⏰")
                                .font(.system(size: 11))
                            Text(dateStr)
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                    
                    // 显示计划时间
                    if let scheduledTimeStr = formattedScheduledTime {
                        HStack(spacing: 4) {
                            Text("📅")
                                .font(.system(size: 11))
                            Text(scheduledTimeStr)
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                }
                .onTapGesture {
                    editedTitle = task.title
                    isEditing = true
                }
                
                Spacer()
                
                if task.isPrivate ?? false {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.blue)
                        .padding(.trailing, 4)
                }
                
                // 删除按钮
                Button(action: deleteTask) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.gray.opacity(0.5))
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(Color.gray.opacity(0.1)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    task.taskType == .reminder
                        ? Color.orange.opacity(0.08)
                        : (task.isCompleted ? Color.green.opacity(0.05) : Color.gray.opacity(0.04))
                )
        )
        .contentShape(Rectangle())
        .contextMenu {
            Button(action: togglePrivacy) {
                Label((task.isPrivate ?? false) ? "取消隐私" : "设为隐私", systemImage: "lock")
            }
            
            Button(action: {
                editedTitle = task.title
                isEditing = true
            }) {
                Label("编辑", systemImage: "pencil")
            }
            
            Button(action: { showDatePicker = true }) {
                Label(task.dueDate == nil ? "设置时间" : "修改时间", systemImage: "calendar")
            }
            
            if task.dueDate != nil {
                Button(action: {
                    task.dueDate = nil
                    try? modelContext.save()
                    onUpdate()
                }) {
                    Label("清除时间", systemImage: "calendar.badge.minus")
                }
            }
            
            Divider()
            
            if canMoveUp {
                Button(action: onMoveUp) {
                    Label("上移", systemImage: "arrow.up")
                }
            }
            
            if canMoveDown {
                Button(action: onMoveDown) {
                    Label("下移", systemImage: "arrow.down")
                }
            }
            
            Divider()
            
            Button(role: .destructive, action: deleteTask) {
                Label("删除", systemImage: "trash")
            }
        }
        .sheet(isPresented: $showDatePicker) {
            DatePickerSheet(date: Binding(
                get: { task.dueDate ?? Date() },
                set: { task.dueDate = $0 }
            )) {
                try? modelContext.save()
                onUpdate()
            }
        }
        .sheet(isPresented: $showAdvancedEditor) {
            AdvancedTaskEditor(task: task, modelContext: modelContext, onUpdate: onUpdate)
        }
    }
    
    private func toggleTask() {
        guard task.taskType != .reminder else { return }
        withAnimation(.spring(duration: 0.2)) {
            task.isCompleted.toggle()
        }
        try? modelContext.save()
        onUpdate()
    }
    
    private func saveTaskTitle() {
        if !editedTitle.trimmingCharacters(in: .whitespaces).isEmpty {
            task.title = editedTitle
            try? modelContext.save()
            onUpdate()
        }
        isEditing = false
    }
    
    private func deleteTask() {
        withAnimation {
            if let group = task.taskGroup {
                group.tasks.removeAll { $0.id == task.id }
            }
            modelContext.delete(task)
            try? modelContext.save()
            onUpdate()
        }
    }
    
    /// 切换任务隐私状态
    /// - Returns: Void
    private func togglePrivacy() {
        guard isProUser else {
            onRequireSubscription()
            return
        }
        task.isPrivate = !(task.isPrivate ?? false)
        try? modelContext.save()
        onUpdate()
    }
}

// MARK: - 日期选择器
struct DatePickerSheet: View {
    @Binding var date: Date
    var onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                DatePicker(
                    "选择日期时间",
                    selection: $date,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.graphical)
                .padding()
                
                Spacer()
            }
            .navigationTitle("设置时间")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        onSave()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - 高级任务编辑器
struct AdvancedTaskEditor: View {
    @Bindable var task: TaskItem
    let modelContext: ModelContext
    let onUpdate: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedScheduledTime: Date = Date()
    @State private var selectedReminderType: ReminderType = .none
    @State private var selectedPriority: Priority = .medium
    @State private var selectedRepeatType: RepeatType = .none
    @State private var repeatInterval: Int = 1
    @State private var attachments: [Attachment] = []
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("计划时间")) {
                    Toggle("设置计划时间", isOn: Binding(
                        get: { task.scheduledTime != nil },
                        set: { if $0 { task.scheduledTime = selectedScheduledTime } else { task.scheduledTime = nil } }
                    ))
                    
                    if task.scheduledTime != nil {
                        DatePicker("计划时间", selection: Binding(
                            get: { task.scheduledTime ?? Date() },
                            set: { task.scheduledTime = $0; selectedScheduledTime = $0 }
                        ), displayedComponents: [.date, .hourAndMinute])
                    }
                }
                
                Section(header: Text("重复")) {
                    Picker("重复类型", selection: $selectedRepeatType) {
                        Text("不重复").tag(RepeatType.none)
                        Text("每天").tag(RepeatType.daily)
                        Text("每周").tag(RepeatType.weekly)
                        Text("每月").tag(RepeatType.monthly)
                        Text("每年").tag(RepeatType.yearly)
                    }
                    
                    if selectedRepeatType != .none {
                        Stepper("间隔: \(repeatInterval)", value: $repeatInterval, in: 1...30)
                    }
                }
                
                Section(header: Text("提醒")) {
                    Picker("提醒类型", selection: $selectedReminderType) {
                        Text("无提醒").tag(ReminderType.none)
                        Text("准时提醒").tag(ReminderType.atTime)
                        Text("提前10分钟").tag(ReminderType.before10min)
                        Text("提前30分钟").tag(ReminderType.before30min)
                        Text("提前1小时").tag(ReminderType.before1hour)
                        Text("提前6小时").tag(ReminderType.before6hours)
                        Text("提前1天").tag(ReminderType.before1day)
                        Text("提前1周").tag(ReminderType.before1week)
                    }
                }
                
                Section(header: Text("优先级")) {
                    Picker("优先级", selection: $selectedPriority) {
                        Text("低").tag(Priority.low)
                        Text("中").tag(Priority.medium)
                        Text("高").tag(Priority.high)
                        Text("紧急").tag(Priority.urgent)
                    }
                }
                
                Section(header: Text("附件")) {
                    ForEach(attachments.indices, id: \.self) { index in
                        HStack {
                            Text(attachments[index].title)
                            Spacer()
                            Button(action: { attachments.remove(at: index) }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                    
                    Button(action: addAttachment) {
                        Label("添加附件", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("高级设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveChanges()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                selectedScheduledTime = task.scheduledTime ?? Date()
                selectedReminderType = task.reminderType ?? .none
                selectedPriority = task.priority ?? .medium
                selectedRepeatType = task.repeatType ?? .none
                repeatInterval = task.repeatInterval ?? 1
                attachments = task.attachments ?? []
            }
        }
    }
    
    private func saveChanges() {
        task.repeatType = selectedRepeatType == .none ? nil : selectedRepeatType
        task.repeatInterval = selectedRepeatType == .none ? nil : repeatInterval
        task.reminderType = selectedReminderType == .none ? nil : selectedReminderType
        task.priority = selectedPriority
        
        try? modelContext.save()
        onUpdate()
    }
    
    private func addAttachment() {
        // 这里可以实现添加附件的逻辑
        // 暂时添加一个示例附件
        let newAttachment = Attachment(
            id: UUID(),
            type: .link,
            url: "https://example.com",
            title: "示例链接"
        )
        attachments.append(newAttachment)
    }
}

// MARK: - 高级分组编辑器
struct AdvancedGroupEditor: View {
    @Bindable var group: TaskGroup
    let modelContext: ModelContext
    let onUpdate: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedScheduledTime: Date = Date()
    @State private var selectedReminderType: ReminderType = .none
    @State private var selectedPriority: Priority = .medium
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("计划时间")) {
                    Toggle("设置计划时间", isOn: Binding(
                        get: { group.scheduledTime != nil },
                        set: { if $0 { group.scheduledTime = selectedScheduledTime } else { group.scheduledTime = nil } }
                    ))
                    
                    if group.scheduledTime != nil {
                        DatePicker("计划时间", selection: Binding(
                            get: { group.scheduledTime ?? Date() },
                            set: { group.scheduledTime = $0; selectedScheduledTime = $0 }
                        ), displayedComponents: [.date, .hourAndMinute])
                    }
                }
                
                Section(header: Text("提醒")) {
                    Picker("提醒类型", selection: $selectedReminderType) {
                        Text("无提醒").tag(ReminderType.none)
                        Text("准时提醒").tag(ReminderType.atTime)
                        Text("提前10分钟").tag(ReminderType.before10min)
                        Text("提前30分钟").tag(ReminderType.before30min)
                        Text("提前1小时").tag(ReminderType.before1hour)
                        Text("提前6小时").tag(ReminderType.before6hours)
                        Text("提前1天").tag(ReminderType.before1day)
                        Text("提前1周").tag(ReminderType.before1week)
                    }
                }
                
                Section(header: Text("优先级")) {
                    Picker("优先级", selection: $selectedPriority) {
                        Text("低").tag(Priority.low)
                        Text("中").tag(Priority.medium)
                        Text("高").tag(Priority.high)
                        Text("紧急").tag(Priority.urgent)
                    }
                }
            }
            .navigationTitle("分组高级设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveChanges()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                selectedScheduledTime = group.scheduledTime ?? Date()
                selectedReminderType = group.reminderType ?? .none
                selectedPriority = group.priority ?? .medium
            }
        }
    }
    
    private func saveChanges() {
        group.reminderType = selectedReminderType == .none ? nil : selectedReminderType
        group.priority = selectedPriority
        
        try? modelContext.save()
        onUpdate()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: TaskGroup.self, inMemory: true)
}
