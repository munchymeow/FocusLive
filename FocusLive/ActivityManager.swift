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
import WidgetKit

/// App Group 标识符
private let appGroupID = "group.com.QingTeng.FocusLive"
private let allowedGroupIDsKey = "liveActivityAllowedGroupIDs"
private let proStatusKey = "isProUser"
private let smartReminderKey = "smartReminderEnabled"
private let dailyMotivationEnabledKey = "dailyMotivationEnabled"
private let lastMotivationDateKey = "lastMotivationDate"
private let currentMotivationQuoteKey = "currentMotivationQuote"
private let currentMotivationAuthorKey = "currentMotivationAuthor"
private let widgetDisplaySnapshotKey = "widgetDisplaySnapshot"

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
        
        let allowedGroupIDs = resolvedAllowedGroupIDs(for: groups)
        let isProUser = currentProStatus()
        let orderedGroups = orderedGroups(from: groups)
        
        // 筛选出有效分组（有未完成且非隐私任务的分组，且分组未完成）
        var validGroups = orderedGroups.filter { group in
            guard allowedGroupIDs.contains(group.id.uuidString) else { return false }
            let publicTasks = publicTasks(for: group)
            let publicIncomplete = publicTasks.filter { !$0.isCompleted }
            return !publicTasks.isEmpty && !publicIncomplete.isEmpty
        }
        
        // 根据订阅状态限制分组数量
        let maxGroups = isProUser ? 3 : 2
        if validGroups.count > maxGroups {
            validGroups = Array(validGroups.prefix(maxGroups))
        }
        
        if !isProUser, let firstGroup = validGroups.first {
            validGroups = [firstGroup]
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

            // 跳过特殊类型 Activity（每日鼓励 / 智能提醒）
            if isSpecialActivity(groupID: groupID) {
                continue
            }
            
            // 如果该 Activity 对应的分组不在有效分组列表中
            if !validGroupIDs.contains(groupID) {
                // 检查原因
            if let group = groups.first(where: { $0.id.uuidString == groupID }) {
                let publicTasks = publicTasks(for: group)
                let publicIncomplete = publicTasks.filter { !$0.isCompleted }
                if publicTasks.isEmpty {
                    print("   🔒 分组 '\(group.title)' 仅含隐私任务，结束 Activity")
                } else if publicIncomplete.isEmpty {
                    print("   🎉 分组 '\(group.title)' 已全部完成，结束 Activity")
                } else {
                    print("   ❌ 分组 '\(group.title)' 不满足显示条件，结束 Activity")
                }
            } else {
                print("   ❌ 分组 ID '\(groupID)' 已删除，结束对应 Activity")
            }
                endActivity(groupID: groupID)
            }
        }
        
        print("✅ 同步完成！")
        
        // 检查并创建智能提醒 Live Activity（仅Pro用户且开启开关）
        if isProUser && isSmartReminderEnabled() {
            checkAndCreateSmartReminders(groups: groups)
        }

        // 调度/取消本地通知智能提醒
        if isProUser && isSmartReminderEnabled() {
            Task {
                let granted = await NotificationManager.shared.requestPermission()
                if granted {
                    NotificationManager.shared.rescheduleSmartReminders(groups: groups)
                }
            }
        } else {
            NotificationManager.shared.cancelAllSmartReminders()
        }
        
        // 根据每日鼓励开关与分组选择同步励志名言活动
        checkAndCreateMotivationActivityIfNeeded()

        // 持久化主屏 Widget 当前应显示的内容
        persistWidgetSnapshot(validGroups: validGroups)
        
        // 刷新主屏幕小组件
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// 检查并创建智能提醒
    /// - Parameter groups: 当前所有分组
    func checkAndCreateSmartReminders(groups: [TaskGroup]) {
        let now = Date()
        var reminders: [(title: String, time: Date, priority: Priority)] = []
        
        // 检查分组提醒
        for group in groups {
            if let scheduledTime = group.scheduledTime,
               let reminderType = group.reminderType,
               reminderType != .none {
                let reminderTime = calculateReminderTime(for: scheduledTime, reminderType: reminderType)
                if reminderTime <= now && scheduledTime > now {
                    reminders.append((
                        title: "分组提醒: \(group.title)",
                        time: scheduledTime,
                        priority: group.priority ?? .medium
                    ))
                }
            }
        }
        
        // 检查任务提醒
        for group in groups {
            for task in group.tasks {
                if let scheduledTime = task.scheduledTime,
                   let reminderType = task.reminderType,
                   reminderType != .none,
                   !(task.isCompleted) {
                    let reminderTime = calculateReminderTime(for: scheduledTime, reminderType: reminderType)
                    if reminderTime <= now && scheduledTime > now {
                        reminders.append((
                            title: "任务提醒: \(task.title)",
                            time: scheduledTime,
                            priority: task.priority ?? .medium
                        ))
                    }
                }
            }
        }
        
        // 按优先级和时间排序
        reminders.sort { (a, b) in
            if a.priority != b.priority {
                return priorityValue(a.priority) > priorityValue(b.priority)
            }
            return a.time < b.time
        }
        
        // 只显示最高优先级的提醒（Pro用户）
        if let topReminder = reminders.first, currentProStatus() {
            createSmartReminderActivity(reminder: topReminder)
        }
    }
    
    /// 计算提醒时间
    private func calculateReminderTime(for scheduledTime: Date, reminderType: ReminderType) -> Date {
        let calendar = Calendar.current
        switch reminderType {
        case .atTime:
            return scheduledTime
        case .before10min:
            return calendar.date(byAdding: .minute, value: -10, to: scheduledTime) ?? scheduledTime
        case .before30min:
            return calendar.date(byAdding: .minute, value: -30, to: scheduledTime) ?? scheduledTime
        case .before1hour:
            return calendar.date(byAdding: .hour, value: -1, to: scheduledTime) ?? scheduledTime
        case .before6hours:
            return calendar.date(byAdding: .hour, value: -6, to: scheduledTime) ?? scheduledTime
        case .before1day:
            return calendar.date(byAdding: .day, value: -1, to: scheduledTime) ?? scheduledTime
        case .before1week:
            return calendar.date(byAdding: .day, value: -7, to: scheduledTime) ?? scheduledTime
        case .none:
            return scheduledTime
        }
    }
    
    /// 获取优先级数值（用于排序）
    private func priorityValue(_ priority: Priority) -> Int {
        switch priority {
        case .urgent: return 4
        case .high: return 3
        case .medium: return 2
        case .low: return 1
        }
    }
    
    /// 创建智能提醒Activity
    private func createSmartReminderActivity(reminder: (title: String, time: Date, priority: Priority)) {
        let reminderID = "smart_reminder_\(UUID().uuidString)"
        let attributes = FocusAttributes(groupID: reminderID)
        
        let timeInterval = reminder.time.timeIntervalSinceNow
        let countdownText: String
        if timeInterval <= 0 {
            countdownText = "时间已到！"
        } else if timeInterval < 3600 { // 不到1小时
            let minutes = Int(timeInterval / 60)
            countdownText = "还剩 \(minutes) 分钟"
        } else if timeInterval < 86400 { // 不到1天
            let hours = Int(timeInterval / 3600)
            let minutes = Int((timeInterval.truncatingRemainder(dividingBy: 3600)) / 60)
            countdownText = "还剩 \(hours)小时\(minutes)分钟"
        } else {
            let days = Int(timeInterval / 86400)
            countdownText = "还剩 \(days) 天"
        }
        
        let contentState = FocusAttributes.ContentState(
            groupTitle: reminder.title,
            groupIcon: "⏰",
            tasks: [
                TaskItemSnapshot(
                    id: "countdown",
                    title: countdownText,
                    isCompleted: false
                )
            ],
            renderVersion: Date().timeIntervalSince1970
        )
        
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: contentState, staleDate: nil),
                pushType: nil
            )
            print("🔔 智能提醒 Activity 已创建: \(reminder.title)")
            
            // 设置自动结束时间
            Task {
                try? await Task.sleep(nanoseconds: UInt64(max(timeInterval, 60)) * 1_000_000_000)
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        } catch {
            print("⚠️ 创建智能提醒失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Activity 操作方法
    
    /// 为指定分组启动 Live Activity
    private func startActivity(for group: TaskGroup) {
        let groupIDString = group.id.uuidString
        let attributes = FocusAttributes(groupID: groupIDString)
        let publicTasks = publicTasks(for: group)
        let contentState = FocusAttributes.ContentState(
            groupTitle: group.title,
            groupIcon: group.iconName,
            tasks: publicTasks.map { TaskItemSnapshot(from: $0) },
            renderVersion: Date().timeIntervalSince1970
        )
        
        print("═══════════════════════════════════════════")
        print("📱 [ActivityManager] 创建 Live Activity")
        print("   📌 groupID: \(groupIDString)")
        print("   📌 groupTitle: \(group.title)")
        print("   📋 任务列表(非隐私):")
        for task in publicTasks {
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
        
        let publicTasks = publicTasks(for: group)
        let newState = FocusAttributes.ContentState(
            groupTitle: group.title,
            groupIcon: group.iconName,
            tasks: publicTasks.map { TaskItemSnapshot(from: $0) },
            renderVersion: Date().timeIntervalSince1970
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
                taskType: updatedTasks[index].taskType,
                dueDate: updatedTasks[index].dueDate
            )
            
            let newState = FocusAttributes.ContentState(
                groupTitle: activity.content.state.groupTitle,
                groupIcon: activity.content.state.groupIcon,
                tasks: updatedTasks,
                renderVersion: Date().timeIntervalSince1970
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

    /// 获取分组中可用于 Live Activity 的非隐私任务
    /// - Parameter group: 任务分组
    /// - Returns: 已按排序规则处理的非隐私任务
    private func publicTasks(for group: TaskGroup) -> [TaskItem] {
        guard !(group.isPrivate ?? false) else { return [] }
        return group.sortedTasks.filter { !($0.isPrivate ?? false) }
    }
    
    /// 获取按排序权重排序的分组列表
    /// - Parameter groups: 原始分组列表
    /// - Returns: 排序后的分组列表
    private func orderedGroups(from groups: [TaskGroup]) -> [TaskGroup] {
        groups.sorted { ($0.sortOrder ?? 0) < ($1.sortOrder ?? 0) }
    }
    
    /// 获取允许显示的分组 ID 列表
    /// - Parameter groups: 当前分组列表
    /// - Returns: 允许显示的分组 ID 集合
    private func resolvedAllowedGroupIDs(for groups: [TaskGroup]) -> Set<String> {
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            return Set(groups.map { $0.id.uuidString })
        }
        if let stored = defaults.array(forKey: allowedGroupIDsKey) as? [String] {
            return Set(stored)
        }
        return Set(groups.map { $0.id.uuidString })
    }
    
    /// 获取当前会员状态
    /// - Returns: 是否为会员
    private func currentProStatus() -> Bool {
        UserDefaults(suiteName: appGroupID)?.bool(forKey: proStatusKey) ?? false
    }
    
    /// 获取智能提醒开关状态
    /// - Returns: 是否开启智能提醒
    private func isSmartReminderEnabled() -> Bool {
        UserDefaults(suiteName: appGroupID)?.bool(forKey: smartReminderKey) ?? false
    }

    /// 检查是否有活跃的分组活动
    /// - Returns: 是否有分组活动正在运行
    func hasActiveGroupActivities() -> Bool {
        let runningActivities = Activity<FocusAttributes>.activities
        return runningActivities.contains { !isSpecialActivity(groupID: $0.attributes.groupID) }
    }
    
    /// 创建励志名言活动
    /// - Parameters:
    ///   - quote: 名言文本
    ///   - author: 作者（可选）
    func createMotivationActivity(quote: String, author: String?) {
        let motivationID = "motivation_\(UUID().uuidString)"
        let attributes = FocusAttributes(groupID: motivationID)
        
        // 格式化名言显示
        let displayText = quote
        let authorText = author != nil ? "\n——\(author!)" : ""
        let fullText = displayText + authorText
        
        let contentState = FocusAttributes.ContentState(
            groupTitle: "每日鼓励",
            groupIcon: "💡",
            tasks: [
                TaskItemSnapshot(
                    id: "quote",
                    title: fullText,
                    isCompleted: false
                )
            ],
            renderVersion: Date().timeIntervalSince1970
        )
        
        do {
            _ = try Activity.request(
                attributes: attributes,
                content: .init(state: contentState, staleDate: nil),
                pushType: nil
            )
            print("💡 励志名言 Activity 已创建")
        } catch {
            print("⚠️ 创建励志名言 Activity 失败: \(error.localizedDescription)")
        }
    }
    
    /// 结束励志名言活动
    func endMotivationActivity() {
        let runningActivities = Activity<FocusAttributes>.activities
        for activity in runningActivities where activity.attributes.groupID.hasPrefix("motivation_") {
            Task {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        print("💡 励志名言 Activity 已结束")
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
            guard let taskID = changeDict["taskID"] as? String,
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

    /// 检查并创建励志名言活动（如果需要）
    private func checkAndCreateMotivationActivityIfNeeded() {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        
        let isEnabled = defaults.object(forKey: dailyMotivationEnabledKey) as? Bool ?? true
        let storedSelection = defaults.array(forKey: allowedGroupIDsKey) as? [String]
        let shouldShowMotivation = isEnabled && (storedSelection?.isEmpty == true)
        
        guard shouldShowMotivation else {
            endMotivationActivity()
            return
        }
        
        let motivationActivities = Activity<FocusAttributes>.activities.filter {
            $0.attributes.groupID.hasPrefix("motivation_")
        }
        
        // 检查是否需要更新名言（每天更换）
        let lastDate = defaults.object(forKey: lastMotivationDateKey) as? Date
        let today = Calendar.current.startOfDay(for: Date())
        let isToday = lastDate.map { Calendar.current.isDate($0, inSameDayAs: today) } ?? false
        
        // 同一天内，如果没有正在运行的每日鼓励卡片，按已存内容恢复
        if isToday {
            guard motivationActivities.isEmpty else { return }
            
            let storedQuote = defaults.string(forKey: currentMotivationQuoteKey)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !storedQuote.isEmpty {
                let storedAuthor = defaults.string(forKey: currentMotivationAuthorKey)
                createMotivationActivity(quote: storedQuote, author: storedAuthor)
                return
            }
            
            createRandomMotivationActivity(defaults: defaults, for: today)
            return
        }
        
        // 新的一天：先结束旧卡片，再随机生成当天内容
        if !motivationActivities.isEmpty {
            endMotivationActivity()
        }
        createRandomMotivationActivity(defaults: defaults, for: today)
    }
    
    /// 随机选择一句名言并创建活动，同时持久化当天内容
    private func createRandomMotivationActivity(defaults: UserDefaults, for dayStart: Date) {
        guard let selected = randomMotivationQuoteFromCSV() else { return }
        
        defaults.set(selected.quote, forKey: currentMotivationQuoteKey)
        if let author = selected.author, !author.isEmpty {
            defaults.set(author, forKey: currentMotivationAuthorKey)
        } else {
            defaults.removeObject(forKey: currentMotivationAuthorKey)
        }
        defaults.set(dayStart, forKey: lastMotivationDateKey)
        
        createMotivationActivity(quote: selected.quote, author: selected.author)
    }
    
    /// 从 CSV 中随机获取一句名言
    private func randomMotivationQuoteFromCSV() -> (quote: String, author: String?)? {
        guard let url = Bundle.main.url(forResource: "motivational_quotes", withExtension: "csv"),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }
        
        let quotes = content.components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        
        guard let line = quotes.randomElement() else { return nil }
        return parseMotivationLine(line)
    }
    
    /// 解析 CSV 行："名言"——作者
    private func parseMotivationLine(_ line: String) -> (quote: String, author: String?) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let range = trimmed.range(of: "——", options: .backwards) else {
            return (cleanedQuote(trimmed), nil)
        }
        
        let rawQuote = String(trimmed[..<range.lowerBound])
        let rawAuthor = String(trimmed[range.upperBound...])
        let quote = cleanedQuote(rawQuote)
        let author = rawAuthor.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return (quote, author.isEmpty ? nil : author)
    }
    
    /// 清洗名言文本（去掉包裹引号）
    private func cleanedQuote(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("\""), text.hasSuffix("\""), text.count >= 2 {
            text.removeFirst()
            text.removeLast()
        }
        return text.trimmingCharacters(in: CharacterSet(charactersIn: "“”\""))
    }
    
    /// 是否为特殊 Activity（不是普通分组 Activity）
    private func isSpecialActivity(groupID: String) -> Bool {
        groupID.hasPrefix("motivation_") || groupID.hasPrefix("smart_reminder_")
    }

    // MARK: - 主屏 Widget 快照同步

    private func persistWidgetSnapshot(validGroups: [TaskGroup]) {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }

        if let group = validGroups.first {
            let state = FocusAttributes.ContentState(
                groupTitle: group.title,
                groupIcon: group.iconName,
                tasks: publicTasks(for: group).map { TaskItemSnapshot(from: $0) },
                renderVersion: Date().timeIntervalSince1970
            )
            persistWidgetSnapshot(state: state, defaults: defaults)
            return
        }

        if let reminderActivity = Activity<FocusAttributes>.activities.first(where: {
            $0.attributes.groupID.hasPrefix("smart_reminder_")
        }) {
            persistWidgetSnapshot(state: reminderActivity.content.state, defaults: defaults)
            return
        }

        let selectedGroups = defaults.array(forKey: allowedGroupIDsKey) as? [String]
        let isMotivationEnabled = defaults.object(forKey: dailyMotivationEnabledKey) as? Bool ?? true
        let shouldShowMotivation = isMotivationEnabled && (selectedGroups?.isEmpty == true)

        if shouldShowMotivation {
            let quote = defaults.string(forKey: currentMotivationQuoteKey) ?? "愿你今天也保持专注。"
            let author = defaults.string(forKey: currentMotivationAuthorKey)
            defaults.set([
                "kind": "motivation",
                "quote": quote,
                "author": author ?? ""
            ], forKey: widgetDisplaySnapshotKey)
        } else {
            defaults.set(["kind": "empty"], forKey: widgetDisplaySnapshotKey)
        }
    }

    private func persistWidgetSnapshot(state: FocusAttributes.ContentState, defaults: UserDefaults? = nil) {
        guard let widgetDefaults = defaults ?? UserDefaults(suiteName: appGroupID) else { return }

        let taskDictionaries = state.incompleteTasks.map { task in
            var dictionary: [String: Any] = [
                "id": task.id,
                "title": task.title,
                "isCompleted": task.isCompleted,
                "isReminder": task.taskType == .reminder
            ]
            if let dueText = task.formattedDueDate {
                dictionary["dueText"] = dueText
            }
            return dictionary
        }

        widgetDefaults.set([
            "kind": "tasks",
            "groupTitle": state.groupTitle,
            "groupIcon": state.groupIcon,
            "completedCount": state.completedCount,
            "totalCount": state.totalCount,
            "tasks": taskDictionaries
        ], forKey: widgetDisplaySnapshotKey)
    }
}
