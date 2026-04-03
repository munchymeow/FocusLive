//
//  TaskModel.swift
//  FocusLive
//
//  Created by 赵豪伟 on 2026/1/13.
//

import Foundation
import SwiftData

/// 重复类型枚举
enum RepeatType: String, Codable {
    case none
    case daily
    case weekly
    case monthly
    case yearly
}

/// 提醒类型枚举
enum ReminderType: String, Codable {
    case none
    case atTime
    case before10min
    case before30min
    case before1hour
    case before6hours
    case before1day
    case before1week
}

/// 优先级枚举
enum Priority: String, Codable {
    case low
    case medium
    case high
    case urgent
}

/// 任务类型：待办 / 提醒 / 每日打卡
enum TaskType: String, Codable {
    case todo
    case reminder
    case dailyCheckIn
}

/// 附件类型
struct Attachment: Codable, Hashable {
    let id: UUID
    let type: AttachmentType
    let url: String
    let title: String
    
    enum AttachmentType: String, Codable {
        case link
        case file
        case image
    }
}

/// 任务项目
@Model
final class TaskItem {
    var id: UUID
    var title: String
    var isCompleted: Bool
    var isPrivate: Bool?
    var taskType: TaskType?
    var dueDate: Date?
    var sortOrder: Int?
    var taskGroup: TaskGroup?
    
    // 新增字段
    var scheduledTime: Date?
    var repeatType: RepeatType?
    var repeatInterval: Int?
    var reminderTime: Date?
    var reminderType: ReminderType?
    var priority: Priority?
    var attachments: [Attachment]?
    
    /// 初始化任务项目
    /// - Parameters:
    ///   - id: 任务唯一标识
    ///   - title: 任务标题
    ///   - isCompleted: 是否已完成
    ///   - isPrivate: 是否为隐私任务
    ///   - taskType: 任务类型（待办/提醒）
    ///   - dueDate: 截止时间
    ///   - sortOrder: 排序权重
    ///   - scheduledTime: 计划时间
    ///   - repeatType: 重复类型
    ///   - repeatInterval: 重复间隔
    ///   - reminderTime: 提醒时间
    ///   - reminderType: 提醒类型
    ///   - priority: 优先级
    ///   - attachments: 附件列表
    init(
        id: UUID = UUID(),
        title: String,
        isCompleted: Bool = false,
        isPrivate: Bool = false,
        taskType: TaskType = .todo,
        dueDate: Date? = nil,
        sortOrder: Int? = 0,
        scheduledTime: Date? = nil,
        repeatType: RepeatType? = RepeatType.none,
        repeatInterval: Int? = 1,
        reminderTime: Date? = nil,
        reminderType: ReminderType? = ReminderType.none,
        priority: Priority? = .medium,
        attachments: [Attachment]? = nil
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.isPrivate = isPrivate
        self.taskType = taskType
        self.dueDate = dueDate
        self.sortOrder = sortOrder
        self.scheduledTime = scheduledTime
        self.repeatType = repeatType
        self.repeatInterval = repeatInterval
        self.reminderTime = reminderTime
        self.reminderType = reminderType
        self.priority = priority
        self.attachments = attachments
    }

    /// 是否为提醒事项（提醒事项不需要完成）
    var isReminder: Bool {
        taskType == .reminder
    }
}

/// 任务分组
@Model
final class TaskGroup {
    var id: UUID
    var title: String
    var iconName: String
    var isPrivate: Bool?
    var sortOrder: Int?
    @Relationship(deleteRule: .cascade) var tasks: [TaskItem]
    
    // 新增字段
    var scheduledTime: Date?
    var reminderTime: Date?
    var reminderType: ReminderType?
    var priority: Priority?
    
    /// 初始化任务分组
    /// - Parameters:
    ///   - id: 分组唯一标识
    ///   - title: 分组标题
    ///   - iconName: 分组图标
    ///   - isPrivate: 是否为隐私分组
    ///   - sortOrder: 排序权重
    ///   - tasks: 分组内任务
    ///   - scheduledTime: 计划时间
    ///   - reminderTime: 提醒时间
    ///   - reminderType: 提醒类型
    ///   - priority: 优先级
    init(
        id: UUID = UUID(),
        title: String,
        iconName: String,
        isPrivate: Bool = false,
        sortOrder: Int? = 0,
        tasks: [TaskItem] = [],
        scheduledTime: Date? = nil,
        reminderTime: Date? = nil,
        reminderType: ReminderType? = ReminderType.none,
        priority: Priority? = .medium
    ) {
        self.id = id
        self.title = title
        self.iconName = iconName
        self.isPrivate = isPrivate
        self.sortOrder = sortOrder
        self.tasks = tasks
        self.scheduledTime = scheduledTime
        self.reminderTime = reminderTime
        self.reminderType = reminderType
        self.priority = priority
    }
    
