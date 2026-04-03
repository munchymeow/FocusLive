# ActivityKit 技术详解

## 当前实现快照（2026-04-03）

- 首页默认筛选为 `全部`
- 筛选顺序为 `全部 / 未完成 / 已完成 / 隐私空间`
- 首次启动会进入交互式新手教程，并直接写入实时活动相关设置
- 锁屏卡片默认字号为 `150%`
- 锁屏卡片背景仅保留 `透明 / 不透明` 两种模式
- 已完成事项可按设置决定是否显示，并以横线标记
- 每日鼓励可独立开启，支持首页底部展示、锁屏鼓励卡片同步、手动刷新和自定义
- 顶部 `+` 按钮使用锚定式菜单，不再使用底部确认弹层

## 核心概念深度解析

### 1. Activity 的生命周期

```swift
// 创建 Activity
let activity = try Activity.request(
    attributes: FocusAttributes(groupID: "group-123"),
    content: .init(state: initialState, staleDate: nil),
    pushType: nil
)

// 更新 Activity
await activity.update(ActivityContent(state: newState, staleDate: nil))

// 结束 Activity
await activity.end(nil, dismissalPolicy: .immediate)
```

**关键点：**
- `attributes` 是静态的，创建后不可修改
- `content.state` 是动态的，可以多次更新
- `staleDate` 用于标记数据过期时间（可选）
- `dismissalPolicy` 控制结束时的行为（立即/延迟）

### 2. 数据大小限制

**ActivityKit 对数据大小有严格限制：**

- **Attributes + ContentState** 总大小：≈ 4KB
- 超出限制会导致创建/更新失败

**优化策略：**

```swift
// ❌ 不好：传递完整的任务对象
struct ContentState {
    var tasks: [Task]  // 可能包含大量不必要的属性
}

// ✅ 好：只传递必要数据
struct ContentState {
    var tasks: [TaskItemSnapshot]  // 精简版，只有 id, title, isCompleted
}
```

**本项目的轻量化设计：**

```swift
struct TaskItemSnapshot: Codable, Hashable {
    let id: String           // 仅 36 字节（UUID）
    let title: String        // 通常 < 50 字节
    let isCompleted: Bool    // 1 字节
}
// 单个任务 ≈ 100 字节，可以安全传递 30+ 个任务
```

### 3. 自动同步的核心算法

#### 问题：如何避免重复创建 Activity？

**方案 1（低效）：每次都先结束所有 Activity，再重新创建**

```swift
// ❌ 不推荐：会导致闪烁
for activity in Activity.activities {
    await activity.end(nil, dismissalPolicy: .immediate)
}
for group in groups {
    try Activity.request(...)
}
```

**方案 2（高效）：使用 Set 进行差异比对**

```swift
// ✅ 推荐：本项目采用的方案
let runningIDs = Set(Activity.activities.map { $0.attributes.groupID })
let currentIDs = Set(groups.map { $0.id.uuidString })

// 只创建新增的
for group in groups where !runningIDs.contains(group.id.uuidString) {
    try Activity.request(...)
}

// 只结束删除的
for activity in Activity.activities where !currentIDs.contains(activity.attributes.groupID) {
    await activity.end(...)
}
```

**时间复杂度分析：**
- 方案 1：O(n²) - 每次都重建
- 方案 2：O(n) - 只处理差异

### 4. 交互式 Intent 的实现

#### LiveActivityIntent vs AppIntent

```swift
// LiveActivityIntent：专为 Live Activity 设计
struct ToggleTaskIntent: LiveActivityIntent {
    @Parameter var groupID: String
    @Parameter var taskID: String
    
    @MainActor
    func perform() async throws -> some IntentResult {
        // 直接访问 Activity.activities
        guard let activity = Activity<FocusAttributes>.activities.first(...) else {
            return .result()
        }
        
        // 修改并更新
        await activity.update(...)
        return .result()
    }
}
```

**关键特性：**
- 自动在后台执行，无需打开 App
- 可以直接访问 `Activity.activities`
- 返回 `IntentResult` 表示完成

#### 参数传递

```swift
// 在视图中绑定 Intent
Button(intent: ToggleTaskIntent(groupID: "123", taskID: "456")) {
    Image(systemName: "circle")
}
```

**注意事项：**
- 参数必须是 `Codable` 类型
- 避免传递复杂对象（使用 ID 代替）
- Intent 执行时可能 App 未运行，需要独立处理

### 5. Dynamic Island 布局技巧

#### 区域划分

```
┌─────────────────────────────┐
│  Leading  │       │ Trailing │  ← Expanded
├───────────┴───────┴──────────┤
│                               │
│          Bottom               │  ← Expanded
└───────────────────────────────┘

[Icon] ··· [Badge]  ← Compact
   │          │
Leading   Trailing

 [Icon]  ← Minimal
```

#### 最佳实践

```swift
DynamicIsland {
    DynamicIslandExpandedRegion(.leading) {
        // 左侧：通常放图标 + 标题
        HStack {
            Image(systemName: icon)
            Text(title)
        }
    }
    
    DynamicIslandExpandedRegion(.trailing) {
        // 右侧：通常放状态信息
        Text("2/5")
    }
    
    DynamicIslandExpandedRegion(.bottom) {
        // 底部：主要内容 + 交互按钮
        VStack {
            Text("下一个任务：复习数学")
            Button(intent: ...) {
                Text("标记完成")
            }
        }
    }
} compactLeading: {
    // 收起左侧：简化版图标
    Image(systemName: icon)
} compactTrailing: {
    // 收起右侧：通常是数字或简短状态
    Text("-3")
} minimal: {
    // 最小化：仅图标
    Image(systemName: icon)
}
```

