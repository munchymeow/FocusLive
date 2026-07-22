//
//  TaskRow.swift
//  FocusLive
//

import SwiftUI
import SwiftData

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
    @State private var persistenceErrorMessage = ""
    @State private var showPersistenceErrorAlert = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    private var formattedDate: String? {
        guard let date = task.dueDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d HH:mm"
        return formatter.string(from: date)
    }
    
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
                                // 勾上时一次回弹 —— 完成反馈。reduceMotion 时禁用。
                                .symbolEffect(.bounce, value: task.isCompleted)
                        } else if task.taskType == .dailyCheckIn {
                            Image(systemName: "calendar")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.blue.opacity(0.5))
                        }
                    }
                    // 完成态切换做空圆 ↔ 渐变圆 + 勾号 的连贯淡入淡出，
                    // 取代 SwiftUI 默认的瞬间 insert/remove。
                    .contentTransition(.opacity)
                }
                .buttonStyle(.plain)
            }
            
            if isEditing {
                TextField("任务名称", text: $editedTitle)
                    .font(.body)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { saveTaskTitle() }
                    .onAppear { editedTitle = task.title }
                
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
                    
                    if let dateStr = formattedDate {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.orange)
                            Text(dateStr)
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                    
                    if let scheduledTimeStr = formattedScheduledTime {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 10))
                                .foregroundStyle(.orange)
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
                    if saveChanges(failureMessage: String(localized: "清除任务时间失败")) {
                        onUpdate()
                    }
                }) {
                    Label("清除时间", systemImage: "calendar.badge.minus")
                }
            }
            Button(action: { showAdvancedEditor = true }) {
                Label("高级设置", systemImage: "gear")
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
                if saveChanges(failureMessage: String(localized: "保存任务时间失败")) {
                    onUpdate()
                }
            }
        }
        .alert("保存失败", isPresented: $showPersistenceErrorAlert) {
            Button("知道了", role: .cancel) { }
        } message: {
            Text(persistenceErrorMessage)
        }
        .sheet(isPresented: $showAdvancedEditor) {
            AdvancedTaskEditor(task: task, modelContext: modelContext, onUpdate: onUpdate)
        }
    }
    
    private func toggleTask() {
        guard task.taskType != .reminder else { return }
        withAnimation(MotionTokens.toggle(reduceMotion: reduceMotion)) {
            task.isCompleted.toggle()
        }
        if saveChanges(failureMessage: String(localized: "更新任务状态失败")) {
            onUpdate()
        }
    }
    
    private func saveTaskTitle() {
        if !editedTitle.trimmingCharacters(in: .whitespaces).isEmpty {
            task.title = editedTitle
            if saveChanges(failureMessage: String(localized: "保存任务名称失败")) {
                onUpdate()
            }
        }
        isEditing = false
    }
    
    private func deleteTask() {
        withAnimation {
            if let group = task.taskGroup {
                group.tasks.removeAll { $0.id == task.id }
            }
            modelContext.delete(task)
            if saveChanges(failureMessage: String(localized: "删除任务失败")) {
                onUpdate()
            }
        }
    }
    
    private func togglePrivacy() {
        guard isProUser else {
            onRequireSubscription()
            return
        }
        task.isPrivate = !(task.isPrivate ?? false)
        if saveChanges(failureMessage: String(localized: "更新任务隐私失败")) {
            onUpdate()
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
