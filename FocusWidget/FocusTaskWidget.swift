//
//  FocusTaskWidget.swift
//  FocusWidget
//
//  Main screen task widget — reads real task data from App Group SwiftData store.
//  Supports small / medium / large families.
//

import WidgetKit
import AppIntents
import SwiftUI
import SwiftData

// MARK: - Task Widget Data

/// Lightweight display model for a single task inside the widget.
struct WidgetTask: Hashable, Identifiable {
    let id: String
    let title: String
    let isCompleted: Bool
    let taskType: TaskType?
}

/// Lightweight display model for a task group inside the widget.
struct WidgetGroup: Hashable, Identifiable {
    let id: String
    let title: String
    let iconName: String
    let tasks: [WidgetTask]

    var incompleteCount: Int { tasks.filter { !$0.isCompleted }.count }
    var completedCount: Int { tasks.filter { $0.isCompleted }.count }
    var totalCount: Int { tasks.count }

    var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }
}

/// Timeline entry for the task widget.
struct TaskWidgetEntry: TimelineEntry {
    let date: Date
    let groups: [WidgetGroup]
}

// MARK: - Data Fetching

/// 判断字符串是否为 SF Symbol 名
private func fetchWidgetGroups() -> [WidgetGroup] {
    guard let containerURL = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: appGroupID
    ) else { return [] }

    let storeURL = containerURL.appendingPathComponent("FocusLive.store")
    let schema = Schema([TaskGroup.self, TaskItem.self])
    let config = ModelConfiguration(schema: schema, url: storeURL, allowsSave: false)

    guard let container = try? ModelContainer(for: schema, configurations: [config]) else {
        return []
    }

    let context = ModelContext(container)
    context.autosaveEnabled = false

    let descriptor = FetchDescriptor<TaskGroup>(
        sortBy: [SortDescriptor(\.sortOrder, order: .forward)]
    )

    guard let groups = try? context.fetch(descriptor) else { return [] }

    // Filter: non-private groups that have at least one incomplete non-private task
    var result: [WidgetGroup] = []
    for group in groups where !(group.isPrivate ?? false) {
        let publicTasks = group.sortedTasks.filter { !($0.isPrivate ?? false) }
        guard !publicTasks.isEmpty else { continue }

        let incompletePublic = publicTasks.filter { !$0.isCompleted }
        // Show groups that still have incomplete tasks
        guard !incompletePublic.isEmpty else { continue }

        let widgetTasks = publicTasks.prefix(8).map { task in
            WidgetTask(
                id: task.id.uuidString,
                title: task.title,
                isCompleted: task.isCompleted,
                taskType: task.taskType
            )
        }

        result.append(WidgetGroup(
            id: group.id.uuidString,
            title: group.title,
            iconName: group.iconName,
            tasks: Array(widgetTasks)
        ))
    }

    return result
}

// MARK: - Provider

struct TaskWidgetProvider: AppIntentTimelineProvider {
    typealias Intent = TaskWidgetConfigurationIntent

    func placeholder(in context: Context) -> TaskWidgetEntry {
        TaskWidgetEntry(date: Date(), groups: [
            WidgetGroup(id: "preview", title: "示例分组", iconName: "doc.text.fill", tasks: [
                WidgetTask(id: "1", title: "任务一", isCompleted: false, taskType: .todo),
                WidgetTask(id: "2", title: "任务二", isCompleted: true, taskType: .todo),
                WidgetTask(id: "3", title: "任务三", isCompleted: false, taskType: .todo),
            ])
        ])
    }

    func snapshot(for configuration: TaskWidgetConfigurationIntent, in context: Context) async -> TaskWidgetEntry {
        let groups = fetchWidgetGroups()
        if groups.isEmpty { return placeholder(in: context) }
        return TaskWidgetEntry(date: Date(), groups: groups)
    }

    func timeline(for configuration: TaskWidgetConfigurationIntent, in context: Context) async -> Timeline<TaskWidgetEntry> {
        let groups = fetchWidgetGroups()
        let entry = TaskWidgetEntry(date: Date(), groups: groups.isEmpty ? placeholder(in: context).groups : groups)

        // Refresh every 30 minutes to keep data reasonably fresh
        let nextUpdate = Date().addingTimeInterval(30 * 60)
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }
}

// MARK: - Configuration Intent

struct TaskWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "任务小组件" }
    static var description: IntentDescription { "在主屏幕显示待办任务列表。" }
}

// MARK: - Widget Entry View

