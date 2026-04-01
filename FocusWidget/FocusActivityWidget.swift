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
import UIKit

private let appGroupID = "group.com.QingTeng.FocusLive"
private let liveActivityDisplayCountKey = "liveActivityMaxCount"
private let liveActivityOpacityKey = "liveActivityBackgroundOpacity"
private let liveActivityFontSizeKey = "liveActivityFontSize"
private let proStatusKey = "isProUser"
private let compactViewKey = "compactViewEnabled"

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
                    if context.attributes.groupID.hasPrefix("motivation_") {
                        Text("💡")
                            .font(.headline)
                    } else if context.state.totalCount > 0 {
                        Text("\(context.state.completedCount)/\(context.state.totalCount)")
                            .font(.headline.monospacedDigit())
                    } else {
                        Text("🔔\(context.state.reminderTasks.count)")
                            .font(.headline.monospacedDigit())
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if context.attributes.groupID.hasPrefix("motivation_"),
                       let quoteTask = context.state.tasks.first {
                        Text(quoteTask.title)
                            .font(.subheadline)
                            .lineLimit(2)
                    } else if let firstTask = context.state.todoIncompleteTasks.first {
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
                    } else if let firstReminder = context.state.reminderTasks.first {
                        HStack(spacing: 8) {
                            Image(systemName: "bell.fill")
                                .foregroundStyle(.orange)
                            Text(firstReminder.title)
                                .font(.subheadline)
                                .lineLimit(1)
                            Spacer()
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
                if context.attributes.groupID.hasPrefix("motivation_") {
                    Text("💡")
                        .font(.caption)
                } else if context.state.totalCount > 0 {
                    Text("\(context.state.completedCount)/\(context.state.totalCount)")
                        .font(.caption.monospacedDigit())
                } else {
                    Text("🔔\(context.state.reminderTasks.count)")
                        .font(.caption.monospacedDigit())
                }
            } minimal: {
                // 最小化视图：显示剩余任务数（点击展开灵动岛）
                // 注意：minimal 视图不支持 Button 交互，点击会展开灵动岛
                if context.attributes.groupID.hasPrefix("motivation_") {
                    ZStack {
                        Circle()
                            .fill(Color.orange)
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    }
                } else {
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
}

// MARK: - 锁屏 Live Activity 视图
struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<FocusAttributes>
    
    /// 是否为每日鼓励卡片
    private var isMotivationActivity: Bool {
        context.attributes.groupID.hasPrefix("motivation_")
    }
    
    /// 每日鼓励正文
    private var motivationText: String {
        context.state.tasks.first?.title ?? "愿你今天也保持专注。"
    }
    
    /// 拆分每日鼓励内容（正文 / 作者）
    private var motivationParts: (quote: String, author: String?) {
        let raw = motivationText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let range = raw.range(of: "\n——", options: .backwards) {
            let quote = String(raw[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            let author = String(raw[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            return (quote.isEmpty ? raw : quote, author.isEmpty ? nil : author)
        }
        
        if let range = raw.range(of: "——", options: .backwards) {
            let quote = String(raw[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            let author = String(raw[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            return (quote.isEmpty ? raw : quote, author.isEmpty ? nil : author)
        }
        
        return (raw, nil)
    }
    
    private var motivationQuoteText: String {
        motivationParts.quote
    }
    
    private var motivationAuthorText: String? {
        motivationParts.author
    }
    
    /// 每日鼓励装饰色
    private var motivationAccentGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.cyan.opacity(isDarkAppearance ? 0.85 : 0.72),
                Color.blue.opacity(isDarkAppearance ? 0.78 : 0.64),
                Color.mint.opacity(isDarkAppearance ? 0.72 : 0.58)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// 计算进度值（防止除零错误）
    private var progressValue: Double {
        let total = context.state.totalCount
        guard total > 0 else { return 0 }
        return Double(context.state.completedCount) / Double(total)
    }
    
    /// 是否全部完成
    private var isAllCompleted: Bool {
        context.state.todoIncompleteTasks.isEmpty && context.state.totalCount > 0
    }
    
    /// 显示的任务数量（未完成+已完成，最多受 maxDisplayCount 限制）
    private var displayTaskCount: Int {
        min(allDisplayTasks.count, maxDisplayCount)
    }

    /// 用户设置的最大显示条数
    private var maxDisplayCount: Int {
        let storedValue = UserDefaults(suiteName: appGroupID)?
            .object(forKey: liveActivityDisplayCountKey) as? NSNumber
        let defaultValue = isCompactView ? 8 : (isProUser ? 4 : 3)
        let value = storedValue?.intValue ?? defaultValue
        let limit = isCompactView ? 8 : (isProUser ? 4 : 3)
        return min(max(value, 1), limit)
    }
    
    /// 是否启用紧凑视图
    private var isCompactView: Bool {
        let userSetting = UserDefaults(suiteName: appGroupID)?.bool(forKey: compactViewKey) ?? false
        let taskCount = context.state.incompleteTasks.count
        // 超过4个任务时自动启用紧凑模式
        return userSetting || taskCount > 4
    }

    private var headerStatusText: String {
        if isMotivationActivity {
            return "每日一句"
        }
        if context.state.totalCount > 0 {
            return isAllCompleted ? "✓" : "\(context.state.completedCount)/\(context.state.totalCount)"
        }
        return "🔔\(context.state.reminderTasks.count)"
    }
    
    /// 用户设置的背景透明度（默认完全透明）
    private var backgroundOpacity: Double {
        let storedValue = UserDefaults(suiteName: appGroupID)?
            .object(forKey: liveActivityOpacityKey) as? NSNumber
        let value = storedValue?.doubleValue ?? 0.0
        return min(max(value, 0.0), 1.0)
    }

    /// 当前是否为深色外观（读取系统外观设置）
    private var isDarkAppearance: Bool {
        if let interfaceStyle = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") {
            return interfaceStyle == "Dark"
        }
        return false
    }

    /// 锁屏卡片基础色：浅色白、深色黑
    private var baseCardColor: Color {
        isDarkAppearance ? Color.black : Color.white
    }

    /// 锁屏卡片玻璃背景（0 时完全透明，100 时接近基准色）
    @ViewBuilder
    private var glassBackground: some View {
        if backgroundOpacity >= 1.0 {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(baseCardColor)
        } else if backgroundOpacity > 0.001 {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(baseCardColor.opacity(backgroundOpacity))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .opacity((1.0 - backgroundOpacity) * 0.55)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(isDarkAppearance ? 0.06 * backgroundOpacity : 0.12 * backgroundOpacity))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            (isDarkAppearance ? Color.white : Color.black)
                                .opacity(isDarkAppearance ? 0.22 * backgroundOpacity : 0.10 * backgroundOpacity),
                            lineWidth: 1
                        )
                )
        } else {
            Color.clear
        }
    }

    /// 当前会员状态
    private var isProUser: Bool {
        UserDefaults(suiteName: appGroupID)?.bool(forKey: proStatusKey) ?? false
    }

    /// 用户设置的字体大小缩放比例（0.7 ~ 1.4，默认 1.0）
    private var fontSizeScale: CGFloat {
        let value = UserDefaults(suiteName: appGroupID)?
            .object(forKey: liveActivityFontSizeKey) as? Double ?? 1.0
        return CGFloat(min(max(value, 0.7), 1.4))
    }

    /// 当不透明度为100%时，应强制使用与背景对比的前景色方案
    private var forcedColorScheme: ColorScheme? {
        guard backgroundOpacity >= 1.0 else { return nil }
        return isDarkAppearance ? .dark : .light
    }

    /// 锁屏显示任务列表：未完成/提醒事项在前，已完成待办附在后（划线保留）
    private var allDisplayTasks: [TaskItemSnapshot] {
        let active = context.state.incompleteTasks   // 未完成 + 提醒
        let done = context.state.todoTasks.filter { $0.isCompleted }
        return active + done
    }

    /// 根据字体缩放比例计算任务行字号
    private var scaledTaskFont: Font {
        let base: CGFloat
        switch displayTaskCount {
        case 0...2: base = 20
        case 3...5: base = 17
        case 6...8: base = 16
        default: base = 14
        }
        return .system(size: base * fontSizeScale, weight: .medium)
    }

    private var scaledCompactFont: Font {
        let base: CGFloat
        switch displayTaskCount {
        case 0...4: base = 12
        case 5...6: base = 11
        case 7...8: base = 10
        default: base = 10
        }
        return .system(size: base * fontSizeScale, weight: .medium)
    }
    
    /// 根据任务数量计算头部字号
    private var headerIconSize: CGFloat {
        switch displayTaskCount {
        case 0...2: return 22
        case 3...5: return 20
        case 6...8: return 18
        default: return 16
        }
    }
    
    private var headerFont: Font {
        switch displayTaskCount {
        case 0...2: return .title3
        case 3...5: return .headline
        case 6...8: return .subheadline
        default: return .subheadline
        }
    }
    
    /// 根据任务数量计算任务字号
    private var taskIconSize: CGFloat {
        switch displayTaskCount {
        case 0...2: return 26
        case 3...5: return 22
        case 6...8: return 20
        default: return 18
        }
    }
    
    private var taskFont: Font {
        switch displayTaskCount {
        case 0...2: return .title3
        case 3...5: return .headline
        case 6...8: return .body
        default: return .subheadline
        }
    }
    
    /// 任务行间距
    private var taskSpacing: CGFloat {
        switch displayTaskCount {
        case 0...2: return 12
        case 3...5: return 10
        case 6...8: return 8
        default: return 6
        }
    }
    
    /// 紧凑模式图标大小
    private var compactIconSize: CGFloat {
        switch displayTaskCount {
        case 0...4: return 16
        case 5...6: return 14
        case 7...8: return 12
        default: return 12
        }
    }
    
    /// 紧凑模式字体
    private var compactFont: Font {
        switch displayTaskCount {
        case 0...4: return .caption
        case 5...6: return .caption2
        case 7...8: return .caption2
        default: return .caption2
        }
    }
    
    /// 紧凑模式行间距
    private var compactRowSpacing: CGFloat {
        switch displayTaskCount {
        case 4: return 4  // 4个任务时稍微缩短间距
        case 0...3: return 6
        case 5...6: return 4
        case 7...8: return 3
        default: return 3
        }
    }
    
    /// 紧凑模式行高
    private var compactRowHeight: CGFloat {
        switch displayTaskCount {
        case 0...4: return 24
        case 5...6: return 20
        case 7...8: return 18
        default: return 18
        }
    }
    
    var body: some View {
        if isMotivationActivity {
            motivationCardBody
        } else {
        // 整体容器 - 始终使用最大尺寸
        VStack(alignment: .leading, spacing: displayTaskCount <= 3 ? 14 : (displayTaskCount <= 6 ? 10 : 8)) {
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
                Text(headerStatusText)
                    .font(headerFont)
                    .fontWeight(.medium)
                    .foregroundStyle(isAllCompleted ? .green : .secondary)
                    .monospacedDigit()
            }
            .padding(.horizontal, 4)
            
            // 任务列表（最多显示用户设置的条数，已完成任务保留显示并划线）
            if !allDisplayTasks.isEmpty {
                if isCompactView {
                    // 紧凑模式：双列网格布局
                    let tasks = Array(allDisplayTasks.prefix(displayTaskCount))
                    let columns = [GridItem(.flexible()), GridItem(.flexible())]
                    let rows = min(Int(ceil(Double(tasks.count) / 2.0)), 5)

                    LazyVGrid(columns: columns, spacing: compactRowSpacing) {
                        ForEach(tasks.indices, id: \.self) { index in
                            TaskRowView(
                                task: tasks[index],
                                groupID: context.attributes.groupID,
                                iconSize: compactIconSize,
                                font: scaledCompactFont
                            )
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(maxHeight: CGFloat(rows) * (compactRowHeight + compactRowSpacing))
                } else {
                    // 普通模式：单列布局
                    VStack(alignment: .leading, spacing: taskSpacing) {
                        ForEach(Array(allDisplayTasks.prefix(displayTaskCount)), id: \.id) { task in
                            TaskRowView(
                                task: task,
                                groupID: context.attributes.groupID,
                                iconSize: taskIconSize,
                                font: scaledTaskFont
                            )
                            .padding(.horizontal, 4)
                        }
                    }
                }
            } else {
                // 全部完成状态或无任务状态
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: taskIconSize))
                        .foregroundStyle(.green)
                    Text(context.state.totalCount > 0 ? "全部完成！" : "暂无任务")
                        .font(taskFont)
                        .fontWeight(.medium)
                        .foregroundStyle(.green)
                }
                .padding(.horizontal, 4)
            }
            
            // 填充剩余空间，确保始终使用最大尺寸
            if displayTaskCount < maxDisplayCount {
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
        .background(glassBackground)
        .environment(\.colorScheme, forcedColorScheme ?? .dark)
        .activityBackgroundTint(.clear)
        .activitySystemActionForegroundColor(forcedColorScheme == .light ? Color.black : Color.white)
        }
    }
    
    /// 每日鼓励专用卡片（纯展示，不交互）
    private var motivationCardBody: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(motivationAccentGradient)
                            .frame(width: 28, height: 28)
                        Image(systemName: "quote.opening")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    
                    Text(context.state.groupTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .fontWeight(.semibold)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Text(headerStatusText)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule(style: .continuous)
                            .fill(.thinMaterial)
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Color.white.opacity(isDarkAppearance ? 0.20 : 0.28), lineWidth: 0.7)
                    )
            }
            
            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(motivationAccentGradient)
                    .frame(width: 3)
                
                Text("“\(motivationQuoteText)”")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            if let author = motivationAuthorText {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(author)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.primary.opacity(isDarkAppearance ? 0.12 : 0.08))
                )
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            
            HStack(spacing: 6) {
                Image(systemName: "leaf.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("慢一点，也在前进")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
        .background(glassBackground)
        .overlay(alignment: .topTrailing) {
            Circle()
                .stroke(motivationAccentGradient, lineWidth: 1)
                .frame(width: 78, height: 78)
                .opacity(0.55)
                .offset(x: 22, y: -30)
        }
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(motivationAccentGradient.opacity(0.18))
                .frame(width: 58, height: 58)
                .offset(x: 12, y: -22)
        }
        .overlay(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(motivationAccentGradient.opacity(0.45))
                .frame(height: 1)
                .padding(.horizontal, 4)
                .padding(.bottom, 2)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .activityBackgroundTint(.clear)
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
        if task.taskType == .reminder {
            HStack(spacing: 10) {
                Image(systemName: "bell.fill")
                    .font(.system(size: iconSize, weight: .medium))
                    .foregroundStyle(.orange)
                
                Text(task.title)
                    .font(font)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                Spacer(minLength: 0)
                
                if let dateStr = task.formattedDueDate {
                    Text(dateStr)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        } else {
            // 使用 Button + LiveActivityIntent 实现不打开 App 的交互
            Button(intent: ToggleTaskIntent(groupID: groupID, taskID: task.id)) {
                HStack(spacing: 10) {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: iconSize, weight: .medium))
                        .foregroundStyle(task.isCompleted ? .green : .gray)
                    
                    Text(task.title)
                        .font(font)
                        .fontWeight(.medium)
                        .foregroundStyle(task.isCompleted ? .secondary : .primary)
                        .strikethrough(task.isCompleted, color: .secondary)
                        .lineLimit(1)
                    
                    Spacer(minLength: 0)
                    
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
