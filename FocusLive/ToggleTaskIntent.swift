//
//  ToggleTaskIntent.swift
//  FocusLive
//
//  Live Activity 交互 Intent - 切换任务完成状态
//  注意：此文件需要同时包含在 FocusLive 和 FocusWidgetExtension 两个 target 中
//
//  根据 Apple 文档：LiveActivityIntent 会在主 App 进程中运行
//

import Foundation
import AppIntents
import ActivityKit

/// App Group 标识符（用于数据共享）
private let appGroupID = "group.com.QingTeng.FocusLive"

/// 切换任务完成状态的交互意图
/// 用于 Live Activity 锁屏交互，点击小圆点标记任务完成
struct ToggleTaskIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "切换任务状态"
    static var description = IntentDescription("在锁屏上标记任务为已完成或未完成")
    
    /// 关键：设置为 false 才能在锁屏上直接执行，不打开 App
    static var openAppWhenRun: Bool = false
    
    @Parameter(title: "分组 ID", default: "")
    var groupID: String
    
    @Parameter(title: "任务 ID", default: "")
    var taskID: String
    
    init() {
        self.groupID = ""
        self.taskID = ""
    }
    
    init(groupID: String, taskID: String) {
        self.groupID = groupID
        self.taskID = taskID
    }
    
    @MainActor
    func perform() async throws -> some IntentResult {
        print("═══════════════════════════════════════════")
        print("🎯 [ToggleTaskIntent] perform() 被调用!")
        print("   📌 groupID: \(groupID)")
        print("   📌 taskID: \(taskID)")
        print("═══════════════════════════════════════════")
        
        // 列出所有正在运行的 Activities
        let allActivities = Activity<FocusAttributes>.activities
        print("   📋 当前运行的 Activities 数量: \(allActivities.count)")
        for (index, act) in allActivities.enumerated() {
            print("      [\(index)] Activity ID: \(act.id)")
            print("          groupID: \(act.attributes.groupID)")
            print("          任务数: \(act.content.state.tasks.count)")
        }
        
        // 找到对应的 Live Activity
        guard let activity = Activity<FocusAttributes>.activities.first(where: { 
            $0.attributes.groupID == groupID 
        }) else {
            print("   ❌ 未找到 groupID=\(groupID) 的 Activity!")
            print("═══════════════════════════════════════════")
            return .result()
        }
        
        print("   ✅ 找到匹配的 Activity: \(activity.id)")
        
        // 获取当前任务列表
        var updatedTasks = activity.content.state.tasks
        print("   📋 当前任务列表:")
        for (index, task) in updatedTasks.enumerated() {
            print("      [\(index)] id=\(task.id), title=\(task.title), completed=\(task.isCompleted)")
        }
        
        // 查找并更新任务状态
        guard let index = updatedTasks.firstIndex(where: { $0.id == taskID }) else {
            print("   ❌ 未找到 taskID=\(taskID) 的任务!")
            print("═══════════════════════════════════════════")
            return .result()
        }
        
        let currentTask = updatedTasks[index]
        let newCompletedStatus = !currentTask.isCompleted
        
        print("   🔄 准备更新任务:")
        print("      任务: \(currentTask.title)")
        print("      原状态: \(currentTask.isCompleted)")
        print("      新状态: \(newCompletedStatus)")
        
        // 创建新的任务快照（保留 dueDate）
        updatedTasks[index] = TaskItemSnapshot(
            id: currentTask.id,
            title: currentTask.title,
            isCompleted: newCompletedStatus,
            dueDate: currentTask.dueDate
        )
        
        print("   ✅ 任务 '\(currentTask.title)' 状态切换为: \(newCompletedStatus)")
        
        // 构建新的状态
        let newState = FocusAttributes.ContentState(
            groupTitle: activity.content.state.groupTitle,
            groupIcon: activity.content.state.groupIcon,
            tasks: updatedTasks
        )
        
        print("   📤 准备更新 Live Activity...")
        
        // 更新 Live Activity
        let content = ActivityContent(state: newState, staleDate: nil)
        await activity.update(content)
        print("   ✅ Live Activity 已更新!")
        
        // 通过 App Groups 保存变更，供主 App 同步
        saveTaskChangeToAppGroup(groupID: groupID, taskID: taskID, isCompleted: newCompletedStatus)
        
        print("═══════════════════════════════════════════")
        print("🎉 [ToggleTaskIntent] 执行完成!")
        print("═══════════════════════════════════════════")
        
        return .result()
    }
    
    /// 保存任务状态变更到 App Groups（供主 App 读取同步）
    private func saveTaskChangeToAppGroup(groupID: String, taskID: String, isCompleted: Bool) {
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            print("   ⚠️ 无法访问 App Groups")
            return
        }
        
        // 保存待同步的变更记录
        let changeRecord: [String: Any] = [
            "groupID": groupID,
            "taskID": taskID,
            "isCompleted": isCompleted,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        // 追加到变更队列
        var pendingChanges = defaults.array(forKey: "pendingTaskChanges") as? [[String: Any]] ?? []
        pendingChanges.append(changeRecord)
        defaults.set(pendingChanges, forKey: "pendingTaskChanges")
        
        print("   💾 变更已保存到 App Groups，等待主 App 同步")
    }
}
