//
//  ActivityManager.swift
//  FocusLive
//
//  Created by 赵豪伟 on 2026/1/13.
//

import Foundation
import ActivityKit
import SwiftUI
import SwiftData

/// App Group 标识符
private let appGroupID = "group.zhaohaowei.FocusLive"

/// 待同步的任务变更记录
struct PendingTaskChange: Codable {
    let groupID: String
    let taskID: String
    let isCompleted: Bool
    let timestamp: Double
}

/// Live Activity 管理器（单例）
@MainActor
final class ActivityManager {
    static let shared = ActivityManager()
    
    private init() {}
    
    // MARK: - 核心方法：自动同步所有分组的 Live Activity
    
    /// 自动同步 Live Activities
    /// - Parameter groups: 当前 App 中的所有任务分组
    ///
    /// 核心逻辑：
    /// 1. 获取当前所有正在运行的 Activity
    /// 2. 遍历 groups，如果某个 group 有未完成任务且没有对应的 Activity，则自动创建
    /// 3. 如果某个 Activity 对应的 group 已被删除、为空、或已全部完成，则结束该 Activity
    func syncActivities(groups: [TaskGroup]) {
        // 获取所有当前运行中的 Live Activities
        let runningActivities = Activity<FocusAttributes>.activities
        
        // 提取所有运行中 Activity 的 groupID
        let runningGroupIDs = Set(runningActivities.map { $0.attributes.groupID })
        
        // 筛选出有效分组（有未完成任务的分组）
        let validGroups = groups.filter { group in
            !group.tasks.isEmpty && group.incompleteTasks.count > 0
        }
        
        // 提取所有有效分组的 ID
        let validGroupIDs = Set(validGroups.map { $0.id.uuidString })
        
        print("🔄 同步 Live Activities...")
        print("   运行中的 Activities: \(runningGroupIDs.count) 个")
        print("   当前分组数: \(groups.count) 个")
        print("   有效分组数(有未完成任务): \(validGroups.count) 个")
        
        // ========== 第一步：为有未完成任务的分组创建/更新 Activity ==========
        for group in validGroups {
            let groupIDString = group.id.uuidString
            
            // 检查是否已经存在该分组的 Activity
            if !runningGroupIDs.contains(groupIDString) {
                // 不存在，自动创建新的 Live Activity
                print("   ✅ 为分组 '\(group.title)' 创建新 Activity")
                startActivity(for: group)
            } else {
                // 已存在，仅更新内容
                print("   🔁 分组 '\(group.title)' 已有 Activity，更新内容")
                updateActivity(groupID: groupIDString, group: group)
            }
        }
        
        // ========== 第二步：结束无效分组的 Activity ==========
        // 无效情况：分组被删除、分组为空、分组全部完成
        for activity in runningActivities {
            let groupID = activity.attributes.groupID
            
            // 如果该 Activity 对应的分组不在有效分组列表中
            if !validGroupIDs.contains(groupID) {
                // 检查原因
                if let group = groups.first(where: { $0.id.uuidString == groupID }) {
                    if group.tasks.isEmpty {
                        print("   ❌ 分组 '\(group.title)' 为空，结束 Activity")
                    } else if group.incompleteTasks.count == 0 {
                        print("   🎉 分组 '\(group.title)' 已全部完成，结束 Activity")
                    }
                } else {
                    print("   ❌ 分组 ID '\(groupID)' 已删除，结束对应 Activity")
                }
                endActivity(groupID: groupID)
            }
        }
        
        print("✅ 同步完成！")
    }
    
    // MARK: - Activity 操作方法
    
