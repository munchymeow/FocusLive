//
//  FocusAttributes.swift
//  FocusLive
//
//  Created by 赵豪伟 on 2026/1/13.
//

import Foundation
import ActivityKit
import SwiftUI

/// Live Activity 的静态属性（创建后不可更改）
struct FocusAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // 动态内容（可更新）
        var groupTitle: String
        var groupIcon: String
        var tasks: [TaskItemSnapshot]
        /// 仅用于强制触发渲染刷新（例如样式设置变化）
        var renderVersion: Double? = nil
        /// 字体颜色名称（与 liveActivityFontColor UserDefaults key 对应）
        var fontColorName: String = "default"

        /// 传统待办（用于进度统计）
        var todoTasks: [TaskItemSnapshot] {
            tasks.filter { $0.taskType != .reminder }
        }

        /// 未完成待办（可交互完成）
        var todoIncompleteTasks: [TaskItemSnapshot] {
            todoTasks.filter { !$0.isCompleted }
                .sorted { task1, task2 in
                    switch (task1.dueDate, task2.dueDate) {
                    case (nil, nil):
                        return false
                    case (nil, _):
                        return false
                    case (_, nil):
                        return true
                    case (let date1?, let date2?):
                        return date1 < date2
                    }
                }
        }

        /// 提醒事项（不需要完成）
        var reminderTasks: [TaskItemSnapshot] {
            tasks.filter { $0.taskType == .reminder }
                .sorted { task1, task2 in
                    switch (task1.dueDate, task2.dueDate) {
                    case (nil, nil):
                        return false
                    case (nil, _):
                        return false
                    case (_, nil):
                        return true
                    case (let date1?, let date2?):
                        return date1 < date2
                    }
                }
        }
        
        var completedCount: Int {
            todoTasks.filter { $0.isCompleted }.count
        }
        
        var totalCount: Int {
            todoTasks.count
        }
        
        /// Live Activity 展示列表：未完成待办 + 提醒事项
        var incompleteTasks: [TaskItemSnapshot] {
            tasks.filter { ($0.taskType == .reminder) || !$0.isCompleted }
                .sorted { task1, task2 in
                    switch (task1.dueDate, task2.dueDate) {
                    case (nil, nil):
                        return false
                    case (nil, _):
                        return false
                    case (_, nil):
                        return true
                    case (let date1?, let date2?):
                        return date1 < date2
                    }
                }
        }
        
        var remainingCount: Int {
            max(0, incompleteTasks.count)
        }
        
        /// 计算进度（0.0 ~ 1.0），防止除零错误
        var progress: Double {
            guard totalCount > 0 else { return 0 }
            return Double(completedCount) / Double(totalCount)
        }
    }
    
    // 静态属性（用于标识不同的 Activity）
    var groupID: String
}
