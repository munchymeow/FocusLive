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
private let notificationCompleteActionID = "COMPLETE_TASK"
private let notificationIDPrefix = "FocusLive.SmartReminder."

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
        cancelAllSmartReminders()

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
                    id: notificationIDPrefix + task.id.uuidString,
                    groupID: group.id.uuidString,
                    taskID: task.id.uuidString,
                    title: "即将开始：\(group.title)",
                    body: "\(task.title)  ·  还有 2 小时",
                    fireDate: fireDate
                )
            }
        }
    }

    /// 取消所有智能提醒通知
    func cancelAllSmartReminders() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let ids = requests
                .filter { $0.identifier.hasPrefix(notificationIDPrefix) }
                .map { $0.identifier }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    // MARK: - 内部工具

    private func registerNotificationActions(center: UNUserNotificationCenter) {
        let completeAction = UNNotificationAction(
            identifier: notificationCompleteActionID,
            title: "完成",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: notificationCategoryID,
            actions: [completeAction],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([category])
    }

    private func scheduleNotification(
        id: String,
        groupID: String,
        taskID: String,
        title: String,
        body: String,
        fireDate: Date
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = notificationCategoryID
        content.userInfo = [
            "groupID": groupID,
            "taskID": taskID
        ]

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                debugLog("⚠️ 调度通知失败 [\(id)]: \(error.localizedDescription)")
            }
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
