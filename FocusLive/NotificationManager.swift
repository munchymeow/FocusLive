//
//  NotificationManager.swift
//  FocusLive
//
//  智能提醒：基于 UNUserNotificationCenter，在任务计划时间前 2 小时发送本地通知
//

import Foundation
import UserNotifications

private let notificationCategoryID = "TASK_REMINDER"
private let notificationIDPrefix = "FocusLive.SmartReminder."

/// 本地通知管理器（单例）
@MainActor
final class NotificationManager {
    static let shared = NotificationManager()

    private init() {}

    // MARK: - 权限

    /// 请求通知权限，返回是否已授权
    @discardableResult
    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional:
            return true
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .sound, .badge])
            } catch {
                print("⚠️ 请求通知权限失败: \(error)")
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
                    title: "📌 即将开始：\(group.title)",
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

    private func scheduleNotification(id: String, title: String, body: String, fireDate: Date) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = notificationCategoryID

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("⚠️ 调度通知失败 [\(id)]: \(error.localizedDescription)")
            }
        }
    }
}
