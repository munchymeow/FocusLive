# FocusLive

简化版：FocusLive 是基于 iOS Live Activities 的待办事项应用，支持自动将任务分组同步为锁屏/灵动岛实时活动，并提供锁屏上的交互（标记完成）。

关键点
- 支持 iOS 17+、Xcode 15+
- 使用 SwiftData 存储任务，使用 ActivityKit 管理 Live Activity
- 交互通过 `LiveActivityIntent` 实现，不一定会打开 App（`openAppWhenRun = false`）

快速文件概览
- `FocusLive/TaskModel.swift`：数据模型（`TaskGroup`、`TaskItem`、`TaskItemSnapshot`）
- `FocusLive/FocusAttributes.swift`：Activity 数据定义
- `FocusLive/ActivityManager.swift`：启动/更新/结束 Activity 的核心逻辑
- `FocusWidget/FocusActivityWidget.swift`：Lock Screen / Dynamic Island 视图

运行提示
- 使用真机（模拟器对 Live Activities 支持有限）
- 确保 App Groups 已配置（`group.com.QingTeng.FocusLive`）
- 在 Xcode 控制台查看同步与 Intent 调试日志

更多细节请参阅 `QUICKSTART.md` 和 `SETUP_CHECKLIST.md`。
1. 获取当前所有正在运行的 `Activity.activities`
2. 遍历 `groups`：
   - 如果某个 Group 还没有对应的 Activity（通过 ID 比对），则调用 `Activity.request` 自动创建
   - 如果 Group 已有 Activity，则调用 `update` 更新内容
3. 遍历运行中的 Activities：
   - 如果某个 Activity 对应的 Group 已被删除，则调用 `end` 关闭它

**防止重复创建的关键代码：**

```swift
let runningGroupIDs = Set(runningActivities.map { $0.attributes.groupID })
let currentGroupIDs = Set(groups.map { $0.id.uuidString })

// 只为不存在的分组创建 Activity
if !runningGroupIDs.contains(groupIDString) {
    startActivity(for: group)
}
```

#### 4️⃣ **交互意图** (`ToggleIntent.swift`)

实现 `LiveActivityIntent` 协议，支持锁屏交互。

```swift
struct ToggleTaskIntent: LiveActivityIntent {
    var groupID: String
    var taskID: String
    
    func perform() async throws -> some IntentResult {
        // 1. 找到对应的 Activity
        // 2. 修改 ContentState 中对应 Task 的 isCompleted
        // 3. 调用 activity.update() 刷新锁屏
    }
}
```

#### 5️⃣ **主界面** (`ContentView.swift`)

**自动化触发核心：**

```swift
.onAppear {
    activityManager.syncActivities(groups: taskGroups)
}
.onChange(of: taskGroups) { oldValue, newValue in
    activityManager.syncActivities(groups: taskGroups)
}
```

当 App 启动或数据变化时，自动调用 `syncActivities`。

#### 6️⃣ **锁屏界面** (`FocusActivityWidget.swift`)

**视觉设计要点：**

- **背景**：`.ultraThinMaterial` 毛玻璃效果
- **头部**：图标 + 标题 + 进度（如 "🌙 晚自修 2/5"）
- **任务列表**：最多显示 4 个未完成任务
- **交互按钮**：`Button(intent: ToggleTaskIntent(...))`

**灵动岛适配：**

- **Compact**：左边显示图标，右边显示剩余任务数
- **Expanded**：显示下一个任务 + "标记完成" 按钮

## 使用流程

### 🚀 第一次运行

1. 打开 App，点击"添加示例数据"按钮
2. 系统自动创建 3 个分组："工作"、"晚自修"、"生活"
3. **自动触发**：App 在 `onAppear` 时调用 `syncActivities`
4. 锁屏上立即出现 3 个 Live Activity 卡片

### 📱 日常使用

**在 App 内：**
- 添加/删除分组 → 自动同步到锁屏
- 添加/删除任务 → 自动更新对应的 Live Activity
- 标记任务完成 → 同时更新 App 和锁屏

**在锁屏上：**
- 点击圆圈按钮 → 标记任务完成
- 实时看到进度变化
- 在灵动岛查看下一个任务

## 技术要点

### ✅ ActivityKit 核心概念

1. **Attributes（静态属性）**：创建后不可更改，用于标识 Activity
2. **ContentState（动态内容）**：可通过 `update()` 更新
3. **Activity 生命周期**：`request` → `update` → `end`

### ✅ 自动同步的关键

**防止重复创建**：通过比对 `groupID` 实现

```swift
// 使用 Set 进行快速查找
let runningGroupIDs = Set(runningActivities.map { $0.attributes.groupID })
if !runningGroupIDs.contains(groupIDString) {
    // 不存在才创建
}
```

**自动清理**：删除的分组对应的 Activity 会被自动结束

```swift
if !currentGroupIDs.contains(groupID) {
    endActivity(groupID: groupID)
}
```

### ✅ 数据同步策略

1. **App → Live Activity**：通过 `ActivityManager.updateActivity()`
2. **Live Activity → App**：通过 App Groups 共享数据（未来可扩展）
3. **当前实现**：锁屏操作直接修改 Activity 的 ContentState

## 系统要求

- iOS 17.0+
- Xcode 15.0+
- 支持 Live Activities 的设备

## 配置说明

### Info.plist

确保主 App 的 Info.plist 包含：

```xml
<key>NSSupportsLiveActivities</key>
<true/>
```

### Entitlements

App 和 Widget Extension 都需要配置 App Groups：

```xml
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.QingTeng.FocusLive</string>
</array>
```

## 调试技巧

### 查看日志

`ActivityManager` 包含详细的打印日志：

```
🔄 同步 Live Activities...
   运行中的 Activities: 2 个
   当前分组数: 3 个
   ✅ 为分组 '生活' 创建新 Activity
   🔁 分组 '工作' 已有 Activity，更新内容
✅ 同步完成！
```

### 模拟器注意事项

Live Activities 在模拟器上可能显示不完整，建议在真机上测试。

## 扩展方向

🔮 **未来可以添加的功能：**

1. **推送更新**：使用 Push to Update 远程更新 Live Activity
2. **数据共享**：使用 App Groups + UserDefaults 实现双向同步
3. **统计分析**：记录任务完成时间、效率分析
4. **主题定制**：自定义颜色、图标、布局
5. **智能提醒**：基于时间或位置的任务提醒

## 许可证

MIT License

---

**开发者**: 赵豪伟  
**日期**: 2026/1/13  
**框架**: SwiftUI + ActivityKit + SwiftData
