//
//  ShortcutsIntents.swift
//  FocusLive
//
//  Created by 赵豪伟 on 2026/1/13.
//

import AppIntents
import SwiftData
import Foundation
import WidgetKit
import os.log


/// 统一日志记录器（可在 Xcode Console 和 Mac Console.app 中查看）
private let logger = Logger(subsystem: "com.zhaohaowei.FocusLive", category: "Shortcuts")

// MARK: - ModelContainer 单例管理器
final class SharedModelContainer {
    static let shared = SharedModelContainer()
    
    private var _container: ModelContainer?
    private let lock = NSLock()
    
    private init() {
        logger.info("🏗️ SharedModelContainer 单例初始化")
    }
    
    @MainActor
    var container: ModelContainer {
        get throws {
            lock.lock()
            defer { lock.unlock() }
            
            if let existing = _container {
                logger.debug("📦 返回已存在的 ModelContainer")
                return existing
            }
            
            logger.info("📦 创建新的 ModelContainer...")
            
            let schema = Schema([TaskGroup.self, TaskItem.self])
            
            guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
                logger.error("❌ App Group 未配置: \(appGroupID)")
                throw ShortcutError.appGroupNotConfigured
            }
            
            let storeURL = containerURL.appendingPathComponent("FocusLive.store")
            logger.info("📍 数据库路径: \(storeURL.path)")
            
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                url: storeURL,
                allowsSave: true
            )
            
            let newContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
            _container = newContainer
            logger.info("✅ ModelContainer 创建成功")
            return newContainer
        }
    }
}

// MARK: - 错误类型
enum ShortcutError: Error, LocalizedError {
    case appGroupNotConfigured
    case groupNotFound
    case emptyGroupName
    case emptyTaskTitle
    case noGroupSelected
    
    var errorDescription: String? {
        switch self {
        case .appGroupNotConfigured:
            return "App Group 未正确配置"
        case .groupNotFound:
            return "找不到指定的分组"
        case .emptyGroupName:
            return "分组名称不能为空"
        case .emptyTaskTitle:
            return "任务标题不能为空"
        case .noGroupSelected:
            return "请选择一个分组"
        }
    }
}

// MARK: - 分组实体
struct GroupEntity: AppEntity, Identifiable {
    var id: String
    var name: String
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation = TypeDisplayRepresentation(
        name: "任务分组",
        numericFormat: "\(placeholder: .int) 个分组"
    )
    
    static var defaultQuery = GroupEntityQuery()
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
    
    init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

struct GroupEntityQuery: EntityQuery {
    
    @MainActor
    func entities(for identifiers: [String]) async throws -> [GroupEntity] {
        logger.info("🔍 entities(for:) 调用，IDs: \(identifiers)")
        
        let container = try SharedModelContainer.shared.container
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<TaskGroup>()
        let groups = try context.fetch(descriptor)
        
        let result = groups
            .filter { identifiers.contains($0.id.uuidString) }
            .map { GroupEntity(id: $0.id.uuidString, name: "\($0.iconName) \($0.title)") }
        
        logger.info("🔍 entities(for:) 返回 \(result.count) 个实体")
        return result
    }
    
    @MainActor
    func suggestedEntities() async throws -> [GroupEntity] {
        logger.info("📋 suggestedEntities() 被调用")
        
        let container = try SharedModelContainer.shared.container
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<TaskGroup>(sortBy: [SortDescriptor(\.sortOrder)])
        let groups = try context.fetch(descriptor)
        
        logger.info("📋 从数据库获取到 \(groups.count) 个分组")
        
        let result = groups.map { group in
            let entity = GroupEntity(id: group.id.uuidString, name: "\(group.iconName) \(group.title)")
            logger.debug("   ✓ \(entity.name)")
            return entity
        }
        
        return result
    }
}

// MARK: - 快捷指令 1: 在已有分组添加任务
struct AddTaskToExistingGroupIntent: AppIntent {
    static var title: LocalizedStringResource = "添加任务到分组"
    static var description = IntentDescription("在已有分组中添加新任务")
    static var openAppWhenRun: Bool = false
    
    // 🔑 非可选类型，系统会自动在 perform() 之前收集
    @Parameter(title: "分组")
    var group: GroupEntity
    
    @Parameter(title: "任务标题")
    var taskTitle: String
    
    @Parameter(title: "截止时间")
    var dueDate: Date?
    
    static var parameterSummary: some ParameterSummary {
        Summary("在「\(\.$group)」添加「\(\.$taskTitle)」") {
            \.$dueDate
        }
    }
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        logger.info("🚀 AddTaskToExistingGroupIntent 开始执行")
        logger.info("   分组: \(self.group.name)")
        logger.info("   任务: \(self.taskTitle)")
        
