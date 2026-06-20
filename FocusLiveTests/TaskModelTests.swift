//
//  TaskModelTests.swift
//  FocusLiveTests
//

import XCTest
import SwiftData
@testable import FocusLive

final class TaskModelTests: XCTestCase {

    // MARK: - TaskGroup.sortedTasks

    func testSortedTasks_putsDueDateFirst() {
        let t1 = TaskItem(title: "no date", sortOrder: 0)
        let t2 = TaskItem(title: "has date", dueDate: Date(timeIntervalSince1970: 1000), sortOrder: 1)
        let group = TaskGroup(title: "G", iconName: "📁", tasks: [t1, t2])
        let sorted = group.sortedTasks
        XCTAssertEqual(sorted.first?.title, "has date")
    }

    func testSortedTasks_earlierDueDateFirst() {
        let early = TaskItem(title: "early", dueDate: Date(timeIntervalSince1970: 100), sortOrder: 1)
        let late  = TaskItem(title: "late",  dueDate: Date(timeIntervalSince1970: 200), sortOrder: 0)
        let group = TaskGroup(title: "G", iconName: "📁", tasks: [late, early])
        let sorted = group.sortedTasks
        XCTAssertEqual(sorted.map(\.title), ["early", "late"])
    }

    func testSortedTasks_sameDueDate_usesSortOrder() {
        let date = Date(timeIntervalSince1970: 100)
        let a = TaskItem(title: "A", dueDate: date, sortOrder: 2)
        let b = TaskItem(title: "B", dueDate: date, sortOrder: 1)
        let group = TaskGroup(title: "G", iconName: "📁", tasks: [a, b])
        let sorted = group.sortedTasks
        XCTAssertEqual(sorted.map(\.title), ["B", "A"])
    }

    func testSortedTasks_noDueDate_usesSortOrder() {
        let a = TaskItem(title: "A", sortOrder: 3)
        let b = TaskItem(title: "B", sortOrder: 1)
        let c = TaskItem(title: "C", sortOrder: 2)
        let group = TaskGroup(title: "G", iconName: "📁", tasks: [a, b, c])
        let sorted = group.sortedTasks
        XCTAssertEqual(sorted.map(\.title), ["B", "C", "A"])
    }

    // MARK: - TaskGroup counts

    func testCompletedCount() {
        let t1 = TaskItem(title: "done", isCompleted: true)
        let t2 = TaskItem(title: "open", isCompleted: false)
        let group = TaskGroup(title: "G", iconName: "📁", tasks: [t1, t2])
        XCTAssertEqual(group.completedCount, 1)
        XCTAssertEqual(group.totalCount, 2)
    }

    func testIncompleteTasks_filtersCompleted() {
        let t1 = TaskItem(title: "done", isCompleted: true, sortOrder: 0)
        let t2 = TaskItem(title: "open", isCompleted: false, sortOrder: 1)
        let group = TaskGroup(title: "G", iconName: "📁", tasks: [t1, t2])
        XCTAssertEqual(group.incompleteTasks.map(\.title), ["open"])
    }

    // MARK: - TaskItemSnapshot

    func testSnapshot_preservesMetadata() {
        let item = TaskItem(
            title: "Test",
            isCompleted: false,
            taskType: .todo,
            dueDate: Date(timeIntervalSince1970: 500),
            priority: .high
        )
        let snap = TaskItemSnapshot(from: item)
        let updated = snap.updatingCompletion(true)
        XCTAssertTrue(updated.isCompleted)
        XCTAssertEqual(updated.title, "Test")
        XCTAssertEqual(updated.priority, .high)
        XCTAssertEqual(updated.dueDate, Date(timeIntervalSince1970: 500))
    }

    func testSnapshot_formattedDueDate() {
        let item = TaskItem(
            title: "T",
            dueDate: Date(timeIntervalSince1970: 0)  // 1970-01-01 00:00 UTC
        )
        let snap = TaskItemSnapshot(from: item)
        XCTAssertNotNil(snap.formattedDueDate)
    }

    func testSnapshot_nilDueDate() {
        let item = TaskItem(title: "T")
        let snap = TaskItemSnapshot(from: item)
        XCTAssertNil(snap.formattedDueDate)
    }

    // MARK: - TaskGroupSnapshot

    func testGroupSnapshot_fromGroup() {
        let t1 = TaskItem(title: "A", isCompleted: true, sortOrder: 0)
        let t2 = TaskItem(title: "B", isCompleted: false, sortOrder: 1)
        let group = TaskGroup(title: "My Group", iconName: "⭐", tasks: [t1, t2])
        let snap = TaskGroupSnapshot(from: group)
        XCTAssertEqual(snap.title, "My Group")
        XCTAssertEqual(snap.totalCount, 2)
        XCTAssertEqual(snap.completedCount, 1)
        XCTAssertEqual(snap.incompleteTasks.count, 1)
        XCTAssertEqual(snap.incompleteTasks.first?.title, "B")
    }

    // MARK: - AppSupport helpers

    func testTrimmed() {
        XCTAssertEqual(trimmed("  hello  "), "hello")
        XCTAssertEqual(trimmed("\n\t"), "")
        XCTAssertEqual(trimmed("no change"), "no change")
    }

