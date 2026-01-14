//
//  TaskModel.swift
//  FocusLive
//
//  Created by 赵豪伟 on 2026/1/13.
//

import Foundation
import SwiftData

/// 任务项目
@Model
final class TaskItem {
    var id: UUID
    var title: String
    var isCompleted: Bool
    var isPrivate: Bool?
    var dueDate: Date?
    var sortOrder: Int?
    var taskGroup: TaskGroup?
    
    /// 初始化任务项目
    /// - Parameters:
    ///   - id: 任务唯一标识
    ///   - title: 任务标题
    ///   - isCompleted: 是否已完成
    ///   - isPrivate: 是否为隐私任务
    ///   - dueDate: 截止时间
    ///   - sortOrder: 排序权重
    init(
        id: UUID = UUID(),
        title: String,
        isCompleted: Bool = false,
        isPrivate: Bool = false,
        dueDate: Date? = nil,
        sortOrder: Int? = 0
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.isPrivate = isPrivate
        self.dueDate = dueDate
        self.sortOrder = sortOrder
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
    
    /// 初始化任务分组
    /// - Parameters:
    ///   - id: 分组唯一标识
    ///   - title: 分组标题
    ///   - iconName: 分组图标
    ///   - isPrivate: 是否为隐私分组
    ///   - sortOrder: 排序权重
    ///   - tasks: 分组内任务
    init(
        id: UUID = UUID(),
        title: String,
        iconName: String,
        isPrivate: Bool = false,
        sortOrder: Int? = 0,
        tasks: [TaskItem] = []
    ) {
        self.id = id
        self.title = title
        self.iconName = iconName
        self.isPrivate = isPrivate
        self.sortOrder = sortOrder
        self.tasks = tasks
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
    
    init(from group: TaskGroup) {
        self.id = group.id.uuidString
        self.title = group.title
        self.iconName = group.iconName
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
    let dueDate: Date?
    
    /// 从 TaskItem 创建快照
    init(from item: TaskItem) {
        self.id = item.id.uuidString
        self.title = item.title
        self.isCompleted = item.isCompleted
        self.dueDate = item.dueDate
    }
    
    /// 直接创建快照（用于更新状态）
    init(id: String, title: String, isCompleted: Bool, dueDate: Date? = nil) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.dueDate = dueDate
    }
    
    /// 格式化截止日期
    var formattedDueDate: String? {
        guard let date = dueDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d HH:mm"
        return formatter.string(from: date)
    }
}
