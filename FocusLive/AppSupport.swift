//
//  AppSupport.swift
//  FocusLive
//
//  Shared helpers & constants used across multiple view files.
//

import Foundation
import SwiftData
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
