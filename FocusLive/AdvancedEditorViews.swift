//
//  AdvancedEditorViews.swift
//  FocusLive
//

import SwiftUI
import SwiftData

// MARK: - Advanced Task Editor

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
    @State private var selectedTaskType: TaskType = .todo
    @State private var persistenceErrorMessage = ""
    @State private var showPersistenceErrorAlert = false
    @State private var attachments: [Attachment] = []
    @State private var showAddLinkSheet = false
    @State private var newLinkURL = ""
    @State private var newLinkTitle = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("事项类型")) {
                    Picker("类型", selection: $selectedTaskType) {
                        Text("传统待办").tag(TaskType.todo)
                        Text("每日打卡").tag(TaskType.dailyCheckIn)
                        Text("提醒事项").tag(TaskType.reminder)
                    }
                    .pickerStyle(.segmented)
                }

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
                
                // MARK: Attachments
                Section(header: Text("附件链接")) {
                    if attachments.isEmpty {
                        Text("暂无附件")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(attachments) { attachment in
                            HStack(spacing: 10) {
                                Image(systemName: linkIcon(for: attachment))
                                    .foregroundStyle(.blue)
                                    .frame(width: 20)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(attachment.title.isEmpty ? attachment.url : attachment.title)
                                        .font(.subheadline)
                                        .lineLimit(1)
                                    if !attachment.title.isEmpty {
                                        Text(attachment.url)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                Spacer()
                            }
                        }
                        .onDelete { offsets in
                            attachments.remove(atOffsets: offsets)
                        }
                    }
                    
                    Button {
                        newLinkURL = ""
                        newLinkTitle = ""
                        showAddLinkSheet = true
                    } label: {
                        Label("添加链接", systemImage: "plus.circle")
                    }
                }
            }
            .navigationTitle("高级设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                    .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        if saveChanges() { dismiss() }
                    }
                    .fontWeight(.semibold)
                }
            }
            .alert("保存失败", isPresented: $showPersistenceErrorAlert) {
                Button("知道了", role: .cancel) { }
            } message: {
                Text(persistenceErrorMessage)
            }
            .sheet(isPresented: $showAddLinkSheet) {
                NavigationView {
                    Form {
                        Section(header: Text("链接信息")) {
                            TextField("链接地址 (https://...)", text: $newLinkURL)
                                .textContentType(.URL)
                                .keyboardType(.URL)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                            TextField("标题（可选）", text: $newLinkTitle)
                        }
                    }
                    .navigationTitle("添加链接")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("取消") { showAddLinkSheet = false }
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("添加") {
                                addLinkAttachment()
                                showAddLinkSheet = false
                            }
                            .disabled(newLinkURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
                .presentationDetents([.medium])
            }
            .onAppear {
                selectedTaskType = task.taskType ?? .todo
                selectedScheduledTime = task.scheduledTime ?? Date()
                selectedReminderType = task.reminderType ?? .none
                selectedPriority = task.priority ?? .medium
                selectedRepeatType = task.repeatType ?? .none
                repeatInterval = task.repeatInterval ?? 1
                attachments = task.attachments ?? []
            }
        }
    }
    
    @discardableResult
    private func saveChanges() -> Bool {
        task.taskType = selectedTaskType
        task.repeatType = selectedRepeatType == .none ? nil : selectedRepeatType
        task.repeatInterval = selectedRepeatType == .none ? nil : repeatInterval
        task.reminderType = selectedReminderType == .none ? nil : selectedReminderType
        task.priority = selectedPriority
        task.attachments = attachments.isEmpty ? nil : attachments

        let didSave = saveModelContext(modelContext, failureMessage: String(localized: "保存任务高级设置失败")) { message in
            persistenceErrorMessage = message
            showPersistenceErrorAlert = true
        }
        if didSave { onUpdate() }
        return didSave
    }
    
    private func addLinkAttachment() {
        let url = newLinkURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty else { return }
        let normalizedURL = url.hasPrefix("http") ? url : "https://\(url)"
        let title = newLinkTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let attachment = Attachment(id: UUID(), type: .link, url: normalizedURL, title: title)
        attachments.append(attachment)
    }
    
    private func linkIcon(for attachment: Attachment) -> String {
        switch attachment.type {
        case .link: return "link"
        case .file: return "doc"
        case .image: return "photo"
        }
    }
}

// MARK: - Advanced Group Editor

struct AdvancedGroupEditor: View {
    @Bindable var group: TaskGroup
    let modelContext: ModelContext
    let onUpdate: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedScheduledTime: Date = Date()
    @State private var selectedReminderType: ReminderType = .none
    @State private var selectedPriority: Priority = .medium
    @State private var persistenceErrorMessage = ""
    @State private var showPersistenceErrorAlert = false
    
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
                    Button("取消") { dismiss() }
                    .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        if saveChanges() { dismiss() }
                    }
                    .fontWeight(.semibold)
                }
            }
            .alert("保存失败", isPresented: $showPersistenceErrorAlert) {
                Button("知道了", role: .cancel) { }
            } message: {
                Text(persistenceErrorMessage)
            }
            .onAppear {
                selectedScheduledTime = group.scheduledTime ?? Date()
                selectedReminderType = group.reminderType ?? .none
                selectedPriority = group.priority ?? .medium
            }
        }
    }
    
    @discardableResult
    private func saveChanges() -> Bool {
        group.reminderType = selectedReminderType == .none ? nil : selectedReminderType
        group.priority = selectedPriority
        
        let didSave = saveModelContext(modelContext, failureMessage: String(localized: "保存分组高级设置失败")) { message in
            persistenceErrorMessage = message
            showPersistenceErrorAlert = true
        }
        if didSave { onUpdate() }
        return didSave
    }
}
