//
//  AppSupport.swift
//  FocusLive
//
//  Shared helpers & constants used across multiple view files.
//

import Foundation
import SwiftData
import SwiftUI
import os

// MARK: - Logger

#if DEBUG
let focusLiveLogger = Logger(subsystem: "com.zhaohaowei.FocusLive", category: "App")
#endif

func debugLog(_ message: @autoclosure () -> String) {
    #if DEBUG
    let text = message()
    focusLiveLogger.debug("\(text, privacy: .public)")
    #endif
}

// MARK: - Shared Constants

let appGroupID = "group.com.QingTeng.FocusLive"
let currentMotivationQuoteKey = "currentMotivationQuote"
let currentMotivationAuthorKey = "currentMotivationAuthor"
let lastMotivationDateKey = "lastMotivationDate"
let lastDailyCheckInResetDateKey = "lastDailyCheckInResetDate"
let useCustomMotivationQuoteKey = "useCustomMotivationQuote"
let customMotivationQuoteKey = "customMotivationQuote"
let customMotivationAuthorKey = "customMotivationAuthor"
/// 与 UIStyleManager 共用的 App Group 键：锁屏 Live Activity 跟随实验室 UI 风格。
let selectedUIStyleKey = "selectedUIStyle"

extension Notification.Name {
    /// 实验室 UI 风格切换后广播，主界面据此刷新 Live Activity。
    static let focusLiveUIStyleDidChange = Notification.Name("focusLiveUIStyleDidChange")
}

/// 读取当前选中的 UI 风格 rawValue（Widget / Live Activity 可安全调用）。
/// 未开启实验室测试版 UI 时，固定返回 "ambient_glass" 默认正常风格。
func currentSelectedUIStyleRawValue() -> String {
    let defaults = UserDefaults(suiteName: appGroupID)
    let isLabEnabled = defaults?.bool(forKey: "labBorderlessUIEnabled") ?? false
    if !isLabEnabled {
        return "ambient_glass"
    }
    return defaults?.string(forKey: selectedUIStyleKey) ?? "ambient_glass"
}


/// 锁屏 Live Activity 的轻量视觉主题。
/// 只依赖 App Group 中的风格 rawValue，可在 Widget Extension 中安全使用。
struct LiveActivityStyleTheme {
    enum Kind: String {
        case ambientGlass = "ambient_glass"
        case flat = "flat"
        case skeu = "skeu"
        case material = "material"
        case minimal = "minimal"
        case glassmorphism = "glassmorphism"
        case boldStats = "bold_stats"
        case neoBrutal = "neo_brutal"
        case editorial = "editorial"
        case aurora = "aurora"
        case terminal = "terminal"

        static func resolve(_ raw: String?) -> Kind {
            Kind(rawValue: raw ?? "") ?? .ambientGlass
        }
    }

    let kind: Kind

    static var current: LiveActivityStyleTheme {
        LiveActivityStyleTheme(kind: .resolve(currentSelectedUIStyleRawValue()))
    }

    var cornerRadius: CGFloat {
        switch kind {
        case .ambientGlass: return 20
        case .flat: return 4
        case .skeu: return 14
        case .material: return 16
        case .minimal: return 10
        case .glassmorphism: return 22
        case .boldStats: return 18
        
        case .neoBrutal: return 4
        case .editorial: return 8
        case .aurora: return 22
        case .terminal: return 2
}
    }

    var usesMonospace: Bool { kind == .flat || kind == .terminal }
    var usesSerif: Bool { kind == .skeu || kind == .minimal || kind == .editorial }
    var usesRounded: Bool {
        switch kind {
        case .ambientGlass, .glassmorphism, .boldStats, .aurora, .neoBrutal: return true
        default: return false
        }
    }

    var accent: Color {
        switch kind {
        case .ambientGlass: return .cyan
        case .flat: return .white
        case .skeu: return Color(red: 0.45, green: 0.68, blue: 1.0)
        case .material: return .teal
        case .minimal: return .white
        case .glassmorphism: return .purple
        case .boldStats: return .orange
        
        case .neoBrutal: return Color(red: 1.0, green: 0.84, blue: 0.0)
        case .editorial: return Color(red: 0.85, green: 0.55, blue: 0.6)
        case .aurora: return Color(red: 0.55, green: 0.8, blue: 1.0)
        case .terminal: return Color(red: 0.2, green: 0.95, blue: 0.45)
}
    }

    func headerFont(size: CGFloat) -> Font {
        if usesMonospace {
            return .system(size: size, weight: .bold, design: .monospaced)
        }
        if usesSerif {
            return .system(size: size, weight: kind == .minimal ? .medium : .bold, design: .serif)
        }
        if usesRounded {
            return .system(size: size, weight: .bold, design: .rounded)
        }
        return .system(size: size, weight: .semibold, design: .default)
    }

    func bodyFont(size: CGFloat) -> Font {
        if usesMonospace {
            return .system(size: size, weight: .medium, design: .monospaced)
        }
        if usesSerif {
            return .system(size: size, weight: .medium, design: .serif)
        }
        if usesRounded {
            return .system(size: size, weight: .medium, design: .rounded)
        }
        return .system(size: size, weight: .medium, design: .default)
    }