        guard !taskTitle.trimmingCharacters(in: .whitespaces).isEmpty else {
            return .result(dialog: "❌ 请输入任务标题")
        }
        
        let container = try SharedModelContainer.shared.container
        let context = ModelContext(container)
        
        let descriptor = FetchDescriptor<TaskGroup>()
        let groups = try context.fetch(descriptor)
        
        guard let targetGroup = groups.first(where: { $0.id.uuidString == group.id }) else {
            logger.error("❌ 找不到分组: \(self.group.id)")
            return .result(dialog: "❌ 找不到分组「\(group.name)」")
        }
        
        let maxTaskOrder = targetGroup.tasks.compactMap { $0.sortOrder }.max() ?? -1
        let task = TaskItem(
            title: taskTitle,
            isCompleted: false,
            dueDate: dueDate,
            sortOrder: maxTaskOrder + 1
        )
        
        task.taskGroup = targetGroup
        targetGroup.tasks.append(task)
        
        try context.save()
        notifyAppAndWidgets()
        
        var message = "✅ 已在「\(targetGroup.iconName) \(targetGroup.title)」添加任务「\(taskTitle)」"
        if let dueDate = dueDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            message += "\n⏰ \(formatter.string(from: dueDate))"
        }
        
        logger.info("🎉 任务创建成功")
        return .result(dialog: "\(message)")
    }
}

// MARK: - 快捷指令 2: 创建新分组并添加任务
struct CreateGroupAndAddTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "创建分组并添加任务"
    static var description = IntentDescription("创建新分组并添加第一个任务")
    static var openAppWhenRun: Bool = false
    
    @Parameter(title: "分组名称")
    var groupName: String
    
    @Parameter(title: "分组图标", default: "folder.fill")
    var groupIcon: String
    
    @Parameter(title: "任务标题")
    var taskTitle: String
    
    @Parameter(title: "截止时间")
    var dueDate: Date?
    
    static var parameterSummary: some ParameterSummary {
        Summary("创建「\(\.$groupName)」并添加「\(\.$taskTitle)」") {
            \.$groupIcon
            \.$dueDate
        }
    }
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        logger.info("🚀 CreateGroupAndAddTaskIntent 开始执行")
        logger.info("   新分组: \(self.groupIcon) \(self.groupName)")
        logger.info("   任务: \(self.taskTitle)")
        
        guard !groupName.trimmingCharacters(in: .whitespaces).isEmpty else {
            return .result(dialog: "❌ 请输入分组名称")
        }
        guard !taskTitle.trimmingCharacters(in: .whitespaces).isEmpty else {
            return .result(dialog: "❌ 请输入任务标题")
        }
        
        let container = try SharedModelContainer.shared.container
        let context = ModelContext(container)
        
        let descriptor = FetchDescriptor<TaskGroup>()
        let groups = try context.fetch(descriptor)
        let maxOrder = groups.compactMap { $0.sortOrder }.max() ?? -1
        
        let icon = groupIcon.isEmpty ? "folder.fill" : groupIcon
        let newGroup = TaskGroup(
            title: groupName,
            iconName: icon,
            sortOrder: maxOrder + 1,
            tasks: []
        )
        context.insert(newGroup)
        
        let task = TaskItem(
            title: taskTitle,
            isCompleted: false,
            dueDate: dueDate,
            sortOrder: 0
        )
        
        task.taskGroup = newGroup
        newGroup.tasks.append(task)
        
        try context.save()
        notifyAppAndWidgets()
        
        var message = "✅ 已创建「\(icon) \(groupName)」并添加任务「\(taskTitle)」"
        if let dueDate = dueDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            message += "\n⏰ \(formatter.string(from: dueDate))"
        }
        
        logger.info("🎉 分组和任务创建成功")
        return .result(dialog: "\(message)")
    }
}

// MARK: - 辅助函数
private func notifyAppAndWidgets() {
    logger.info("📡 通知 App 和 Widget 刷新")
    
    if let defaults = UserDefaults(suiteName: appGroupID) {
        defaults.set(Date().timeIntervalSince1970, forKey: "lastIntentUpdate")
    }
    
    WidgetCenter.shared.reloadAllTimelines()
}

// MARK: - App Shortcuts Provider
struct FocusLiveShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddTaskToExistingGroupIntent(),
            phrases: [
                "添加 \(.applicationName) 任务",
                "在 \(.applicationName) 添加任务"
            ],
            shortTitle: "添加任务",
            systemImageName: "plus.circle.fill"
        )
        
        AppShortcut(
            intent: CreateGroupAndAddTaskIntent(),
            phrases: [
                "创建 \(.applicationName) 分组",
                "新建 \(.applicationName) 分组"
            ],
            shortTitle: "创建分组",
            systemImageName: "folder.badge.plus"
        )
    }
}
