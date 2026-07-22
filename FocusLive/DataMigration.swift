//
//  DataMigration.swift
//  FocusLive
//
//  SwiftData VersionedSchema + MigrationPlan for safe schema evolution.
//
//  Current version: V1 (initial schema with all fields added through P0–M2 iterations).
//  To add a new migration:
//    1. Create SchemaV2 as a new VersionedSchema.
//    2. Add it to FocusLiveMigrationPlan.versions.
//    3. Define a lightweight or custom migration step in FocusLiveMigrationPlan.
//    4. Update the ModelContainer creation in FocusLiveApp.swift to use FocusLiveMigrationPlan.
//

import Foundation
import SwiftData

// MARK: - Schema V1 (current production schema)

enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [TaskGroupV1.self, TaskItemV1.self]
    }

    @Model
    final class TaskGroupV1 {
        var id: UUID
        var title: String
        var iconName: String
        var isPrivate: Bool?
        var sortOrder: Int?
        @Relationship(deleteRule: .cascade) var tasks: [TaskItemV1]
        var scheduledTime: Date?
        var reminderTime: Date?
        var reminderType: ReminderType?
        var priority: Priority?

        init(
            id: UUID = UUID(),
            title: String,
            iconName: String,
            isPrivate: Bool = false,
            sortOrder: Int? = 0,
            tasks: [TaskItemV1] = [],
            scheduledTime: Date? = nil,
            reminderTime: Date? = nil,
            reminderType: ReminderType? = ReminderType.none,
            priority: Priority? = .medium
        ) {
            self.id = id
            self.title = title
            self.iconName = iconName
            self.isPrivate = isPrivate
            self.sortOrder = sortOrder
            self.tasks = tasks
            self.scheduledTime = scheduledTime
            self.reminderTime = reminderTime
            self.reminderType = reminderType
            self.priority = priority
        }
    }

    @Model
    final class TaskItemV1 {
        var id: UUID
        var title: String
        var isCompleted: Bool
        var isPrivate: Bool?
        var taskType: TaskType?
        var dueDate: Date?
        var sortOrder: Int?
        var taskGroup: TaskGroupV1?
        var scheduledTime: Date?
        var repeatType: RepeatType?
        var repeatInterval: Int?
        var reminderTime: Date?
        var reminderType: ReminderType?
        var priority: Priority?
        var attachments: [Attachment]?

        init(
            id: UUID = UUID(),
            title: String,
            isCompleted: Bool = false,
            isPrivate: Bool = false,
            taskType: TaskType = .todo,
            dueDate: Date? = nil,
            sortOrder: Int? = 0,
            scheduledTime: Date? = nil,
            repeatType: RepeatType? = RepeatType.none,
            repeatInterval: Int? = 1,
            reminderTime: Date? = nil,
            reminderType: ReminderType? = ReminderType.none,
            priority: Priority? = .medium,
            attachments: [Attachment]? = nil
        ) {
            self.id = id
            self.title = title
            self.isCompleted = isCompleted
            self.isPrivate = isPrivate
            self.taskType = taskType
            self.dueDate = dueDate
            self.sortOrder = sortOrder
            self.scheduledTime = scheduledTime
            self.repeatType = repeatType
            self.repeatInterval = repeatInterval
            self.reminderTime = reminderTime
            self.reminderType = reminderType
            self.priority = priority
            self.attachments = attachments
        }
    }
}

// MARK: - Migration Plan

enum FocusLiveMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self]
    }

    static var stages: [MigrationStage] {
        // No migrations needed yet — V1 is the initial schema.
        // When adding V2, insert a lightweight or custom migration stage here.
        []
    }
}
