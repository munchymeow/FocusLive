//
//  FocusLiveApp.swift
//  FocusLive
//
//  Created by 赵豪伟 on 2026/1/13.
//

import SwiftUI
import SwiftData

/// App Group 标识符
private let appGroupID = "group.zhaohaowei.FocusLive"

@main
struct FocusLiveApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            TaskGroup.self,
            TaskItem.self,
        ])
        
        // 使用 App Group 共享容器，确保快捷指令和主应用访问同一个数据库
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            fatalError("无法访问 App Group 容器")
        }
        
        let storeURL = containerURL.appendingPathComponent("FocusLive.store")
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            url: storeURL,
            allowsSave: true
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    handleURL(url)
                }
        }
        .modelContainer(sharedModelContainer)
    }
    
    /// 处理 URL Scheme
    private func handleURL(_ url: URL) {
        print("═══════════════════════════════════════════")
        print("🔗 [FocusLiveApp] 收到 URL: \(url.absoluteString)")
        print("═══════════════════════════════════════════")
        
        guard url.scheme == "focuslive" else { 
            print("   ⚠️ 不是 focuslive scheme，忽略")
            return 
        }
        
        let host = url.host ?? ""
        print("   📌 host: \(host)")
        
        switch host {
        case "toggle":
            // 切换任务完成状态
            handleToggleTask(url: url)
            
        case "sync", "start", "activate":
            // 触发同步 Live Activity
            Task { @MainActor in
                let context = sharedModelContainer.mainContext
                let descriptor = FetchDescriptor<TaskGroup>()
                if let groups = try? context.fetch(descriptor) {
                    ActivityManager.shared.syncActivities(groups: groups)
                }
            }
            
        case "end", "stop":
            // 结束所有 Live Activity
            Task { @MainActor in
                ActivityManager.shared.endAllActivities()
            }
            
        default:
            print("   ⚠️ 未知的 host: \(host)")
            break
        }
    }
    
    /// 处理切换任务状态的 URL
    private func handleToggleTask(url: URL) {
        print("🔄 [handleToggleTask] 开始处理...")
        
        // 解析 URL 参数
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            print("   ⚠️ 无法解析 URL 参数")
            return
        }
        
        var groupID: String?
        var taskID: String?
        
        for item in queryItems {
            switch item.name {
            case "groupID":
                groupID = item.value
            case "taskID":
                taskID = item.value
            default:
                break
            }
        }
        
        guard let groupID = groupID, let taskID = taskID else {
            print("   ⚠️ 缺少 groupID 或 taskID")
            return
        }
        
        print("   📌 groupID: \(groupID)")
        print("   📌 taskID: \(taskID)")
        
        // 在数据库中查找并更新任务
        Task { @MainActor in
            let context = sharedModelContainer.mainContext
            
            // 查找任务
            guard let taskUUID = UUID(uuidString: taskID) else {
                print("   ⚠️ 无效的 taskID")
                return
            }
            
            let descriptor = FetchDescriptor<TaskItem>(
                predicate: #Predicate<TaskItem> { $0.id == taskUUID }
            )
            
            do {
                let tasks = try context.fetch(descriptor)
                if let task = tasks.first {
                    // 切换任务状态
                    task.isCompleted.toggle()
                    try context.save()
                    print("   ✅ 任务 '\(task.title)' 状态已切换为: \(task.isCompleted)")
                    
                    // 同步 Live Activity
                    let groupDescriptor = FetchDescriptor<TaskGroup>()
                    if let groups = try? context.fetch(groupDescriptor) {
                        ActivityManager.shared.syncActivities(groups: groups)
                    }
                } else {
                    print("   ⚠️ 未找到任务")
                }
            } catch {
                print("   ⚠️ 查询/保存失败: \(error)")
            }
        }
    }
}
