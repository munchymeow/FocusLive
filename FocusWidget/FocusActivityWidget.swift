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
private let liveActivityFontSizeKey   = "liveActivityFontSize"
private let liveActivityFontColorKey  = "liveActivityFontColor"
private let showCompletedTasksKey = "liveActivityShowCompletedTasks"
private let proStatusKey = "isProUser"
private let compactViewKey = "compactViewEnabled"
private let dynamicIslandEnabledKey = "liveActivityDynamicIslandEnabled"
private let liveActivityAppearanceKey = "liveActivitySystemAppearance"

/// Live Activity Widget 视图
struct FocusActivityWidget: Widget {
    private var isDynamicIslandEnabled: Bool {
        UserDefaults(suiteName: appGroupID)?.object(forKey: dynamicIslandEnabledKey) as? Bool ?? false
    }

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusAttributes.self) { context in
            // 锁屏 Live Activity 视图
            LockScreenLiveActivityView(context: context)
        } dynamicIsland: { context in
            dynamicIslandContent(for: context)
        }
    }

    private func dynamicIslandContent(for context: ActivityViewContext<FocusAttributes>) -> DynamicIsland {
        guard isDynamicIslandEnabled else {
            // iOS 目前不支持仅保留锁屏而彻底关闭灵动岛，这里尽量返回空内容。
            return DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    EmptyView()
                }
            } compactLeading: {
                EmptyView()
            } compactTrailing: {
                EmptyView()
            } minimal: {
                EmptyView()
            }
        }

        return DynamicIsland {
            DynamicIslandExpandedRegion(.leading) {
                HStack(spacing: 6) {
                    Text(context.state.groupIcon)
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

// MARK: - 锁屏 Live Activity 视图
struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<FocusAttributes>
    @Environment(\.colorScheme) private var colorScheme
    
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
        let taskCount = allDisplayTasks.count
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
        return value >= 0.5 ? 1.0 : 0.0
    }

    private var isOpaqueBackground: Bool {
        backgroundOpacity >= 1.0
    }

    private var storedSystemAppearance: String? {
        UserDefaults(suiteName: appGroupID)?.string(forKey: liveActivityAppearanceKey)
    }

    /// 当前是否为深色外观（直接跟随锁屏 Live Activity 的环境色彩方案）
    private var isDarkAppearance: Bool {
        if let storedSystemAppearance {
            return storedSystemAppearance == "dark"
        }
        if let interfaceStyle = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") {
            return interfaceStyle == "Dark"
        }
        return colorScheme == .dark
    }

    /// 锁屏默认标题颜色：半透明锁屏卡片统一使用白色，纯色背景再按明暗对比
    private var headerTextColor: Color {
        if isOpaqueBackground {
            return isDarkAppearance ? .white : .black
        }
        return .white
    }

    /// 锁屏自动任务文字颜色：默认白色，纯色背景再按明暗对比
    private var adaptiveTaskTextColor: Color {
        if isOpaqueBackground {
            return isDarkAppearance ? .white : .black
        }
        return .white
    }

    /// 锁屏卡片基础色：浅色白、深色黑
    private var baseCardColor: Color {
        isDarkAppearance ? Color.black : Color.white
    }

    /// 锁屏卡片背景：仅保留透明 / 不透明两种模式
    @ViewBuilder
    private var glassBackground: some View {
        if isOpaqueBackground {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(baseCardColor)
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
            .object(forKey: liveActivityFontSizeKey) as? Double ?? 1.5
        return CGFloat(min(max(value, 0.7), 2.0))
    }

    /// 用户设置的字体颜色，从 ContentState 读取（确保与 Activity.update 同步）
    private var customTextColor: Color {
        switch context.state.fontColorName {
        case "default": return adaptiveTaskTextColor
        case "white":  return .white
        case "black":  return .black
        case "yellow": return .yellow
        case "orange": return .orange
        case "green":  return .green
        case "blue":   return .blue
        case "red":    return .red
        case "pink":   return .pink
        case "purple": return .purple
        case "cyan":   return .cyan
        default:       return adaptiveTaskTextColor
        }
    }

    /// 是否显示已完成事项（使用划线保留）
    private var showCompletedTasks: Bool {
        UserDefaults(suiteName: appGroupID)?.object(forKey: showCompletedTasksKey) as? Bool ?? true
    }

    /// 透明卡片固定按深色语义渲染，不透明卡片跟随系统深浅色
    private var contentColorScheme: ColorScheme {
        isOpaqueBackground ? (isDarkAppearance ? .dark : .light) : .dark
    }

    /// 锁屏显示任务列表：未完成/提醒事项在前，已完成待办附在后（划线保留）
    private var allDisplayTasks: [TaskItemSnapshot] {
        let active = context.state.incompleteTasks   // 未完成 + 提醒
        let done = showCompletedTasks ? context.state.todoTasks.filter { $0.isCompleted } : []
        return active + done
    }

    /// 任务字号数值（任务越多字越小，强负相关；供 Font 和 NSAttributedString 复用）
    private var scaledTaskFontSize: CGFloat {
        let base: CGFloat
        switch displayTaskCount {
        case 0...1: base = 18
        case 2:     base = 16
        case 3:     base = 14
        case 4:     base = 13
        case 5:     base = 12
        case 6:     base = 11
        default:    base = 10
        }
        return base * fontSizeScale
    }

    private var scaledTaskFont: Font {
        .system(size: scaledTaskFontSize, weight: .medium)
    }

    private var scaledCompactFontSize: CGFloat {
        let base: CGFloat
        switch displayTaskCount {
        case 0...4: base = 12
        case 5...6: base = 11
        default:    base = 10
        }
        return base * fontSizeScale
    }

    private var scaledCompactFont: Font {
        .system(size: scaledCompactFontSize, weight: .medium)
    }

    private var scaledHeaderFontSize: CGFloat {
        scaledTaskFontSize
    }
    
    /// 根据任务数量计算头部字号（锁屏空间有限，保持紧凑）
    private var headerIconSize: CGFloat {
        switch displayTaskCount {
        case 0...2: return 15
        case 3...5: return 13
        default: return 12
        }
    }

    private var headerFont: Font {
        switch displayTaskCount {
        case 0...2: return .footnote
        case 3...5: return .caption
        default: return .caption2
        }
    }

    /// 根据任务数量计算任务字号
    private var taskIconSize: CGFloat {
        switch displayTaskCount {
        case 0...2: return 15
        case 3...5: return 13
        default: return 12
        }
    }

    private var taskFont: Font {
        switch displayTaskCount {
        case 0...2: return .footnote
        case 3...5: return .caption
        default: return .caption2
        }
    }

    /// 任务行间距
    private var taskSpacing: CGFloat {
        switch displayTaskCount {
        case 0...2: return 7
        case 3...5: return 5
        default: return 3
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
        VStack(alignment: .leading, spacing: 0) {
            // 头部：钉死在卡片顶部
            HStack(alignment: .center) {
                // 左上：emoji + 分组标题
                HStack(spacing: 6) {
                    Text(context.state.groupIcon)
                        .font(.system(size: headerIconSize))

                    Text(context.state.groupTitle)
                        .font(.system(size: scaledHeaderFontSize, weight: .semibold))
                        .fontWeight(.semibold)
                        .foregroundStyle(headerTextColor)
                        .lineLimit(1)
                }

                Spacer()

                // 右上：进度数字
                Text(headerStatusText)
                    .font(.system(size: scaledHeaderFontSize, weight: .medium))
                    .fontWeight(.medium)
                    .foregroundStyle(isAllCompleted ? .green : headerTextColor.opacity(0.6))
                    .monospacedDigit()
            }
            .padding(.horizontal, 4)

            // 任务列表在 header 下方垂直居中
            Spacer(minLength: 4)

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
                                font: scaledCompactFont,
                                textColor: customTextColor
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
                                font: scaledTaskFont,
                                textColor: customTextColor
                            )
                            .padding(.horizontal, 2)
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
            
            // 始终填充剩余空间，保证卡片占满锁屏最大高度
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 150, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(glassBackground)
        .environment(\.colorScheme, contentColorScheme)
        .activityBackgroundTint(.clear)
        .activitySystemActionForegroundColor(contentColorScheme == .light ? Color.black : Color.white)
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
    var textColor: Color = .white

    private var completedTextColor: Color {
        textColor.opacity(0.58)
    }

    private var strikeColor: Color {
        textColor.opacity(0.78)
    }

    private var strikeHeight: CGFloat {
        max(1.4, iconSize * 0.10)
    }

    var body: some View {
        if task.taskType == .reminder {
            HStack(spacing: 10) {
                Image(systemName: "bell.fill")
                    .font(.system(size: iconSize, weight: .medium))
                    .foregroundStyle(.orange)

                Text(task.title)
                    .font(font)
                    .fontWeight(.medium)
                    .foregroundStyle(textColor)
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
                        .foregroundStyle(task.isCompleted ? .green : .secondary)

                    taskTitleView

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

    @ViewBuilder
    private var taskTitleView: some View {
        Text(task.title)
            .font(font)
            .fontWeight(.medium)
            .foregroundStyle(task.isCompleted ? completedTextColor : textColor)
            .lineLimit(1)
            .overlay {
                if task.isCompleted {
                    Rectangle()
                        .fill(strikeColor)
                        .frame(height: strikeHeight)
                        .offset(y: 1)
                }
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