struct TaskWidgetEntryView: View {
    var entry: TaskWidgetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        case .systemLarge:
            largeView
        default:
            smallView
        }
    }

    // MARK: - Small Widget

    private var smallView: some View {
        Group {
            if let group = entry.groups.first {
                smallGroupView(group)
            } else {
                emptyView
            }
        }
    }

    private func smallGroupView(_ group: WidgetGroup) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 8) {
                GroupIcon(name: group.iconName, size: 14, tint: Color.accentColor, showsChrome: false)
                Text(group.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                Text("\(group.completedCount)/\(group.totalCount)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText(countsDown: false))
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 5)
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: max(0, geo.size.width * group.progress), height: 5)
                }
            }
            .frame(height: 5)

            // Task list (up to 4)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(group.tasks.prefix(4)) { task in
                    taskRow(task, compact: true)
                }
            }

            if group.incompleteCount > 4 {
                Text("+\(group.incompleteCount - 4) 更多")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
    }

    // MARK: - Medium Widget

    private var mediumView: some View {
        Group {
            if entry.groups.isEmpty {
                emptyView
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    // Header
                    HStack(spacing: 6) {
                        Image(systemName: "checklist")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                        Text("FocusScreen")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(totalProgressText)
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    // Groups
                    ForEach(entry.groups.prefix(2)) { group in
                        groupSection(group, maxTasks: 3)
                    }

                    if entry.groups.count > 2 {
                        Text("+\(entry.groups.count - 2) 个分组")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)
                }
                .padding(14)
            }
        }
    }

    // MARK: - Large Widget

    private var largeView: some View {
        Group {
            if entry.groups.isEmpty {
                emptyView
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    // Header
                    HStack(spacing: 6) {
                        Image(systemName: "checklist")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                        Text("FocusScreen 任务")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(totalProgressText)
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    // Groups
                    ForEach(entry.groups.prefix(4)) { group in
                        groupSection(group, maxTasks: 6)

                        if group.id != entry.groups.prefix(4).last?.id {
                            Divider()
                        }
                    }

                    Spacer(minLength: 0)
                }
                .padding(16)
            }
        }
    }

    // MARK: - Shared Components

    private func groupSection(_ group: WidgetGroup, maxTasks: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                GroupIcon(name: group.iconName, size: 11, tint: Color.accentColor, showsChrome: false)
                Text(group.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                Text("\(group.completedCount)/\(group.totalCount)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText(countsDown: false))
            }

            ForEach(group.tasks.prefix(maxTasks)) { task in
                taskRow(task, compact: false)
            }

            let remaining = group.incompleteCount - maxTasks
            if remaining > 0 {
                Text("+\(remaining) 更多待办")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 20)
            }
        }
    }

    private func taskRow(_ task: WidgetTask, compact: Bool) -> some View {
        HStack(spacing: compact ? 6 : 8) {
            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: compact ? 12 : 14))
                .foregroundStyle(task.isCompleted ? Color.green : Color.secondary)

            Text(task.title)
                .font(compact ? .caption2 : .caption)
                .lineLimit(1)
                .strikethrough(task.isCompleted)
                .foregroundStyle(task.isCompleted ? Color.secondary : Color.primary)
        }
    }

    private var emptyView: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 32))
                .foregroundStyle(Color.green)
            Text("全部完成")
                .font(.subheadline.weight(.medium))
            Text("所有任务都已完成！")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var totalProgressText: String {
        let totalTasks = entry.groups.reduce(0) { $0 + $1.totalCount }
        let completedTasks = entry.groups.reduce(0) { $0 + $1.completedCount }
        return "\(completedTasks)/\(totalTasks)"
    }
}

// MARK: - Widget Declaration

struct FocusTaskWidget: Widget {
    let kind: String = "FocusTaskWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: TaskWidgetConfigurationIntent.self,
            provider: TaskWidgetProvider()
        ) { entry in
            TaskWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("FocusScreen 任务")
        .description("在主屏幕查看待办任务列表。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    FocusTaskWidget()
} timeline: {
    TaskWidgetEntry(date: .now, groups: [
        WidgetGroup(id: "1", title: "晚自修", iconName: "moon.stars.fill", tasks: [
            WidgetTask(id: "1", title: "复习数学", isCompleted: false, taskType: .todo),
            WidgetTask(id: "2", title: "写英语作业", isCompleted: true, taskType: .todo),
            WidgetTask(id: "3", title: "物理练习题", isCompleted: false, taskType: .todo),
        ])
    ])
}

#Preview("Medium", as: .systemMedium) {
    FocusTaskWidget()
} timeline: {
    TaskWidgetEntry(date: .now, groups: [
        WidgetGroup(id: "1", title: "晚自修", iconName: "moon.stars.fill", tasks: [
            WidgetTask(id: "1", title: "复习数学", isCompleted: false, taskType: .todo),
            WidgetTask(id: "2", title: "写英语作业", isCompleted: true, taskType: .todo),
            WidgetTask(id: "3", title: "物理练习题", isCompleted: false, taskType: .todo),
        ]),
        WidgetGroup(id: "2", title: "运动计划", iconName: "figure.run", tasks: [
            WidgetTask(id: "4", title: "跑步30分钟", isCompleted: false, taskType: .dailyCheckIn),
            WidgetTask(id: "5", title: "拉伸10分钟", isCompleted: true, taskType: .dailyCheckIn),
        ])
    ])
}

#Preview("Large", as: .systemLarge) {
    FocusTaskWidget()
} timeline: {
    TaskWidgetEntry(date: .now, groups: [
        WidgetGroup(id: "1", title: "晚自修", iconName: "moon.stars.fill", tasks: [
            WidgetTask(id: "1", title: "复习数学", isCompleted: false, taskType: .todo),
            WidgetTask(id: "2", title: "写英语作业", isCompleted: true, taskType: .todo),
            WidgetTask(id: "3", title: "物理练习题", isCompleted: false, taskType: .todo),
            WidgetTask(id: "6", title: "预习化学", isCompleted: false, taskType: .todo),
        ]),
        WidgetGroup(id: "2", title: "运动计划", iconName: "figure.run", tasks: [
            WidgetTask(id: "4", title: "跑步30分钟", isCompleted: false, taskType: .dailyCheckIn),
            WidgetTask(id: "5", title: "拉伸10分钟", isCompleted: true, taskType: .dailyCheckIn),
        ]),
        WidgetGroup(id: "3", title: "购物清单", iconName: "cart.fill", tasks: [
            WidgetTask(id: "7", title: "牛奶", isCompleted: false, taskType: .todo),
            WidgetTask(id: "8", title: "面包", isCompleted: true, taskType: .todo),
        ])
    ])
}