    // MARK: - Enums

    func testRepeatType_rawValues() {
        XCTAssertEqual(RepeatType.none.rawValue, "none")
        XCTAssertEqual(RepeatType.daily.rawValue, "daily")
        XCTAssertEqual(RepeatType.weekly.rawValue, "weekly")
    }

    func testPriority_rawValues() {
        XCTAssertEqual(Priority.low.rawValue, "low")
        XCTAssertEqual(Priority.urgent.rawValue, "urgent")
    }

    func testTaskType_rawValues() {
        XCTAssertEqual(TaskType.todo.rawValue, "todo")
        XCTAssertEqual(TaskType.reminder.rawValue, "reminder")
        XCTAssertEqual(TaskType.dailyCheckIn.rawValue, "dailyCheckIn")
    }

    func testTaskItem_isReminder() {
        let todo = TaskItem(title: "T", taskType: .todo)
        let reminder = TaskItem(title: "R", taskType: .reminder)
        XCTAssertFalse(todo.isReminder)
        XCTAssertTrue(reminder.isReminder)
    }

    // MARK: - Repeat Engine

    func testNextRepeatDate_daily() {
        let base = Date(timeIntervalSince1970: 1000)
        let next = nextRepeatDate(from: base, repeatType: .daily, interval: 1)
        XCTAssertEqual(next, Calendar.current.date(byAdding: .day, value: 1, to: base))
    }

    func testNextRepeatDate_weekly_interval3() {
        let base = Date(timeIntervalSince1970: 1000)
        let next = nextRepeatDate(from: base, repeatType: .weekly, interval: 3)
        XCTAssertEqual(next, Calendar.current.date(byAdding: .weekOfYear, value: 3, to: base))
    }

    func testNextRepeatDate_monthly() {
        let base = Date(timeIntervalSince1970: 1000)
        let next = nextRepeatDate(from: base, repeatType: .monthly, interval: 1)
        XCTAssertEqual(next, Calendar.current.date(byAdding: .month, value: 1, to: base))
    }

    func testNextRepeatDate_yearly() {
        let base = Date(timeIntervalSince1970: 1000)
        let next = nextRepeatDate(from: base, repeatType: .yearly, interval: 2)
        XCTAssertEqual(next, Calendar.current.date(byAdding: .year, value: 2, to: base))
    }

    func testNextRepeatDate_none() {
        let base = Date(timeIntervalSince1970: 1000)
        let next = nextRepeatDate(from: base, repeatType: .none, interval: 1)
        XCTAssertEqual(next, base)
    }

    func testNextRepeatDate_zeroInterval_clampedTo1() {
        let base = Date(timeIntervalSince1970: 1000)
        let next = nextRepeatDate(from: base, repeatType: .daily, interval: 0)
        XCTAssertEqual(next, Calendar.current.date(byAdding: .day, value: 1, to: base))
    }

    func testCreateNextRepeatTask_daily() {
        let dueDate = Date(timeIntervalSince1970: 5000)
        let task = TaskItem(
            title: "Morning exercise",
            taskType: .todo,
            dueDate: dueDate,
            sortOrder: 5,
            scheduledTime: dueDate,
            repeatType: .daily,
            repeatInterval: 1,
            priority: .high
        )
        let next = createNextRepeatTask(from: task)
        XCTAssertNotNil(next)
        XCTAssertEqual(next!.title, "Morning exercise")
        XCTAssertFalse(next!.isCompleted)
        XCTAssertEqual(next!.taskType, .todo)
        XCTAssertEqual(next!.priority, .high)
        XCTAssertEqual(next!.repeatType, .daily)
        XCTAssertEqual(next!.repeatInterval, 1)
        // dueDate should advance by 1 day
        let expected = Calendar.current.date(byAdding: .day, value: 1, to: dueDate)
        XCTAssertEqual(next!.dueDate, expected)
        XCTAssertEqual(next!.scheduledTime, expected)
        XCTAssertEqual(next!.sortOrder, 6)
    }

    func testCreateNextRepeatTask_none_returnsNil() {
        let task = TaskItem(title: "One-off", taskType: .todo)
        XCTAssertNil(createNextRepeatTask(from: task))
    }

    func testCreateNextRepeatTask_noDueDate_usesScheduledTime() {
        let scheduled = Date(timeIntervalSince1970: 8000)
        let task = TaskItem(
            title: "Weekly review",
            taskType: .todo,
            scheduledTime: scheduled,
            repeatType: .weekly,
            repeatInterval: 2
        )
        let next = createNextRepeatTask(from: task)
        XCTAssertNotNil(next)
        XCTAssertNil(next!.dueDate)  // original had no dueDate
        let expected = Calendar.current.date(byAdding: .weekOfYear, value: 2, to: scheduled)
        XCTAssertEqual(next!.scheduledTime, expected)
    }

    func testCreateNextRepeatTask_preservesPrivacy() {
        let task = TaskItem(
            title: "Secret",
            isPrivate: true,
            taskType: .todo,
            dueDate: Date(timeIntervalSince1970: 5000),
            repeatType: .monthly,
            repeatInterval: 1
        )
        let next = createNextRepeatTask(from: task)
        XCTAssertTrue(next!.isPrivate ?? false)
    }
}