    /// 按排序顺序获取任务（截止时间优先，然后按创建顺序）
    var sortedTasks: [TaskItem] {
        tasks.sorted { task1, task2 in
            // 1. 有截止时间的排在前面
            switch (task1.dueDate, task2.dueDate) {
            case (nil, nil):
                // 都没有截止时间，按创建顺序
                return (task1.sortOrder ?? 0) < (task2.sortOrder ?? 0)
            case (nil, _):
                // task1 没有截止时间，排后面
                return false
            case (_, nil):
                // task2 没有截止时间，排后面
                return true
            case (let date1?, let date2?):
                // 都有截止时间，时间早的排前面
                if date1 != date2 {
                    return date1 < date2
                }
                // 时间相同，按创建顺序
                return (task1.sortOrder ?? 0) < (task2.sortOrder ?? 0)
            }
        }
    }
    
    /// 计算已完成任务数量
    var completedCount: Int {
        tasks.filter { $0.isCompleted }.count
    }
    
    /// 计算总任务数量
    var totalCount: Int {
        tasks.count
    }
    
    /// 获取未完成的任务
    var incompleteTasks: [TaskItem] {
        sortedTasks.filter { !$0.isCompleted }
    }
}

/// 任务数据的轻量序列化版本（用于传递给 Widget）
struct TaskGroupSnapshot: Codable, Hashable {
    let id: String
    let title: String
    let iconName: String
    let tasks: [TaskItemSnapshot]
    let scheduledTime: Date?
    let reminderTime: Date?
    let reminderType: ReminderType?
    let priority: Priority?
    
    init(from group: TaskGroup) {
        self.id = group.id.uuidString
        self.title = group.title
        self.iconName = group.iconName
        self.scheduledTime = group.scheduledTime
        self.reminderTime = group.reminderTime
        self.reminderType = group.reminderType
        self.priority = group.priority
        // 保持与 TaskGroup.sortedTasks 相同的排序
        self.tasks = group.sortedTasks.map { TaskItemSnapshot(from: $0) }
    }
    
    var completedCount: Int {
        tasks.filter { $0.isCompleted }.count
    }
    
    var totalCount: Int {
        tasks.count
    }
    
    var incompleteTasks: [TaskItemSnapshot] {
        tasks.filter { !$0.isCompleted }
            .sorted { task1, task2 in
                // 1. 有截止时间的排在前面
                switch (task1.dueDate, task2.dueDate) {
                case (nil, nil):
                    // 都没有截止时间，保持原顺序
                    return false
                case (nil, _):
                    // task1 没有截止时间，排后面
                    return false
                case (_, nil):
                    // task2 没有截止时间，排后面
                    return true
                case (let date1?, let date2?):
                    // 都有截止时间，时间早的排前面
                    return date1 < date2
                }
            }
    }
}

struct TaskItemSnapshot: Codable, Hashable {
    let id: String
    let title: String
    let isCompleted: Bool
    let taskType: TaskType?
    let dueDate: Date?
    let scheduledTime: Date?
    let repeatType: RepeatType?
    let repeatInterval: Int?
    let reminderTime: Date?
    let reminderType: ReminderType?
    let priority: Priority?
    let attachments: [Attachment]?
    
    /// 从 TaskItem 创建快照
    init(from item: TaskItem) {
        self.id = item.id.uuidString
        self.title = item.title
        self.isCompleted = item.isCompleted
        self.taskType = item.taskType
        self.dueDate = item.dueDate
        self.scheduledTime = item.scheduledTime
        self.repeatType = item.repeatType
        self.repeatInterval = item.repeatInterval
        self.reminderTime = item.reminderTime
        self.reminderType = item.reminderType
        self.priority = item.priority
        self.attachments = item.attachments
    }
    
    /// 直接创建快照（用于更新状态）
    init(id: String, title: String, isCompleted: Bool, taskType: TaskType? = nil, dueDate: Date? = nil, scheduledTime: Date? = nil, repeatType: RepeatType? = nil, repeatInterval: Int? = nil, reminderTime: Date? = nil, reminderType: ReminderType? = nil, priority: Priority? = nil, attachments: [Attachment]? = nil) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.taskType = taskType
        self.dueDate = dueDate
        self.scheduledTime = scheduledTime
        self.repeatType = repeatType
        self.repeatInterval = repeatInterval
        self.reminderTime = reminderTime
        self.reminderType = reminderType
        self.priority = priority
        self.attachments = attachments
    }
    
    /// 格式化截止日期
    var formattedDueDate: String? {
        guard let date = dueDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d HH:mm"
        return formatter.string(from: date)
    }

    /// 保留现有元数据，仅更新完成状态
    func updatingCompletion(_ isCompleted: Bool) -> TaskItemSnapshot {
        TaskItemSnapshot(
            id: id,
            title: title,
            isCompleted: isCompleted,
            taskType: taskType,
            dueDate: dueDate,
            scheduledTime: scheduledTime,
            repeatType: repeatType,
            repeatInterval: repeatInterval,
            reminderTime: reminderTime,
            reminderType: reminderType,
            priority: priority,
            attachments: attachments
        )
    }
}
