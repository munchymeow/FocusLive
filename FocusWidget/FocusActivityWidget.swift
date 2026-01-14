//
//  FocusActivityWidget.swift
//  FocusWidget
//
//  Created by 赵豪伟 on 2026/1/13.
//

import SwiftUI
import ActivityKit
import WidgetKit
import AppIntents

/// Live Activity Widget 视图
struct FocusActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusAttributes.self) { context in
            // 锁屏 Live Activity 视图
            LockScreenLiveActivityView(context: context)
        } dynamicIsland: { context in
            // 灵动岛视图
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: context.state.groupIcon)
                            .foregroundStyle(.blue)
                        Text(context.state.groupTitle)
                            .font(.headline)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.completedCount)/\(context.state.totalCount)")
                        .font(.headline.monospacedDigit())
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if let firstTask = context.state.incompleteTasks.first {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("下一个: \(firstTask.title)")
                                .font(.subheadline)
                                .lineLimit(1)
                            
                            Button(intent: ToggleTaskIntent(
                                groupID: context.attributes.groupID,
                                taskID: firstTask.id
                            )) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("完成")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.green)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        Text("✓ 全部完成！")
                            .font(.headline)
                            .foregroundStyle(.green)
                    }
                }
            } compactLeading: {
                // 左侧紧凑视图：显示图标
                Text(context.state.groupIcon)
                    .font(.system(size: 14))
            } compactTrailing: {
                // 右侧紧凑视图：显示进度
                Text("\(context.state.completedCount)/\(context.state.totalCount)")
                    .font(.caption.monospacedDigit())
            } minimal: {
                // 最小化视图：显示剩余任务数（点击展开灵动岛）
                // 注意：minimal 视图不支持 Button 交互，点击会展开灵动岛
                ZStack {
                    Circle()
                        .fill(context.state.remainingCount > 0 ? Color.blue : Color.green)
                    
                    if context.state.remainingCount > 0 {
                        Text("\(context.state.remainingCount)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    } else {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
        }
    }
}

// MARK: - 锁屏 Live Activity 视图
struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<FocusAttributes>
    
    /// 计算进度值（防止除零错误）
    private var progressValue: Double {
        let total = context.state.totalCount
        guard total > 0 else { return 0 }
        return Double(context.state.completedCount) / Double(total)
    }
    
    /// 是否全部完成
    private var isAllCompleted: Bool {
        context.state.remainingCount == 0 && context.state.totalCount > 0
    }
    
    /// 显示的任务数量（最多5项）
    private var displayTaskCount: Int {
        min(context.state.incompleteTasks.count, 5)
    }
    
    /// 根据任务数量计算头部字号
    private var headerIconSize: CGFloat {
        switch displayTaskCount {
        case 0...1: return 22
        case 2: return 20
        case 3: return 18
        default: return 16
        }
    }
    
    private var headerFont: Font {
        switch displayTaskCount {
        case 0...1: return .title3
        case 2: return .headline
        case 3: return .subheadline
        default: return .subheadline
        }
    }
    
    /// 根据任务数量计算任务字号
    private var taskIconSize: CGFloat {
        switch displayTaskCount {
        case 0...1: return 26
        case 2: return 22
        case 3: return 20
        default: return 18
        }
    }
    
    private var taskFont: Font {
        switch displayTaskCount {
        case 0...1: return .title3
        case 2: return .headline
        case 3: return .body
        default: return .subheadline
        }
    }
    
    /// 任务行间距
    private var taskSpacing: CGFloat {
        switch displayTaskCount {
        case 0...1: return 12
        case 2: return 10
        case 3: return 8
        default: return 6
        }
    }
    
    var body: some View {
        // 整体容器 - 始终使用最大尺寸
        VStack(alignment: .leading, spacing: displayTaskCount <= 2 ? 14 : 10) {
            // 头部：左边emoji+标题，右边进度
            HStack(alignment: .center) {
                // 左上：emoji + 分组标题
                HStack(spacing: 6) {
                    Text(context.state.groupIcon)
                        .font(.system(size: headerIconSize))
                    
                    Text(context.state.groupTitle)
                        .font(headerFont)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // 右上：进度数字
                Text(isAllCompleted ? "✓" : "\(context.state.completedCount)/\(context.state.totalCount)")
                    .font(headerFont)
                    .fontWeight(.medium)
                    .foregroundStyle(isAllCompleted ? .green : .secondary)
                    .monospacedDigit()
            }
            .padding(.horizontal, 4)
            
            // 任务列表（最多显示 5 项，超出不提示）
            if !context.state.incompleteTasks.isEmpty {
                VStack(alignment: .leading, spacing: taskSpacing) {
                    ForEach(Array(context.state.incompleteTasks.prefix(5)), id: \.id) { task in
                        TaskRowView(
                            task: task,
                            groupID: context.attributes.groupID,
                            iconSize: taskIconSize,
                            font: taskFont
                        )
                        .padding(.horizontal, 4)
                    }
                }
            } else {
                // 全部完成状态
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: taskIconSize))
                        .foregroundStyle(.green)
                    Text("全部完成！")
                        .font(taskFont)
                        .fontWeight(.medium)
                        .foregroundStyle(.green)
                }
                .padding(.horizontal, 4)
            }
            
            // 填充剩余空间，确保始终使用最大尺寸
            if displayTaskCount < 5 {
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
        .activityBackgroundTint(Color(uiColor: .systemBackground).opacity(0.9))
        .activitySystemActionForegroundColor(Color.primary)
    }
}

// MARK: - 任务行视图（锁屏交互）
struct TaskRowView: View {
    let task: TaskItemSnapshot
    let groupID: String
    var iconSize: CGFloat = 18
    var font: Font = .subheadline
    
    var body: some View {
        // 调试：打印参数
        let _ = print("🔘 [TaskRowView] 渲染: groupID=\(groupID), taskID=\(task.id), title=\(task.title)")
        
        // 使用 Button + LiveActivityIntent 实现不打开 App 的交互
        Button(intent: ToggleTaskIntent(groupID: groupID, taskID: task.id)) {
            HStack(spacing: 10) {
                // 圆圈图标
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: iconSize, weight: .medium))
                    .foregroundStyle(task.isCompleted ? .green : .gray)
                
                // 任务标题
                Text(task.title)
                    .font(font)
                    .fontWeight(.medium)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)
                    .strikethrough(task.isCompleted, color: .secondary)
                    .lineLimit(1)
                
                Spacer(minLength: 0)
                
                // 日期显示在右边
                if let dateStr = task.formattedDueDate {
                    Text(dateStr)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview("Live Activity", as: .content, using: FocusAttributes(groupID: "preview")) {
    FocusActivityWidget()
} contentStates: {
    FocusAttributes.ContentState(
        groupTitle: "晚自修",
        groupIcon: "🌙",
        tasks: [
            TaskItemSnapshot(
                id: "1",
                title: "复习数学",
                isCompleted: false
            ),
            TaskItemSnapshot(
                id: "2",
                title: "写英语作业",
                isCompleted: true
            ),
            TaskItemSnapshot(
                id: "3",
                title: "物理练习题",
                isCompleted: false
            ),
        ]
    )
}