**尺寸限制：**
- Compact：宽度受限（≈ 100pt）
- Expanded：高度不宜超过屏幕 1/3
- Minimal：≈ 20x20pt

### 6. 性能优化

#### 避免频繁更新

```swift
// ❌ 不好：每次任务变化都更新
task.isCompleted.toggle()
updateActivity()  // 可能每秒触发多次

// ✅ 好：使用防抖（debounce）
private var updateTask: Task<Void, Never>?
func scheduleUpdate() {
    updateTask?.cancel()
    updateTask = Task {
        try? await Task.sleep(for: .seconds(0.3))
        updateActivity()
    }
}
```

#### 批量更新

```swift
// ❌ 不好：循环内多次更新
for task in tasks {
    task.isCompleted = true
    updateActivity()  // 每次都更新
}

// ✅ 好：收集变化后一次性更新
for task in tasks {
    task.isCompleted = true
}
updateActivity()  // 只更新一次
```

### 7. 错误处理

#### 常见错误及解决方案

**1. Activity Limit Exceeded**

```swift
// 系统限制：每个 App 最多同时运行 2 个 Activity（iOS 16.2+）
// 解决方案：合并相关内容，或让用户选择优先级
```

**2. Invalid Activity**

```swift
// 原因：Activity 已结束，但仍尝试更新
// 解决方案：更新前先检查
guard Activity.activities.contains(where: { $0.id == activityID }) else {
    return
}
```

**3. Content Too Large**

```swift
// 原因：数据超过 4KB
// 解决方案：使用 Snapshot 精简数据
do {
    try Activity.request(...)
} catch {
    print("错误：\(error)")  // ActivityContentError.contentTooLarge
}
```

### 8. 测试策略

#### 单元测试

```swift
@MainActor
class ActivityManagerTests: XCTestCase {
    func testSyncActivities() async {
        let manager = ActivityManager.shared
        let groups = [
            TaskGroup(title: "Test", iconName: "star", tasks: [])
        ]
        
        manager.syncActivities(groups: groups)
        
        // 验证
        let activities = Activity<FocusAttributes>.activities
        XCTAssertEqual(activities.count, 1)
    }
}
```

#### UI 测试（模拟器限制）

```swift
// 注意：Live Activity 在模拟器上显示有限
// 建议使用真机测试，或使用 Xcode Preview
#Preview("Live Activity", as: .content, using: FocusAttributes(groupID: "preview")) {
    FocusActivityWidget()
} contentStates: {
    FocusAttributes.ContentState(...)
}
```

### 9. App Groups 数据共享（当前实现）

本项目已经使用 App Groups 在 App、Live Activity 与 Widget 之间共享状态：

```swift
let sharedDefaults = UserDefaults(suiteName: "group.com.QingTeng.FocusLive")
sharedDefaults?.set(data, forKey: "pendingTaskChanges")
```

当前共享的核心内容包括：

- `pendingTaskChanges`：锁屏勾选任务后的待回写变更
- `liveActivityFontSize`：实时活动字体大小
- `liveActivityBackgroundOpacity`：透明 / 不透明背景模式
- `liveActivityShowCompletedTasks`：是否显示已完成事项
- `dailyMotivationEnabled`：每日鼓励开关
- `currentMotivationQuote` / `currentMotivationAuthor`：当前每日鼓励内容

这部分逻辑主要分布在：

- `FocusLive/ActivityManager.swift`
- `FocusLive/ContentView.swift`
- `FocusLive/ToggleTaskIntent.swift`
- `FocusWidget/FocusActivityWidget.swift`

### 10. 调试技巧

#### 启用详细日志

```swift
// 在 ActivityManager 中添加
#if DEBUG
print("🔍 [Activity] \(message)")
#endif
```

#### 查看所有运行中的 Activity

```swift
func debugActivities() {
    print("📱 当前运行中的 Activities:")
    for activity in Activity<FocusAttributes>.activities {
        print("  - ID: \(activity.id)")
        print("    GroupID: \(activity.attributes.groupID)")
        print("    State: \(activity.content.state.groupTitle)")
    }
}
```

#### 强制结束所有 Activity

```swift
// 用于调试/重置
func resetAllActivities() async {
    for activity in Activity<FocusAttributes>.activities {
        await activity.end(nil, dismissalPolicy: .immediate)
    }
}
```

## 最佳实践总结

✅ **数据设计**
- 使用轻量化的 Snapshot 而非完整对象
- 避免嵌套复杂结构
- 字符串长度控制在合理范围

✅ **更新策略**
- 使用差异比对而非全量重建
- 批量更新而非逐个更新
- 合理使用防抖避免过度刷新

✅ **用户体验**
- 自动同步，无需手动操作
- 锁屏交互流畅，即点即反馈
- 灵动岛充分利用空间

✅ **错误处理**
- try-catch 捕获创建/更新失败
- 检查 Activity 是否存在
- 记录日志便于调试

---

**参考资料：**
- [Apple Developer: ActivityKit](https://developer.apple.com/documentation/activitykit)
- [WWDC 2022: Meet ActivityKit](https://developer.apple.com/videos/play/wwdc2022/10184/)
- [Human Interface Guidelines: Live Activities](https://developer.apple.com/design/human-interface-guidelines/live-activities)