    /// 为指定分组启动 Live Activity
    private func startActivity(for group: TaskGroup) {
        let groupIDString = group.id.uuidString
        let attributes = FocusAttributes(groupID: groupIDString)
        let contentState = FocusAttributes.ContentState(
            groupTitle: group.title,
            groupIcon: group.iconName,
            tasks: group.sortedTasks.map { TaskItemSnapshot(from: $0) }
        )
        
        print("═══════════════════════════════════════════")
        print("📱 [ActivityManager] 创建 Live Activity")
        print("   📌 groupID: \(groupIDString)")
        print("   📌 groupTitle: \(group.title)")
        print("   📋 任务列表:")
        for task in group.sortedTasks {
            print("      - id: \(task.id.uuidString)")
            print("        title: \(task.title)")
            print("        completed: \(task.isCompleted)")
        }
        print("═══════════════════════════════════════════")
        
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: contentState, staleDate: nil),
                pushType: nil
            )
            print("      ✨ Activity 已创建，ID: \(activity.id)")
            print("      ✨ Activity groupID: \(activity.attributes.groupID)")
        } catch {
            print("      ⚠️ 创建 Activity 失败: \(error.localizedDescription)")
        }
    }
    
    /// 更新指定分组的 Live Activity
    func updateActivity(groupID: String, group: TaskGroup) {
        // 查找对应的 Activity
        guard let activity = Activity<FocusAttributes>.activities.first(where: { 
            $0.attributes.groupID == groupID 
        }) else {
            print("   ⚠️ 未找到 groupID=\(groupID) 的 Activity")
            return
        }
        
        let newState = FocusAttributes.ContentState(
            groupTitle: group.title,
            groupIcon: group.iconName,
            tasks: group.sortedTasks.map { TaskItemSnapshot(from: $0) }
        )
        
        Task {
            await updateActivityAsync(activity: activity, newState: newState)
        }
    }
    
    /// 异步更新 Activity（避免主线程阻塞）
    private func updateActivityAsync(activity: Activity<FocusAttributes>, newState: FocusAttributes.ContentState) async {
        let content = ActivityContent(state: newState, staleDate: nil)
        await activity.update(content)
        print("      🔄 Activity 已更新")
    }
    
    /// 更新指定分组中某个任务的状态
    func updateTaskStatus(groupID: String, taskID: String, isCompleted: Bool) {
        guard let activity = Activity<FocusAttributes>.activities.first(where: { 
            $0.attributes.groupID == groupID 
        }) else {
            return
        }
        
        var updatedTasks = activity.content.state.tasks
        if let index = updatedTasks.firstIndex(where: { $0.id == taskID }) {
            updatedTasks[index] = TaskItemSnapshot(
                id: updatedTasks[index].id,
                title: updatedTasks[index].title,
                isCompleted: isCompleted,
                dueDate: updatedTasks[index].dueDate
            )
            
            let newState = FocusAttributes.ContentState(
                groupTitle: activity.content.state.groupTitle,
                groupIcon: activity.content.state.groupIcon,
                tasks: updatedTasks
            )
            
            Task {
                await updateActivityAsync(activity: activity, newState: newState)
            }
        }
    }
    
    /// 结束指定分组的 Live Activity
    func endActivity(groupID: String) {
        guard let activity = Activity<FocusAttributes>.activities.first(where: { 
            $0.attributes.groupID == groupID 
        }) else {
            return
        }
        
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
            print("      🛑 Activity 已结束")
        }
    }
    
    /// 结束所有 Live Activities
    func endAllActivities() {
        for activity in Activity<FocusAttributes>.activities {
            Task {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        print("🛑 所有 Activities 已结束")
    }
    
    // MARK: - Widget 变更同步
    
    /// 从 App Groups 读取并应用 Widget 中的任务变更
    /// - Parameter context: SwiftData ModelContext
    /// - Returns: 是否有变更被应用
    @discardableResult
    func syncPendingChangesFromWidget(context: ModelContext) -> Bool {
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            print("⚠️ 无法访问 App Groups")
            return false
        }
        
        // 读取待同步的变更
        guard let pendingChangesData = defaults.array(forKey: "pendingTaskChanges") as? [[String: Any]],
              !pendingChangesData.isEmpty else {
            return false
        }
        
        print("📥 发现 \(pendingChangesData.count) 个待同步的 Widget 变更")
        
        var hasChanges = false
        
        for changeDict in pendingChangesData {
            guard let groupID = changeDict["groupID"] as? String,
                  let taskID = changeDict["taskID"] as? String,
                  let isCompleted = changeDict["isCompleted"] as? Bool else {
                continue
            }
            
            // 查找对应的任务
            guard let taskUUID = UUID(uuidString: taskID) else {
                print("   ⚠️ 无效的任务 ID: \(taskID)")
                continue
            }
            
            let descriptor = FetchDescriptor<TaskItem>(
                predicate: #Predicate<TaskItem> { $0.id == taskUUID }
            )
            
            do {
                let tasks = try context.fetch(descriptor)
                if let task = tasks.first {
                    if task.isCompleted != isCompleted {
                        task.isCompleted = isCompleted
                        hasChanges = true
                        print("   ✅ 任务 '\(task.title)' 状态已同步为: \(isCompleted)")
                    }
                } else {
                    print("   ⚠️ 未找到任务 ID: \(taskID)")
                }
            } catch {
                print("   ⚠️ 查询任务失败: \(error.localizedDescription)")
            }
        }
        
        // 清空已处理的变更队列
        defaults.removeObject(forKey: "pendingTaskChanges")
        
        if hasChanges {
            do {
                try context.save()
                print("💾 SwiftData 变更已保存")
            } catch {
                print("⚠️ 保存失败: \(error.localizedDescription)")
            }
        }
        
        return hasChanges
    }
    
    /// 检查是否有待同步的 Widget 变更
    func hasPendingWidgetChanges() -> Bool {
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            return false
        }
        
        let pendingChanges = defaults.array(forKey: "pendingTaskChanges") as? [[String: Any]] ?? []
        return !pendingChanges.isEmpty
    }
}
