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

        // Expanded 布局遵循 HIG：leading / trailing / center / bottom 分区，
        // 尽量占满扩展态可用面积，避免标题+图标挤在 leading 导致裁切。
        // https://developer.apple.com/design/human-interface-guidelines/live-activities#Expanded
        return DynamicIsland {
            DynamicIslandExpandedRegion(.leading) {
                GroupIcon(
                    name: context.state.groupIcon,
                    size: 18,
                    tint: .primary,
                    showsChrome: false
                )
                .frame(width: 22, height: 22)
                .padding(.leading, 2)
            }
            DynamicIslandExpandedRegion(.trailing) {
                islandTrailingStatus(for: context)
                    .padding(.trailing, 2)
            }
            DynamicIslandExpandedRegion(.center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.state.groupTitle)
                        .font(.headline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(islandCenterSubtitle(for: context))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            DynamicIslandExpandedRegion(.bottom) {
                islandExpandedBottom(for: context)
                    .padding(.top, 4)
            }
        } compactLeading: {
            // compactLeading 可用宽度极窄：图标必须 ≤ ~12pt，且固定框内裁切。
            GroupIcon(
                name: context.state.groupIcon,
                size: 11,
                tint: .primary,
                showsChrome: false
            )
            .frame(width: 14, height: 14)
        } compactTrailing: {
            if context.attributes.groupID.hasPrefix("motivation_") {
                Image(systemName: "sparkles")
                    .font(.caption)
            } else if context.state.totalCount > 0 {
                Text("\(context.state.completedCount)/\(context.state.totalCount)")
                    .font(.caption.monospacedDigit())
            } else {
                HStack(spacing: 2) {
                    Image(systemName: "bell.badge.fill")
                    Text("\(context.state.reminderTasks.count)")
                }
                .font(.caption.monospacedDigit())
            }
        } minimal: {
            if context.attributes.groupID.hasPrefix("motivation_") {
                ZStack {
                    Circle().fill(Color.orange)
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 20, height: 20)
            } else {
                ZStack {
                    Circle()
                        .fill(context.state.remainingCount > 0 ? Color.blue : Color.green)
                    if context.state.remainingCount > 0 {
                        Text("\(context.state.remainingCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .minimumScaleFactor(0.6)
                    } else {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 20, height: 20)
            }
        }
    }

    // MARK: - Dynamic Island helpers

    @ViewBuilder
    private func islandTrailingStatus(for context: ActivityViewContext<FocusAttributes>) -> some View {
        if context.attributes.groupID.hasPrefix("motivation_") {
            Image(systemName: "sparkles")
                .font(.headline)
                .symbolRenderingMode(.hierarchical)
        } else if context.state.totalCount > 0 {
            Text("\(context.state.completedCount)/\(context.state.totalCount)")
                .font(.headline.monospacedDigit().weight(.semibold))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        } else {
            HStack(spacing: 3) {
                Image(systemName: "bell.badge.fill")
                Text("\(context.state.reminderTasks.count)")
            }
            .font(.headline.monospacedDigit())
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
    }

    private func islandCenterSubtitle(for context: ActivityViewContext<FocusAttributes>) -> String {
        if context.attributes.groupID.hasPrefix("motivation_") {
            return "每日一句"
        }
        if context.attributes.groupID.hasPrefix("smart_reminder_") {
            return "智能提醒"
        }
        if context.state.totalCount > 0 {
            let remaining = max(0, context.state.totalCount - context.state.completedCount)
            return remaining == 0 ? "全部完成" : "剩余 \(remaining) 项"
        }
        let reminders = context.state.reminderTasks.count
        return reminders > 0 ? "\(reminders) 条提醒" : "暂无任务"
    }

    @ViewBuilder
    private func islandExpandedBottom(for context: ActivityViewContext<FocusAttributes>) -> some View {
        if context.attributes.groupID.hasPrefix("motivation_"),
           let quoteTask = context.state.tasks.first {
            VStack(alignment: .leading, spacing: 6) {
                Text(quoteTask.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else if context.attributes.groupID.hasPrefix("smart_reminder_"),
                  let targetDate = context.state.tasks.first?.dueDate {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: "timer")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("距离计划时间")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if targetDate > Date() {
                        Text(timerInterval: Date()...targetDate, countsDown: true)
                            .font(.title3.monospacedDigit().weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    } else {
                        Text("时间已到")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.orange)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            let tasks = Array(context.state.todoIncompleteTasks.prefix(3))
            if tasks.isEmpty {
                if let firstReminder = context.state.reminderTasks.first {
                    HStack(spacing: 8) {
                        Image(systemName: "bell.fill")
                            .foregroundStyle(.orange)
                        Text(firstReminder.title)
                            .font(.subheadline)
                            .lineLimit(2)
                        Spacer(minLength: 0)
                    }
                } else if context.state.totalCount > 0 {
                    Label("全部完成！", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.green)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text("暂无任务")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(tasks.prefix(2), id: \.id) { task in
                        HStack(spacing: 8) {
                            Image(systemName: "circle")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Text(task.title)
                                .font(.subheadline)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                    }

                    if let firstTask = tasks.first {
                        Button(intent: ToggleTaskIntent(
                            groupID: context.attributes.groupID,
                            taskID: firstTask.id
                        )) {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("完成「\(firstTask.title)」")
                                    .lineLimit(1)
                            }
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.green.opacity(0.9), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
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

    private var isSmartReminderActivity: Bool {
        context.attributes.groupID.hasPrefix("smart_reminder_")
    }

    private var isAISummaryActivity: Bool {
        context.attributes.groupID.hasPrefix("ai_summary")
    }

    private var aiSummaryText: String {
        context.state.tasks.first?.title ?? "AI 正在总结工作中..."
    }

    private var smartReminderTargetDate: Date? {
        context.state.tasks.first?.dueDate
    }
    
    var body: some View {
        if isMotivationActivity {
            motivationCardBody
        } else if isSmartReminderActivity {
            smartReminderCardBody
        } else if isAISummaryActivity {
            aiSummaryCardBody
        } else {
            taskCardBody
        }
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
        let limit = isProUser ? 8 : 3
        let defaultValue = min(4, limit)
        let value = storedValue?.intValue ?? defaultValue
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

    /// 实验室 UI 风格 → 锁屏卡片视觉语言
    private var styleTheme: LiveActivityStyleTheme {
        LiveActivityStyleTheme.current
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

    /// 锁屏卡片背景：用户透明/不透明设置 + 实验室 UI 风格材质
    @ViewBuilder
    private var glassBackground: some View {
        styleTheme.cardBackground(isOpaque: isOpaqueBackground, isDark: isDarkAppearance)
    }

    /// 当前会员状态
    private var isProUser: Bool {
        UserDefaults(suiteName: appGroupID)?.bool(forKey: proStatusKey) ?? false
    }

    /// 用户设置的字体大小缩放比例（0.7 ~ 2.0，默认 1.5）
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
    
    private var taskCardBody: some View {
        // 整体容器 - 始终使用最大尺寸
        VStack(alignment: .leading, spacing: 0) {
            // 头部：钉死在卡片顶部
            HStack(alignment: .center) {
                // 左上：icon + 分组标题
                HStack(spacing: 6) {
                    GroupIcon(name: context.state.groupIcon, size: headerIconSize, tint: headerTextColor, showsChrome: false)

                    Text(context.state.groupTitle)
                        .font(styleTheme.headerFont(size: scaledHeaderFontSize))
                        .foregroundStyle(headerTextColor)
                        .lineLimit(1)
                }

                Spacer()

                // 右上：进度数字
                Text(headerStatusText)
                    .font(styleTheme.headerFont(size: scaledHeaderFontSize))
                    .foregroundStyle(isAllCompleted ? styleTheme.accent : headerTextColor.opacity(0.65))
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
                                font: styleTheme.bodyFont(size: scaledCompactFontSize),
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
                                font: styleTheme.bodyFont(size: scaledTaskFontSize),
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
        .padding(.horizontal, styleTheme.kind == .minimal ? 10 : 12)
        .padding(.vertical, styleTheme.kind == .flat ? 10 : 8)
        .background(glassBackground)
        .environment(\.colorScheme, contentColorScheme)
        .activityBackgroundTint(.clear)
        .activitySystemActionForegroundColor(contentColorScheme == .light ? Color.black : Color.white)
    }

    private var smartReminderCardBody: some View {
        let accent = styleTheme.kind == .boldStats ? Color.orange : styleTheme.accent
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(accent.opacity(isDarkAppearance ? 0.30 : 0.18))
                            .frame(width: 28, height: 28)
                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(accent)
                    }

                    Text(context.state.groupTitle)
                        .font(styleTheme.headerFont(size: 16))
                        .foregroundStyle(headerTextColor)
                        .lineLimit(1)
                }

                Spacer()

                Text("智能提醒")
                    .font(styleTheme.bodyFont(size: 11).weight(.semibold))
                    .foregroundStyle(accent)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(
                        Capsule(style: .continuous)
                            .fill(accent.opacity(isDarkAppearance ? 0.18 : 0.12))
                    )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("距离计划时间")
                    .font(styleTheme.bodyFont(size: 12))
                    .foregroundStyle(customTextColor.opacity(0.72))

                if let targetDate = smartReminderTargetDate, targetDate > Date() {
                    Text(timerInterval: Date()...targetDate, countsDown: true)
                        .font(styleTheme.headerFont(size: styleTheme.kind == .boldStats ? 34 : 30).monospacedDigit())
                        .foregroundStyle(customTextColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                } else {
                    Text("时间已到")
                        .font(styleTheme.headerFont(size: 30))
                        .foregroundStyle(accent)
                        .lineLimit(1)
                }
            }

            if let targetDate = smartReminderTargetDate {
                Text(targetDate.formatted(.dateTime.month().day().hour().minute()))
                    .font(styleTheme.bodyFont(size: 12))
                    .foregroundStyle(customTextColor.opacity(0.72))
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(styleTheme.kind == .minimal ? 12 : 14)
        .background(glassBackground)
        .environment(\.colorScheme, contentColorScheme)
        .activityBackgroundTint(.clear)
        .activitySystemActionForegroundColor(contentColorScheme == .light ? Color.black : Color.white)
    }
    
    /// 每日鼓励专用卡片（纯展示，不交互）——跟随实验室 UI 风格
    private var motivationCardBody: some View {
        let accent = styleTheme.accent
        return VStack(alignment: .leading, spacing: styleTheme.kind == .minimal ? 20 : 16) {
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
                        .font(styleTheme.headerFont(size: 16))
                        .lineLimit(1)
                }

                Spacer()

                Text(headerStatusText)
                    .font(styleTheme.bodyFont(size: 11).weight(.medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule(style: .continuous)
                            .fill(styleTheme.kind == .flat ? Color.primary.opacity(0.08) : Color.clear)
                            .background(.thinMaterial, in: Capsule(style: .continuous))
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Color.white.opacity(isDarkAppearance ? 0.20 : 0.28), lineWidth: 0.7)
                    )
            }

            HStack(alignment: .top, spacing: 10) {
                if styleTheme.kind != .minimal {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(motivationAccentGradient)
                        .frame(width: styleTheme.kind == .boldStats ? 5 : 3)
                }

                Text("“\(motivationQuoteText)”")
                    .font(styleTheme.bodyFont(size: styleTheme.kind == .boldStats ? 18 : 16))
                    .foregroundStyle(.primary)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let author = motivationAuthorText {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.caption2)
                        .foregroundStyle(accent.opacity(0.9))
                    Text(author)
                        .font(styleTheme.bodyFont(size: 12))
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
                    .font(styleTheme.bodyFont(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 14)
        .padding(.top, 26)
        .padding(.bottom, 14)
        .background(glassBackground)
        .overlay(alignment: .topTrailing) {
            if styleTheme.kind != .minimal && styleTheme.kind != .flat {
                Circle()
                    .stroke(motivationAccentGradient, lineWidth: 1)
                    .frame(width: 78, height: 78)
                    .opacity(0.55)
                    .offset(x: 22, y: -30)
            }
        }
        .overlay(alignment: .topTrailing) {
            if styleTheme.kind == .glassmorphism || styleTheme.kind == .ambientGlass {
                Circle()
                    .fill(motivationAccentGradient.opacity(0.18))
                    .frame(width: 58, height: 58)
                    .offset(x: 12, y: -22)
            }
        }
        .overlay(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(motivationAccentGradient.opacity(0.45))
                .frame(height: styleTheme.kind == .boldStats ? 2 : 1)
                .padding(.horizontal, 4)
                .padding(.bottom, 2)
        }
        .clipShape(RoundedRectangle(cornerRadius: styleTheme.cornerRadius, style: .continuous))
        .activityBackgroundTint(.clear)
        .activitySystemActionForegroundColor(Color.primary)
    }

    /// AI 总结卡片自适应字号（上限 140% / 18pt，根据字数递减）
    private var dynamicAISummaryFontSize: CGFloat {
        let count = aiSummaryText.count
        switch count {
        case 0...25:  return 18.0
        case 26...45: return 16.5
        case 46...65: return 15.0
        case 66...85: return 13.5
        default:      return 12.0
        }
    }

    /// AI 总结卡片自适应行间距
    private var dynamicAISummaryLineSpacing: CGFloat {
        aiSummaryText.count > 65 ? 3.0 : 4.5
    }

    /// AI 总结卡片动态垂直 Padding（字数少时留白更舒展）
    private var dynamicAISummaryVerticalPadding: CGFloat {
        let count = aiSummaryText.count
        if count <= 45 {
            return 16.0
        } else if count <= 65 {
            return 14.0
        } else {
            return 12.0
        }
    }

    /// AI 总结卡片动态子视图间距
    private var dynamicAISummarySpacing: CGFloat {
        let count = aiSummaryText.count
        if count <= 45 {
            return 10.0
        } else if count <= 65 {
            return 8.0
        } else {
            return 6.0
        }
    }

    private var aiSummaryCardBody: some View {
        VStack(alignment: .leading, spacing: dynamicAISummarySpacing) {
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [styleTheme.accent, Color.blue.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 24, height: 24)
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    Text("AI 总结")
                        .font(styleTheme.headerFont(size: 15))
                        .foregroundStyle(headerTextColor)
                }

                Spacer()

                Text("核心重心")
                    .font(styleTheme.bodyFont(size: 11).weight(.semibold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3.5)
                    .background(Capsule().fill(headerTextColor.opacity(0.12)))
                    .foregroundStyle(headerTextColor)
            }

            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(LinearGradient(colors: [styleTheme.accent, Color.blue.opacity(0.7)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 3.5)

                Text(aiSummaryText)
                    .font(styleTheme.bodyFont(size: dynamicAISummaryFontSize).weight(.semibold))
                    .foregroundStyle(adaptiveTaskTextColor)
                    .lineSpacing(dynamicAISummaryLineSpacing)
                    .lineLimit(5)
                    .minimumScaleFactor(0.75)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 14)
        .padding(.vertical, dynamicAISummaryVerticalPadding)
        .background(glassBackground)
        .clipShape(RoundedRectangle(cornerRadius: styleTheme.cornerRadius, style: .continuous))
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
        groupIcon: "moon.stars.fill",
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

#Preview("每日鼓励 Live Activity", as: .content, using: FocusAttributes(groupID: "motivation_preview")) {
    FocusActivityWidget()
} contentStates: {
    FocusAttributes.ContentState(
        groupTitle: "每日一句",
        groupIcon: "sparkles",
        tasks: [
            TaskItemSnapshot(
                id: "m1",
                title: "保持专注，是对自己最温柔的承诺\n——FocusScreen",
                isCompleted: false
            )
        ]
    )
}
