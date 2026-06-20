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
import SwiftData
import os


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
        debugLog("═══════════════════════════════════════════")
        debugLog("🎯 [ToggleTaskIntent] perform() 被调用!")
        debugLog("   📌 groupID: \(groupID)")
        debugLog("   📌 taskID: \(taskID)")
        debugLog("═══════════════════════════════════════════")
        
        // 列出所有正在运行的 Activities
        let allActivities = Activity<FocusAttributes>.activities
        debugLog("   📋 当前运行的 Activities 数量: \(allActivities.count)")
        for (index, act) in allActivities.enumerated() {
            debugLog("      [\(index)] Activity ID: \(act.id)")
            debugLog("          groupID: \(act.attributes.groupID)")
            debugLog("          任务数: \(act.content.state.tasks.count)")
        }
        
        // 找到对应的 Live Activity
        guard let activity = Activity<FocusAttributes>.activities.first(where: { 
            $0.attributes.groupID == groupID 
        }) else {
            debugLog("   ❌ 未找到 groupID=\(groupID) 的 Activity!")
            debugLog("═══════════════════════════════════════════")
            return .result()
        }
        
        debugLog("   ✅ 找到匹配的 Activity: \(activity.id)")
        
        // 获取当前任务列表
        var updatedTasks = activity.content.state.tasks
        debugLog("   📋 当前任务列表:")
        for (index, task) in updatedTasks.enumerated() {
            debugLog("      [\(index)] id=\(task.id), title=\(task.title), completed=\(task.isCompleted)")
        }
        
        // 查找并更新任务状态
        guard let index = updatedTasks.firstIndex(where: { $0.id == taskID }) else {
            debugLog("   ❌ 未找到 taskID=\(taskID) 的任务!")
            debugLog("═══════════════════════════════════════════")
            return .result()
        }
        
        let currentTask = updatedTasks[index]
        if currentTask.taskType == .reminder {
            debugLog("   ℹ️ 提醒事项不支持完成状态切换，忽略操作")
            debugLog("═══════════════════════════════════════════")
            return .result()
        }
        let newCompletedStatus = !currentTask.isCompleted
        
        debugLog("   🔄 准备更新任务:")
        debugLog("      任务: \(currentTask.title)")
        debugLog("      原状态: \(currentTask.isCompleted)")
        debugLog("      新状态: \(newCompletedStatus)")
        
        // 保留现有样式与元数据，仅切换完成状态
        updatedTasks[index] = currentTask.updatingCompletion(newCompletedStatus)
        
        debugLog("   ✅ 任务 '\(currentTask.title)' 状态切换为: \(newCompletedStatus)")
        
        // 构建新的状态
        let newState = FocusAttributes.ContentState(
            groupTitle: activity.content.state.groupTitle,
            groupIcon: activity.content.state.groupIcon,
            tasks: updatedTasks,
            renderVersion: activity.content.state.renderVersion,
            fontColorName: activity.content.state.fontColorName
        )
        
        debugLog("   📤 准备更新 Live Activity...")
        
        let didPersistToStore = persistTaskChangeToSwiftData(taskID: taskID, isCompleted: newCompletedStatus)

        // 更新 Live Activity
        let content = ActivityContent(state: newState, staleDate: nil)
        await activity.update(content)
        debugLog("   ✅ Live Activity 已更新!")
        
        if !didPersistToStore {
            // 直接落库失败时才保留待同步队列作为兜底。
            saveTaskChangeToAppGroup(groupID: groupID, taskID: taskID, isCompleted: newCompletedStatus)
        }
        
        debugLog("═══════════════════════════════════════════")
        debugLog("🎉 [ToggleTaskIntent] 执行完成!")
        debugLog("═══════════════════════════════════════════")
        
        return .result()
    }

    private func persistTaskChangeToSwiftData(taskID: String, isCompleted: Bool) -> Bool {
        guard let taskUUID = UUID(uuidString: taskID) else {
            debugLog("   ⚠️ 无效的 taskID，无法直接落库")
            return false
        }

        do {
            let context = try makeSharedModelContext()
            resetDailyCheckInTasksIfNeeded(context: context)

            let descriptor = FetchDescriptor<TaskItem>(
                predicate: #Predicate<TaskItem> { $0.id == taskUUID }
            )
            guard let task = try context.fetch(descriptor).first else {
                debugLog("   ⚠️ 未在 SwiftData 中找到任务，保留 pending 兜底")
                return false
            }
            guard task.taskType != .reminder else {
                return true
            }

            if task.isCompleted != isCompleted {
                task.isCompleted = isCompleted
                // Create next repeat instance when completing a repeating task
                if isCompleted, let group = task.taskGroup,
                   let nextTask = createNextRepeatTask(from: task) {
                    group.tasks.append(nextTask)
                }
            }
            try context.save()
            debugLog("   💾 任务状态已直接写入 SwiftData")
            return true
        } catch {
            debugLog("   ⚠️ 直接写入 SwiftData 失败: \(error.localizedDescription)")
            return false
        }
    }

    private func resetDailyCheckInTasksIfNeeded(context: ModelContext) {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        let today = Calendar.current.startOfDay(for: Date())
        let lastResetDate = defaults.object(forKey: lastDailyCheckInResetDateKey) as? Date
        guard lastResetDate == nil || lastResetDate! < today else { return }

        let descriptor = FetchDescriptor<TaskItem>()
        if let tasks = try? context.fetch(descriptor) {
            for task in tasks where task.taskType == .dailyCheckIn && task.isCompleted {
                task.isCompleted = false
            }
        }
        defaults.set(today, forKey: lastDailyCheckInResetDateKey)
    }

    private func makeSharedModelContext() throws -> ModelContext {
        let schema = Schema([TaskGroup.self, TaskItem.self])
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            throw ToggleTaskPersistenceError.appGroupUnavailable
        }

        let storeURL = containerURL.appendingPathComponent("FocusLive.store")
        let configuration = ModelConfiguration(
            schema: schema,
            url: storeURL,
            allowsSave: true
        )
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }
    
    /// 保存任务状态变更到 App Groups（供主 App 读取同步）
    private func saveTaskChangeToAppGroup(groupID: String, taskID: String, isCompleted: Bool) {
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            debugLog("   ⚠️ 无法访问 App Groups")
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
        
        debugLog("   💾 变更已保存到 App Groups，等待主 App 同步")
    }
}

private enum ToggleTaskPersistenceError: Error {
    case appGroupUnavailable
}