    /// 锁屏卡片背景：在用户「透明 / 不透明」设置之上叠加风格材质。
    @ViewBuilder
    func cardBackground(isOpaque: Bool, isDark: Bool) -> some View {
        let base = isDark ? Color.black : Color.white
        switch kind {
        case .ambientGlass:
            if isOpaque {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(base.opacity(isDark ? 0.92 : 0.96))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.white.opacity(isDark ? 0.14 : 0.35), lineWidth: 1)
                    )
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(isDark ? 0.08 : 0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.white.opacity(0.18), lineWidth: 0.8)
                    )
            }

        case .flat:
            if isOpaque {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(isDark ? Color(red: 0.12, green: 0.12, blue: 0.11) : Color(red: 0.95, green: 0.93, blue: 0.86))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.primary.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    )
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }

        case .skeu:
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: isDark
                            ? [Color(red: 0.22, green: 0.22, blue: 0.25), Color(red: 0.12, green: 0.12, blue: 0.14)]
                            : [Color(red: 0.97, green: 0.96, blue: 0.93), Color(red: 0.86, green: 0.84, blue: 0.80)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(isDark ? 0.2 : 0.7), Color.black.opacity(isDark ? 0.4 : 0.12)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1.2
                        )
                )

        case .material:
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(isOpaque ? base.opacity(isDark ? 0.92 : 0.98) : Color.teal.opacity(isDark ? 0.18 : 0.16))
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.teal.opacity(0.85))
                        .frame(height: 3)
                        .clipShape(
                            UnevenRoundedRectangle(
                                topLeadingRadius: cornerRadius,
                                bottomLeadingRadius: 0,
                                bottomTrailingRadius: 0,
                                topTrailingRadius: cornerRadius,
                                style: .continuous
                            )
                        )
                }

        case .minimal:
            if isOpaque {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(base)
            } else {
                Color.clear
            }

        case .glassmorphism:
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.purple.opacity(isDark ? 0.28 : 0.22),
                            Color.blue.opacity(isDark ? 0.18 : 0.14)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.28), lineWidth: 0.8)
                )

        case .boldStats:
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(isOpaque ? base.opacity(isDark ? 0.94 : 0.98) : Color.orange.opacity(isDark ? 0.18 : 0.14))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.orange.opacity(0.8), Color.yellow.opacity(0.35)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.2
                        )
                )
        
        case .neoBrutal:
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(isOpaque ? (isDark ? Color.black : Color.white) : Color.yellow.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.primary, lineWidth: 2)
                )
        case .editorial:
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(isOpaque ? (isDark ? Color.black.opacity(0.92) : Color.white.opacity(0.96)) : Color.white.opacity(0.1))
                .overlay(alignment: .leading) {
                    Rectangle().fill(accent).frame(width: 3)
                }
        case .aurora:
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.cyan.opacity(isDark ? 0.25 : 0.18),
                            Color.purple.opacity(isDark ? 0.2 : 0.14),
                            Color.pink.opacity(isDark ? 0.16 : 0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.25), lineWidth: 0.8)
                )
        case .terminal:
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color(red: 0.04, green: 0.08, blue: 0.06).opacity(isOpaque ? 0.96 : 0.75))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color(red: 0.2, green: 0.95, blue: 0.45).opacity(0.55), lineWidth: 1)
                )
}
    }
}

// MARK: - SwiftData Save Helper

@discardableResult
func saveModelContext(
    _ modelContext: ModelContext,
    failureMessage: String,
    onFailure: (String) -> Void
) -> Bool {
    do {
        try modelContext.save()
        return true
    } catch {
        let message = "\(failureMessage)：\(error.localizedDescription)"
        debugLog(message)
        onFailure(message)
        return false
    }
}

// MARK: - String Helpers

func trimmed(_ raw: String) -> String {
    raw.trimmingCharacters(in: .whitespacesAndNewlines)
}

// MARK: - Default Group Icons (IconSax)

/// 新建分组时的默认图标：按任务类型推荐 IconSax，而非固定 SF Symbol。
func defaultGroupIconName(for taskType: TaskType) -> String {
    switch taskType {
    case .todo:
        return IconSaxCatalog.storageName(for: "folder")
    case .dailyCheckIn:
        return IconSaxCatalog.storageName(for: "calendar")
    case .reminder:
        return IconSaxCatalog.storageName(for: "notification")
    }
}

// MARK: - Repeat Task Engine

/// Calculate the next occurrence date for a repeating task.
func nextRepeatDate(from base: Date, repeatType: RepeatType, interval: Int) -> Date {
    let cal = Calendar.current
    let safeInterval = max(1, interval)
    switch repeatType {
    case .none:
        return base
    case .daily:
        return cal.date(byAdding: .day, value: safeInterval, to: base) ?? base
    case .weekly:
        return cal.date(byAdding: .weekOfYear, value: safeInterval, to: base) ?? base
    case .monthly:
        return cal.date(byAdding: .month, value: safeInterval, to: base) ?? base
    case .yearly:
        return cal.date(byAdding: .year, value: safeInterval, to: base) ?? base
    }
}

/// Create the next repeating task instance from a completed task.
/// Returns nil if the task has no repeat configuration.
func createNextRepeatTask(from task: TaskItem) -> TaskItem? {
    guard let repeatType = task.repeatType, repeatType != .none else { return nil }
    let interval = task.repeatInterval ?? 1
    
    // Use scheduledTime as base, fall back to dueDate, then now
    let baseDate = task.scheduledTime ?? task.dueDate ?? Date()
    let nextDate = nextRepeatDate(from: baseDate, repeatType: repeatType, interval: interval)
    
    let newTask = TaskItem(
        title: task.title,
        isCompleted: false,
        isPrivate: task.isPrivate ?? false,
        taskType: task.taskType ?? .todo,
        dueDate: task.dueDate != nil ? nextDate : nil,
        sortOrder: (task.sortOrder ?? 0) + 1,
        scheduledTime: task.scheduledTime != nil ? nextDate : nil,
        repeatType: repeatType,
        repeatInterval: interval,
        reminderType: task.reminderType,
        priority: task.priority
    )
    return newTask
}
