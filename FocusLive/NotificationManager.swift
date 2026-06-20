//
//  NotificationManager.swift
//  FocusLive
//
//  智能提醒：基于 UNUserNotificationCenter，在任务计划时间前 2 小时发送本地通知
//

import Foundation
import UserNotifications
import SwiftData
import WidgetKit
import os

private let notificationCategoryID = "TASK_REMINDER"
private let reminderNotificationCategoryID = "TASK_REMINDER_REMINDER_ONLY"
private let notificationCompleteActionID = "COMPLETE_TASK"
private let smartReminderIDPrefix = "FocusLive.SmartReminder."
private let reminderNotificationIDPrefix = "FocusLive.Reminder."

/// 本地通知管理器（单例）
@MainActor
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private override init() {
        super.init()
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        registerNotificationActions(center: center)
    }

    // MARK: - 权限

    /// 请求通知权限，返回是否已授权
    @discardableResult
    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        registerNotificationActions(center: center)
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional:
            return true
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .sound, .badge])
            } catch {
                debugLog("⚠️ 请求通知权限失败: \(error)")
                return false
            }
        default:
            return false
        }
    }

    // MARK: - 调度 / 取消

    /// 根据当前所有分组重新调度智能提醒通知（先全部取消再重新调度）
    func rescheduleSmartReminders(groups: [TaskGroup]) {
        cancelNotifications(withPrefix: smartReminderIDPrefix)

        let now = Date()
        for group in groups {
            for task in group.tasks {
                guard
                    !task.isCompleted,
                    let scheduledTime = task.scheduledTime ?? task.dueDate,
                    scheduledTime > now
                else { continue }

                let fireDate = scheduledTime.addingTimeInterval(-2 * 3600)
                guard fireDate > now else { continue }

                scheduleNotification(
                    id: smartReminderIDPrefix + task.id.uuidString,
                    groupID: group.id.uuidString,
                    taskID: task.id.uuidString,
                    title: "即将开始：\(group.title)",
                    body: "\(task.title)  ·  还有 2 小时",
                    fireDate: fireDate,
                    repeats: false
                )
            }
        }
    }

    /// 取消所有智能提醒通知
    func cancelAllSmartReminders() {
        cancelNotifications(withPrefix: smartReminderIDPrefix)
    }

    // MARK: - 提醒事项准时通知

    /// 根据所有提醒事项分组的任务，按 reminderType 调度准时通知
    func rescheduleReminderNotifications(groups: [TaskGroup]) {
        cancelNotifications(withPrefix: reminderNotificationIDPrefix)

        let now = Date()
        for group in groups {
            for task in group.tasks {
                guard
                    task.taskType == .reminder,
                    !task.isCompleted,
                    let scheduledTime = task.scheduledTime ?? task.dueDate,
                    let reminderType = task.reminderType,
                    reminderType != .none
                else { continue }

                let fireDate = calculateFireDate(scheduledTime: scheduledTime, reminderType: reminderType)
                guard fireDate > now else { continue }

                let isRepeating = task.repeatType != nil && task.repeatType != .none
                let triggerDateComponents = calendarComponents(
                    for: fireDate,
                    repeating: isRepeating,
                    repeatType: task.repeatType
                )
                let repeats = isRepeating && triggerDateComponents != nil

                let id = reminderNotificationIDPrefix + task.id.uuidString
                scheduleNotification(
                    id: id,
                    groupID: group.id.uuidString,
                    taskID: task.id.uuidString,
                    title: task.title,
                    body: reminderBody(scheduledTime: scheduledTime, reminderType: reminderType),
                    fireDate: fireDate,
                    repeats: repeats,
                    dateComponents: triggerDateComponents,
                    categoryID: reminderNotificationCategoryID
                )
            }
        }
    }

    // MARK: - 提醒事项辅助

    /// 根据 scheduledTime 和 reminderType 计算实际触发时间
    private func calculateFireDate(scheduledTime: Date, reminderType: ReminderType) -> Date {
        let cal = Calendar.current
        switch reminderType {
        case .atTime:
            return scheduledTime
        case .before10min:
            return cal.date(byAdding: .minute, value: -10, to: scheduledTime) ?? scheduledTime
        case .before30min:
            return cal.date(byAdding: .minute, value: -30, to: scheduledTime) ?? scheduledTime
        case .before1hour:
            return cal.date(byAdding: .hour, value: -1, to: scheduledTime) ?? scheduledTime
        case .before6hours:
            return cal.date(byAdding: .hour, value: -6, to: scheduledTime) ?? scheduledTime
        case .before1day:
            return cal.date(byAdding: .day, value: -1, to: scheduledTime) ?? scheduledTime
        case .before1week:
            return cal.date(byAdding: .day, value: -7, to: scheduledTime) ?? scheduledTime
        case .none:
            return scheduledTime
        }
    }

    /// 通知正文：显示时间信息
    private func reminderBody(scheduledTime: Date, reminderType: ReminderType) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let timeString = formatter.string(from: scheduledTime)
        switch reminderType {
        case .atTime:
            return "计划时间 \(timeString)"
        case .before10min:
            return "还有 10 分钟（\(timeString)）"
        case .before30min:
            return "还有 30 分钟（\(timeString)）"
        case .before1hour:
            return "还有 1 小时（\(timeString)）"
        case .before6hours:
            return "还有 6 小时（\(timeString)）"
        case .before1day:
            return "还有 1 天（\(timeString)）"
        case .before1week:
            return "还有 1 周（\(timeString)）"
        case .none:
            return ""
        }
    }

    /// 根据重复类型返回用于 repeating trigger 的 dateComponents（仅提取时间/星期/日等）
    private func calendarComponents(
        for date: Date,
        repeating: Bool,
        repeatType: RepeatType?
    ) -> DateComponents? {
        guard repeating, let repeatType else { return nil }
        let cal = Calendar.current
        switch repeatType {
        case .daily:
            return cal.dateComponents([.hour, .minute], from: date)
        case .weekly:
            return cal.dateComponents([.weekday, .hour, .minute], from: date)
        case .monthly:
            return cal.dateComponents([.day, .hour, .minute], from: date)
        case .yearly:
            return cal.dateComponents([.month, .day, .hour, .minute], from: date)
        case .none:
            return nil
        }
    }

    // MARK: - 内部工具

    private func registerNotificationActions(center: UNUserNotificationCenter) {
        let completeAction = UNNotificationAction(
            identifier: notificationCompleteActionID,
            title: "完成",
            options: []
        )
        let taskCategory = UNNotificationCategory(
            identifier: notificationCategoryID,
            actions: [completeAction],
            intentIdentifiers: [],
            options: []
        )
        // 提醒事项不显示「完成」按钮（提醒事项不需要完成）
        let reminderCategory = UNNotificationCategory(
            identifier: reminderNotificationCategoryID,
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([taskCategory, reminderCategory])
    }

    private func scheduleNotification(
        id: String,
        groupID: String,
        taskID: String,
        title: String,
        body: String,
        fireDate: Date,
        repeats: Bool = false,
        dateComponents: DateComponents? = nil,
        categoryID: String = notificationCategoryID
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = categoryID
        content.userInfo = [
            "groupID": groupID,
            "taskID": taskID
        ]

        let components = dateComponents ?? Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: repeats)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                debugLog("⚠️ 调度通知失败 [\(id)]: \(error.localizedDescription)")
            }
        }
    }

    /// 取消指定前缀的所有待调度通知
    private func cancelNotifications(withPrefix prefix: String) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let ids = requests
                .filter { $0.identifier.hasPrefix(prefix) }
                .map { $0.identifier }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard response.actionIdentifier == "COMPLETE_TASK" else { return }
        let userInfo = response.notification.request.content.userInfo
        await completeTaskFromNotification(userInfo: userInfo)
    }

    @MainActor
    private func completeTaskFromNotification(userInfo: [AnyHashable: Any]) {
        guard let taskID = userInfo["taskID"] as? String,
              let taskUUID = UUID(uuidString: taskID) else {
            return
        }

        do {
            let context = try makeSharedModelContext()
            let descriptor = FetchDescriptor<TaskItem>(
                predicate: #Predicate<TaskItem> { $0.id == taskUUID }
            )
            guard let task = try context.fetch(descriptor).first,
                  task.taskType != .reminder else {
                return
            }
            task.isCompleted = true
            try context.save()
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            debugLog("⚠️ 通知完成任务失败: \(error.localizedDescription)")
        }
    }

    private func makeSharedModelContext() throws -> ModelContext {
        let schema = Schema([TaskGroup.self, TaskItem.self])
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            throw NotificationPersistenceError.appGroupUnavailable
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
}

private enum NotificationPersistenceError: Error {
    case appGroupUnavailable
}
