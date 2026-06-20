//
//  TaskGroupCard.swift
//  FocusLive
//

import SwiftUI
import SwiftData

struct TaskGroupCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var group: TaskGroup
    let displayTasks: [TaskItem]
    let modelContext: ModelContext
    let allowsTaskReorder: Bool
    let isProUser: Bool
    let onRequireSubscription: () -> Void
    var onMoveUp: () -> Void = {}
    var onMoveDown: () -> Void = {}
    var canMoveUp: Bool = true
    var canMoveDown: Bool = true

    @Query private var allGroups: [TaskGroup]
    
    @State private var isExpanded = true
    @State private var isEditingTitle = false
    @State private var editedTitle = ""
    @State private var showIconPicker = false
    @State private var showAdvancedGroupEditor = false
    @State private var persistenceErrorMessage = ""
    @State private var showPersistenceErrorAlert = false
    
    private var sortedTasks: [TaskItem] { displayTasks }

    private var todoTasks: [TaskItem] {
        displayTasks.filter { $0.taskType != .reminder }
    }

    private var reminderCount: Int {
        displayTasks.filter { $0.taskType == .reminder }.count
    }
    
    private var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }
    
    private var completedCount: Int {
        todoTasks.filter { $0.isCompleted }.count
    }
    
    private var totalCount: Int { todoTasks.count }
    
    private var incompleteCount: Int {
        todoTasks.filter { !$0.isCompleted }.count
    }
    
    private var cardBackground: Color {
        colorScheme == .dark
            ? Color(red: 0.15, green: 0.15, blue: 0.18)
            : Color.white
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // header: icon + title + progress
            HStack(spacing: 12) {
                Button(action: { showIconPicker = true }) {
                    GroupIcon(name: group.iconName, size: 22)
                }
                .buttonStyle(.plain)
                
                if isEditingTitle {
                    TextField(String(localized: "分组名称"), text: $editedTitle)
                        .font(.system(size: 18, weight: .semibold))
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { saveGroupTitle() }
                        .onAppear { editedTitle = group.title }
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
                
                HStack(spacing: 4) {
                    if totalCount > 0 && progress == 1 {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.green)
                    }
                    if totalCount > 0 {
                        Text("\(completedCount)/\(totalCount)")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(progress == 1 ? .green : .blue)
                    } else {
                        HStack(spacing: 2) {
                            Image(systemName: "bell.fill")
                                .font(.system(size: 12))
                            Text("\(reminderCount)")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                        }
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
                
                if isEditingTitle {
                    Button(action: saveGroupTitle) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.green)
                    }
                    .buttonStyle(.plain)
                } else {
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
            
            // progress bar
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
                
                Button(action: { addTask(to: group) }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18))
                        Text(defaultTaskTypeForAdd == .reminder ? "添加提醒" : (defaultTaskTypeForAdd == .dailyCheckIn ? "添加打卡" : "添加任务"))
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
        .alert("保存失败", isPresented: $showPersistenceErrorAlert) {
            Button("知道了", role: .cancel) { }
        } message: {
            Text(persistenceErrorMessage)
        }
        .sheet(isPresented: $showIconPicker) {
            IconPickerView(selectedIcon: $group.iconName) {
                if saveChanges(failureMessage: String(localized: "保存分组图标失败")) {
                    updateLiveActivity()
                }
            }
        }
        .sheet(isPresented: $showAdvancedGroupEditor) {
            AdvancedGroupEditor(group: group, modelContext: modelContext, onUpdate: updateLiveActivity)
        }
    }
    
    private func saveGroupTitle() {
        if !editedTitle.trimmingCharacters(in: .whitespaces).isEmpty {
            group.title = editedTitle
            if saveChanges(failureMessage: String(localized: "保存分组名称失败")) {
                updateLiveActivity()
            }
        }
        isEditingTitle = false
    }
    
    private func deleteGroup() {
        Task { @MainActor in
            ActivityManager.shared.endActivity(groupID: group.id.uuidString)
        }
        modelContext.delete(group)
        saveChanges(failureMessage: String(localized: "删除分组失败"))
    }
    
    private func updateLiveActivity() {
        Task { @MainActor in
            ActivityManager.shared.scheduleSyncActivities(groups: allGroups)
        }
    }
    
    private func addTask(to group: TaskGroup) {
        let maxOrder = group.tasks.compactMap { $0.sortOrder }.max() ?? -1
        let taskType = defaultTaskTypeForAdd
        let newTask = TaskItem(
            title: String(localized: taskType == .reminder ? "新提醒" : (taskType == .dailyCheckIn ? "新打卡" : "新任务")),
            isCompleted: false,
            isPrivate: group.isPrivate ?? false,
            taskType: taskType,
            sortOrder: maxOrder + 1
        )
        group.tasks.append(newTask)
        if saveChanges(failureMessage: String(localized: "添加任务失败")) {
            updateLiveActivity()
        }
    }

    private var defaultTaskTypeForAdd: TaskType {
        if group.tasks.contains(where: { $0.taskType == .reminder }) && !group.tasks.contains(where: { $0.taskType != .reminder }) {
            return .reminder
        }
        if group.tasks.contains(where: { $0.taskType == .dailyCheckIn }) && !group.tasks.contains(where: { $0.taskType != .dailyCheckIn }) {
            return .dailyCheckIn
        }
        return .todo
    }
    
    private func moveTaskUp(_ task: TaskItem) {
        guard let index = sortedTasks.firstIndex(where: { $0.id == task.id }), index > 0 else { return }
        let prevTask = sortedTasks[index - 1]
        let tempOrder = task.sortOrder ?? 0
        task.sortOrder = prevTask.sortOrder ?? 0
        prevTask.sortOrder = tempOrder
        if saveChanges(failureMessage: String(localized: "调整任务顺序失败")) {
            updateLiveActivity()
        }
    }
    
    private func moveTaskDown(_ task: TaskItem) {
        guard let index = sortedTasks.firstIndex(where: { $0.id == task.id }), index < sortedTasks.count - 1 else { return }
        let nextTask = sortedTasks[index + 1]
        let tempOrder = task.sortOrder ?? 0
        task.sortOrder = nextTask.sortOrder ?? 0
        nextTask.sortOrder = tempOrder
        if saveChanges(failureMessage: String(localized: "调整任务顺序失败")) {
            updateLiveActivity()
        }
    }

    @discardableResult
    private func saveChanges(failureMessage: String) -> Bool {
        saveModelContext(modelContext, failureMessage: failureMessage) { message in
            persistenceErrorMessage = message
            showPersistenceErrorAlert = true
        }
    }
}
