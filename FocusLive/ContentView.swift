//
//  ContentView.swift
//  FocusLive
//
//  Created by 赵豪伟 on 2026/1/13.
//

import SwiftUI
import SwiftData

/// App Group 标识符
private let appGroupID = "group.zhaohaowei.FocusLive"

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query private var taskGroups: [TaskGroup]
    @Environment(\.scenePhase) private var scenePhase
    @State private var showAboutSheet = false
    
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
        NavigationView {
            ZStack {
                // 背景
                backgroundColor
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        if taskGroups.isEmpty {
                            // 空状态提示
                            emptyStateView
                        } else {
                            // 顶部统计卡片
                            statsCard
                            
                            ForEach(sortedGroups) { group in
                                TaskGroupCard(
                                    group: group, 
                                    modelContext: modelContext,
                                    onMoveUp: { moveGroupUp(group) },
                                    onMoveDown: { moveGroupDown(group) },
                                    canMoveUp: sortedGroups.first?.id != group.id,
                                    canMoveDown: sortedGroups.last?.id != group.id
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 100)
                }
            }
            .navigationTitle("FocusLive")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: addNewGroup) {
                            Label("新建分组", systemImage: "folder.badge.plus")
                        }
                        Button(action: addSampleData) {
                            Label("添加示例", systemImage: "sparkles")
                        }
                        Divider()
                        Button(role: .destructive, action: endAllActivities) {
                            Label("结束所有活动", systemImage: "xmark.circle")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.blue)
                    }
                }
            }
            .onAppear {
                // 🔑 核心：App 启动时自动同步 Live Activities
                syncPendingChanges()  // 先同步待处理的变更
                syncActivitiesWithGroups()
            }
            .onChange(of: taskGroups) { oldValue, newValue in
                // 当分组发生变化时，自动同步
                syncActivitiesWithGroups()
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                // 当 App 从后台返回前台时，同步待处理的变更
                if newPhase == .active {
                    syncPendingChanges()
                }
                // 注意：不要在退出后台时结束 Live Activity
                // 灵动岛会自动收缩为紧凑视图，用户可以左滑收起
                // 锁屏实时活动会继续显示，方便用户查看和操作
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
                HStack(spacing: 8) {
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
        let totalTasks = taskGroups.flatMap { $0.tasks }.count
        let completedTasks = taskGroups.flatMap { $0.tasks }.filter { $0.isCompleted }.count
        let progress = totalTasks > 0 ? Double(completedTasks) / Double(totalTasks) : 0
        
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
                    Text("/ \(totalTasks) 项")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 5) {
                Text("\(taskGroups.count)")
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
    
    /// 添加新分组
    private func addNewGroup() {
        let maxOrder = taskGroups.compactMap { $0.sortOrder }.max() ?? -1
        let newGroup = TaskGroup(
            title: "新分组 \(taskGroups.count + 1)",
            iconName: "📁",
            sortOrder: maxOrder + 1,
            tasks: []
        )
        modelContext.insert(newGroup)
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
            title: "工作",
            iconName: "💼",
            sortOrder: 0,
            tasks: [
                TaskItem(title: "完成项目方案", isCompleted: false, sortOrder: 0),
                TaskItem(title: "回复邮件", isCompleted: true, sortOrder: 1),
                TaskItem(title: "团队会议", isCompleted: false, sortOrder: 2),
                TaskItem(title: "代码审查", isCompleted: false, sortOrder: 3),
            ]
        )
        
        // 晚自修分组
        let studyGroup = TaskGroup(
            title: "晚自修",
            iconName: "🌙",
            sortOrder: 1,
            tasks: [
                TaskItem(title: "复习数学", isCompleted: true, sortOrder: 0),
                TaskItem(title: "写英语作业", isCompleted: false, sortOrder: 1),
                TaskItem(title: "物理练习题", isCompleted: false, sortOrder: 2),
            ]
        )
        
        // 生活分组
        let lifeGroup = TaskGroup(
            title: "生活",
            iconName: "❤️",
            sortOrder: 2,
            tasks: [
                TaskItem(title: "买菜", isCompleted: false, sortOrder: 0),
                TaskItem(title: "健身", isCompleted: false, sortOrder: 1),
                TaskItem(title: "阅读30分钟", isCompleted: true, sortOrder: 2),
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
    "💻", "⌨️", "🖨️", "📠", "📞", "☎️", "📧", "✉️",
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
    let modelContext: ModelContext
    var onMoveUp: () -> Void = {}
    var onMoveDown: () -> Void = {}
    var canMoveUp: Bool = true
    var canMoveDown: Bool = true
    
    @State private var isExpanded = true
    @State private var isEditingTitle = false
    @State private var editedTitle = ""
    @State private var showIconPicker = false
    
    /// 排序后的任务列表
    private var sortedTasks: [TaskItem] {
        group.sortedTasks
    }
    
    /// 计算进度（0.0 ~ 1.0）
    private var progress: Double {
        guard group.totalCount > 0 else { return 0 }
        return Double(group.completedCount) / Double(group.totalCount)
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
                    TextField("分组名称", text: $editedTitle)
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
                        
                        Text("\(group.incompleteTasks.count) 项待办")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .onTapGesture {
                        editedTitle = group.title
                        isEditingTitle = true
                    }
                }
                
                Spacer()
                
                // 进度徽章
                HStack(spacing: 4) {
                    if progress == 1 {
                        Text("✅")
                            .font(.system(size: 14))
                    }
                    Text("\(group.completedCount)/\(group.totalCount)")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(progress == 1 ? .green : .blue)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(progress == 1 ? Color.green.opacity(0.15) : Color.blue.opacity(0.15))
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
                
                if group.tasks.isEmpty {
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
                                onMoveUp: { moveTaskUp(task) },
                                onMoveDown: { moveTaskDown(task) },
                                canMoveUp: sortedTasks.first?.id != task.id,
                                canMoveDown: sortedTasks.last?.id != task.id
                            )
                        }
                    }
                }
                
                // 添加任务按钮
                Button(action: { addTask(to: group) }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18))
                        Text("添加任务")
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
        .sheet(isPresented: $showIconPicker) {
            IconPickerView(selectedIcon: $group.iconName) {
                try? modelContext.save()
                updateLiveActivity()
            }
        }
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
    
    private func addTask(to group: TaskGroup) {
        let maxOrder = group.tasks.compactMap { $0.sortOrder }.max() ?? -1
        let newTask = TaskItem(title: "新任务", isCompleted: false, sortOrder: maxOrder + 1)
        group.tasks.append(newTask)
        try? modelContext.save()
        updateLiveActivity()
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
    var onMoveUp: () -> Void = {}
    var onMoveDown: () -> Void = {}
    var canMoveUp: Bool = true
    var canMoveDown: Bool = true
    
    @State private var isEditing = false
    @State private var editedTitle = ""
    @State private var showDatePicker = false
    
    /// 格式化日期
    private var formattedDate: String? {
        guard let date = task.dueDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d HH:mm"
        return formatter.string(from: date)
    }
    
    var body: some View {
        HStack(spacing: 14) {
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
                        .foregroundStyle(task.isCompleted ? .secondary : .primary)
                        .strikethrough(task.isCompleted, color: .secondary)
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
                }
                .onTapGesture {
                    editedTitle = task.title
                    isEditing = true
                }
                
                Spacer()
                
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
                .fill(task.isCompleted ? Color.green.opacity(0.05) : Color.gray.opacity(0.04))
        )
        .contentShape(Rectangle())
        .contextMenu {
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
    }
    
    private func toggleTask() {
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

#Preview {
    ContentView()
        .modelContainer(for: TaskGroup.self, inMemory: true)
}
