//
//  DataExportImport.swift
//  FocusLive
//
//  JSON import/export for task data backup and portability.
//

import Foundation
import SwiftData

// MARK: - Export

/// Serializable container for all task data.
struct FocusLiveExport: Codable {
    let exportDate: Date
    let appVersion: String
    let groups: [ExportGroup]
}

struct ExportGroup: Codable {
    let id: String
    let title: String
    let iconName: String
    let isPrivate: Bool
    let sortOrder: Int
    let scheduledTime: Date?
    let reminderType: ReminderType?
    let priority: Priority?
    let tasks: [ExportTask]
}

struct ExportTask: Codable {
    let id: String
    let title: String
    let isCompleted: Bool
    let isPrivate: Bool
    let taskType: TaskType
    let dueDate: Date?
    let sortOrder: Int
    let scheduledTime: Date?
    let repeatType: RepeatType?
    let repeatInterval: Int?
    let reminderType: ReminderType?
    let priority: Priority?
    let attachments: [Attachment]?
}

/// Export all task groups and tasks to a JSON Data blob.
func exportAllTasks(from context: ModelContext) throws -> Data {
    let descriptor = FetchDescriptor<TaskGroup>(
        sortBy: [SortDescriptor(\.sortOrder, order: .forward)]
    )
    let groups = try context.fetch(descriptor)

    let exportGroups = groups.map { group in
        ExportGroup(
            id: group.id.uuidString,
            title: group.title,
            iconName: group.iconName,
            isPrivate: group.isPrivate ?? false,
            sortOrder: group.sortOrder ?? 0,
            scheduledTime: group.scheduledTime,
            reminderType: group.reminderType,
            priority: group.priority,
            tasks: group.sortedTasks.map { task in
                ExportTask(
                    id: task.id.uuidString,
                    title: task.title,
                    isCompleted: task.isCompleted,
                    isPrivate: task.isPrivate ?? false,
                    taskType: task.taskType ?? .todo,
                    dueDate: task.dueDate,
                    sortOrder: task.sortOrder ?? 0,
                    scheduledTime: task.scheduledTime,
                    repeatType: task.repeatType,
                    repeatInterval: task.repeatInterval,
                    reminderType: task.reminderType,
                    priority: task.priority,
                    attachments: task.attachments
                )
            }
        )
    }

    let export = FocusLiveExport(
        exportDate: Date(),
        appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
        groups: exportGroups
    )

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return try encoder.encode(export)
}

// MARK: - Import

enum ImportError: LocalizedError {
    case decodingFailed(String)
    case duplicateGroup(String)

    var errorDescription: String? {
        switch self {
        case .decodingFailed(let detail):
            return "导入数据格式错误：\(detail)"
        case .duplicateGroup(let title):
            return "分组「\(title)」已存在，跳过导入"
        }
    }
}

/// Import task groups from a JSON Data blob. Skips groups whose IDs already exist.
/// Returns the count of newly imported groups.
@discardableResult
func importTasks(from data: Data, into context: ModelContext, skipDuplicates: Bool = true) throws -> Int {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    let export: FocusLiveExport
    do {
        export = try decoder.decode(FocusLiveExport.self, from: data)
    } catch {
        throw ImportError.decodingFailed(error.localizedDescription)
    }

    // Collect existing group IDs for duplicate check
    let existingDescriptor = FetchDescriptor<TaskGroup>()
    let existingGroups = try context.fetch(existingDescriptor)
    let existingIDs = Set(existingGroups.map { $0.id.uuidString })

    var importedCount = 0

    for exportGroup in export.groups {
        if skipDuplicates, existingIDs.contains(exportGroup.id) {
            continue
        }

        guard let groupUUID = UUID(uuidString: exportGroup.id) else { continue }

        let group = TaskGroup(
            id: groupUUID,
            title: exportGroup.title,
            iconName: exportGroup.iconName,
            isPrivate: exportGroup.isPrivate,
            sortOrder: exportGroup.sortOrder,
            scheduledTime: exportGroup.scheduledTime,
            reminderType: exportGroup.reminderType,
            priority: exportGroup.priority
        )

        for exportTask in exportGroup.tasks {
            guard let taskUUID = UUID(uuidString: exportTask.id) else { continue }
            let task = TaskItem(
                id: taskUUID,
                title: exportTask.title,
                isCompleted: exportTask.isCompleted,
                isPrivate: exportTask.isPrivate,
                taskType: exportTask.taskType,
                dueDate: exportTask.dueDate,
                sortOrder: exportTask.sortOrder,
                scheduledTime: exportTask.scheduledTime,
                repeatType: exportTask.repeatType,
                repeatInterval: exportTask.repeatInterval,
                reminderType: exportTask.reminderType,
                priority: exportTask.priority,
                attachments: exportTask.attachments
            )
            group.tasks.append(task)
        }

        context.insert(group)
        importedCount += 1
    }

    if importedCount > 0 {
        try context.save()
    }

    return importedCount
}
