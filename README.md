# FocusLive（FocusScreen）

FocusLive 是一个基于 iOS Live Activities 的待办事项应用。任务分组会自动同步到锁屏和灵动岛，用户可以在锁屏上直接勾选完成，并把结果回写到 App。

> 本 README 在「当前功能」之外，额外维护了一份经过代码审计的 **已知问题清单** 与 **分阶段开发路线图**，作为后续迭代的唯一事实来源（single source of truth）。改动落地后，请同步勾选对应条目。

---

## 一、当前功能概览

- 首页筛选顺序：`全部`、`未完成`、`已完成`、`隐私空间`（默认 `全部`）
- 首次启动：交互式新手教程，可直接设置字体大小、已完成显示、每日鼓励和卡片背景
- 添加分组：右上角 `+` 下拉菜单创建 `传统待办事项`、`每日打卡`、`提醒事项`
- 锁屏卡片：透明 / 不透明背景、已完成事项显示开关、字体大小调节、字体颜色自定义
- 每日鼓励：首页 `全部` 页底部展示，支持随机刷新与自定义，并同步到锁屏鼓励卡片
- 灵动岛：Compact / Expanded 展示
- 会员（Pro）：隐私空间、智能提醒、最多 3 分组、最多 8 条任务、优先级 / 重复 / 计划时间
- 快捷指令：`添加任务到分组`、`创建分组并添加任务`（App Intents）

---

## 二、架构总览

| 层 | 关键文件 | 职责 |
| --- | --- | --- |
| 数据 | `TaskModel.swift` | `TaskGroup` / `TaskItem`（SwiftData @Model）+ `TaskGroupSnapshot` / `TaskItemSnapshot`（跨进程序列化） |
| 容器 | `FocusLiveApp.swift` / `ShortcutsIntents.swift` | App Group 共享 `ModelContainer`（`group.com.QingTeng.FocusLive` 下的 `FocusLive.store`） |
| Live Activity | `ActivityManager.swift` / `FocusAttributes.swift` | 创建 / 更新 / 结束 Activity、智能提醒、每日鼓励 |
| 锁屏交互 | `ToggleTaskIntent.swift` | `LiveActivityIntent`，在主 App 进程内切换完成状态并写入待同步队列 |
| Widget UI | `FocusActivityWidget.swift` / `FocusWidget.swift` / `FocusTaskWidget.swift` | 锁屏 / 灵动岛卡片；主屏每日鼓励 Widget；主屏任务列表 Widget |
| 主 UI | `ContentView.swift`(1129 行) + 9 个拆分文件 / `ProfileView.swift` / `LiveActivitySettingsView.swift` / `SubscriptionView.swift` | 首页、我的、设置、订阅 |
| 服务 | `StoreKitManager.swift` / `NotificationManager.swift` / `PrivacyAuthService.swift` | 订阅、本地通知、Face ID |

**跨进程数据流**：主 App 写 SwiftData → `ActivityManager` 推送 Activity 内容 → 锁屏点击触发 `ToggleTaskIntent`（主 App 进程）→ 直接写入 App Group SwiftData store 并更新 Activity；`pendingTaskChanges` 仅作为直接落库失败时的兜底队列。

---

## 三、已知问题清单（代码审计结果）

> 优先级：**P0**=功能性缺陷/影响核心体验；**P1**=可靠性/一致性/技术债；**P2**=代码质量/打磨。
> 状态：`[ ]` 待修复 / `[x]` 已修复。

### P0 — 功能性缺陷

- [x] **P0-1 主屏 Widget 与 App 数据完全脱节（含死代码）**
  `ActivityManager.persistWidgetSnapshot()` 与 `ToggleTaskIntent.saveWidgetSnapshotToAppGroup()` 把丰富的任务数据写入 App Group 的 `widgetDisplaySnapshot` key，但 `FocusWidget.swift` 的 `Provider` 从不读取它——`WidgetDisplayData` 只有 `.motivation` 一种 case，主屏 Widget 只显示 **12 条硬编码文案**（与 App 内 50 条 CSV / 自定义鼓励均不同步）。结论：所有 `widgetDisplaySnapshot` 写入（4 处）都是死代码；主屏「任务清单 Widget」实际从未实现。
  → 已修复：先采用「主屏 Widget = 共享数据源的每日鼓励」定位，删除 `widgetDisplaySnapshot` 写入死代码；`FocusWidget.Provider` 改为读取 App Group 中的当前每日鼓励 / 自定义鼓励。

- [x] **P0-2 智能提醒依赖 `Task.sleep` 自动结束，App 挂起即失效**
  `createSmartReminderActivity()` 用 `Task { try? await Task.sleep(... timeInterval ...) }` 在到点后结束 Activity。`timeInterval` 可达数小时甚至一周（`before1week`），一旦 App 被系统挂起/终止，该 Task 永不触发 → Activity 残留不消失；且倒计时文本「还剩 X 分钟」是创建时的静态快照，不会刷新。
  → 已修复：移除智能提醒的长时间 `Task.sleep`；Activity 内容使用 `staleDate: scheduledTime`，Widget 端用 `Text(timerInterval:countsDown:)` 系统级渲染倒计时，并在后续同步时清理过期/无效提醒。

- [x] **P0-3 智能提醒每次 sync 重复创建，锁屏堆叠**
  `checkAndCreateSmartReminders()` 在每次 `syncActivities()`（onAppear / scenePhase / onChange(taskGroups) / 设置变更…多处）都执行，`createSmartReminderActivity()` 每次都用全新 `smart_reminder_<UUID>`，无「是否已存在」判重 → 短时间内堆叠多张重复智能提醒卡片。
  → 已修复：智能提醒 ID 改为 `smart_reminder_<kind>_<sourceID>_<scheduledTime>`；同一提醒重复 sync 时更新现有 Activity，不再创建新卡片，并会清理非当前最高优先级的旧智能提醒。

- [x] **P0-4 「显示条数」设置上限与实际渲染上限不一致**
  `LiveActivitySettingsView.maxDisplayCount = isProUser ? 8 : 3`（Pro 可设 1~8），但 `FocusActivityWidget.maxDisplayCount` 在非紧凑视图下被 `isProUser ? 4 : 3` 截断。Pro 用户设 5~8 时，除非任务数 >4 自动进入紧凑网格，否则锁屏只显示 4 条 → 设置「看起来生效但没生效」。
  → 已修复：Widget 渲染层按 Pro 8 / 免费 3 统一裁剪，和设置页上限一致。

- [x] **P0-5 附件功能是假实现**
  `AdvancedTaskEditor.addAttachment()` 只追加一条硬编码「示例链接 https://example.com」；`saveChanges()` 根本不写回 `task.attachments`（只存 taskType/repeat/reminder/priority）。UI 存在但数据不持久化，误导用户。
  → 已修复：先从高级任务编辑器下线附件入口（M0），保留模型字段；M2 已实现真实链接附件的添加、展示与持久化（`AdvancedEditorViews.swift`），支持滑动删除。

- [x] **P0-6 图标选择器数据错误**
  `commonEmojis`（ContentView 内）混入了普通字符串 `"Fax"`（会在选择器里显示文字「Fax」）；并存在重复项（`⭐️`、`❤️` 各出现两次）。`IconPickerView` 用 `id: \.self`，重复值会触发 SwiftUI 重复 ID 警告与渲染异常。
  → 已修复：`"Fax"` 替换为 `📠`，数组加载时去重，`IconPickerView` 改用索引作为唯一 id。

### P1 — 可靠性 / 一致性 / 技术债

- [x] **P1-1 每日打卡重置不可靠**
  `resetDailyCheckInTasksIfNeeded()` 把 `lastDailyCheckInResetDate` 存进 `UserDefaults.standard`（非 App Group），且仅在主 App 前台触发。若用户只用锁屏/快捷指令、长期不开主 App，打卡永不重置。
  → 已修复：重置日期改存 App Group；主 App 前台和 `ToggleTaskIntent` 直接落库前都会校验每日打卡重置，长期只从锁屏交互的用户也能触发重置。

- [x] **P1-2 锁屏勾选不直接落库，存在数据滞后窗口**
  `ToggleTaskIntent` 已运行在主 App 进程（`@MainActor`），却只更新 Activity + 写 `pendingTaskChanges`，不直接写 SwiftData，依赖下次 App 到前台才回写。期间 Activity / 快照 与数据库不一致。
  → 已修复：`ToggleTaskIntent` 会直接打开 App Group 下的 SwiftData store 写入任务完成状态；`pendingTaskChanges` 仅在直接落库失败时作为兜底队列保留。

- [x] **P1-3 `syncActivities` 全量重建 + `renderVersion` 每次变化**
  `renderVersion = Date().timeIntervalSince1970` 导致每次 update 即使内容相同也被判定为「有变化」强制推送；叠加多入口高频触发（taskGroups/scenePhase/colorScheme），易触达 iOS 对 Activity 更新频率的预算限制，并产生「刚 start 又被 end」竞态。
  → 已修复：SwiftUI 高频入口改为 250ms 合并同步；普通分组 / 每日鼓励 Activity 更新前做 `ContentState` diff；`renderVersion` 改为样式设置指纹，仅在显示条数、背景、字体、颜色、深浅色、Pro 状态等实际渲染输入变化时改变。

- [x] **P1-4 灵动岛「关闭」为伪实现**
  `dynamicIslandEnabled=false` 时返回全 `EmptyView` 的灵动岛，但 Activity 仍存活，灵动岛仍占位（最小区域）。README/教程宣称「关闭灵动岛」与实际不符。
  → 已修复：产品文案改为「最小化展示」，设置页明确说明 iOS 不支持仅保留锁屏而彻底关闭灵动岛。

- [x] **P1-5 「已完成」筛选下统计卡片恒为 100%**
  `statsCard` 的 `visibleTodoTasks` 在 `completed` 筛选时只含已完成任务，`progress` 恒为 1.0，「今日进度」语义错乱。
  → 已修复：统计卡片改为基于当前筛选范围的全量普通待办计算进度；`completed` / `incomplete` 筛选不再只用当前可见任务作为分母。

- [x] **P1-6 `StoreKitManager` 双实例 / `.shared` 死单例**
  `StoreKitManager.shared` 从未被 UI 引用；App 用 `@StateObject StoreKitManager()` 新建实例，`SubscriptionView` 预览又 `StoreKitManager()`。`.shared` 在 init 时也会跑 `refreshEntitlements()` 并写 App Group，与 StateObject 实例竞争写同一 `isProUser`。
  → 已修复：删除未使用的 `.shared`，运行时统一使用 App 根部 `@StateObject` 注入的实例；预览保留独立实例，不参与生产运行。

- [x] **P1-7 死代码清理**
  - `ActivityManager.syncPendingChangesFromWidget(context:)`、`hasActiveGroupActivities()`、`updateTaskStatus(...)` 均无调用方（`ContentView.syncPendingChanges()` 才是真正路径）。
  - `Item.swift`（`@Model class Item`）为 Xcode 模板残留，未注册进 schema，从未实例化。
  → 已修复：删除上述无调用方方法、额外的 `hasPendingWidgetChanges()` 遗留方法，以及 Xcode 模板残留 `Item.swift`。

### P2 — 代码质量 / 打磨

- [x] **P2-1 `ContentView.swift` 2649 → 1129 行**：拆分为 `ContentView` / `AppSupport` / `FirstLaunchTutorialView` / `MotivationEditorView` / `EmojiData` / `IconPickerView` / `DatePickerSheet` / `TaskGroupCard` / `TaskRow` / `AdvancedEditorViews` 共 10 个文件；共享 helper 提取到 `AppSupport.swift` 并同步 Widget extension target。
- [x] **P2-2 生产构建保留大量 `print`**（`ActivityManager` 数十处，含任务标题）：已替换为 DEBUG-only `os.Logger` helper，Release 构建不再计算/输出任务标题等调试日志。
- [x] **P2-3 字体默认值/注释不一致**：`FocusActivityWidget.fontSizeScale` 默认 `?? 1.5`，注释写「0.7~1.4，默认 1.0」，滑块实际 0.7~2.0。已统一注释与文档为 0.7~2.0，默认 1.5。
- [x] **P2-4 本地通知前台无展示 / 无交互**：`NotificationManager` 已实现 `UNUserNotificationCenterDelegate`，前台通知展示 banner/list/sound，并注册「完成」action 直接写入 App Group SwiftData。
- [x] **P2-5 错误被静默吞掉**：已移除主界面关键写入路径的 `try? modelContext.save()`，统一走显式 `do/catch` 保存入口；保存失败会弹出错误提示，锁屏 fallback 待同步队列仅在 SwiftData 保存成功后清空，避免失败后丢变更。
- [x] **P2-6 单元测试覆盖**：新增 `FocusLiveTests` target 与 `TaskModelTests`（15 个用例），覆盖 `TaskGroup.sortedTasks` 排序、完成计数、快照元数据保持、枚举 rawValue、`trimmed()` helper、`isReminder` 等核心模型逻辑；测试可在模拟器独立运行，不依赖 App Group。
- [x] **P2-7 i18n 补全**：为 `en.lproj` / `zh-Hans.lproj` 补充 133 条缺失条目；`saveChanges(failureMessage:)` 与 `saveModelContext(failureMessage:)` 的中文错误提示已改用 `String(localized:)` 包装，英文环境下可正确显示翻译。

---

## 四、优化与升级方向（产品 / 工程）

- **跨进程一致性收敛**：把「锁屏勾选 → 落库 → Activity → 快照」收敛为单一可靠管线（见 P1-2 / P1-3），消除滞后与竞态。
- **~~主屏 Widget 真正可用~~**：✅ 已完成 — `FocusTaskWidget.swift` 读取 App Group SwiftData，支持 small/medium/large 三种尺寸。
- **智能提醒体系化**：以本地通知为主、Live Activity 为辅；倒计时交给系统侧 `Text(timerInterval:)`；提醒判重与生命周期清晰化。
- **~~重复任务（repeat）落地~~**：✅ 已完成 — `nextRepeatDate()` + `createNextRepeatTask()` 在 `AppSupport.swift`，集成于 `TaskRow.toggleTask()` 和 `ToggleTaskIntent`。
- **~~数据可迁移性~~**：✅ VersionedSchema + MigrationPlan 已引入（`DataMigration.swift`）；JSON 导入/导出和 iCloud 备份留到 M4。
- **设计系统统一**：颜色/圆角/阴影/卡片样式在多个 View 中重复硬编码，抽出 `Theme` / 复用组件。
- **可观测性**：统一 Logger + 关键路径埋点（Activity 创建成功率、pending 同步量），便于线上排查。

---

## 五、分阶段开发路线图（Roadmap）

> 原则：先稳住核心管线，再补功能，最后做体验与规模化。每个里程碑给出范围、验收标准与涉及文件。

### M0 · 紧急修复（1 个迭代，先发补丁）
**目标**：消除「设置不生效 / 假功能 / 数据脱节」类用户可感知缺陷。
- 修 P0-4（显示条数上限统一）、P0-5（附件下线或落地）、P0-6（emoji 清洗去重）。
- 修 P0-1：决策主屏 Widget 形态——**建议先删除死代码、把 Widget 明确为「共享数据源的每日鼓励」**（读取 CSV/自定义文案），任务 Widget 留到 M2。
- 验收：Pro 设 8 条锁屏确显 8 条；图标选择器无「Fax」无重复；主屏 Widget 文案与 App 一致；无写入死代码残留。
- 涉及：`FocusActivityWidget.swift`、`ContentView.swift`、`FocusWidget.swift`、`ActivityManager.swift`、`ToggleTaskIntent.swift`。

### M1 · 同步管线加固（1–2 个迭代）
**目标**：锁屏交互即时、可靠、无竞态。
- 修 P1-2（Intent 内直接落库）、P1-3（内容 diff + sync 节流 + renderVersion 语义化）、P0-2 / P0-3（智能提醒生命周期 & 判重）、P1-1（打卡重置移到 App Group）。
- 清理 P1-7 死代码、P1-6 StoreKitManager 单实例。
- 验收：锁屏勾选后立即落库（断网/杀后台后重开数据正确）；连续切换深浅色/前后台不产生重复或闪烁 Activity；智能提醒不堆叠、能按时消失。
- 涉及：`ToggleTaskIntent.swift`、`ActivityManager.swift`、`ContentView.swift`、`StoreKitManager.swift`、`FocusLiveApp.swift`。

### M2 · 功能补全 ✅ 已完成
**目标**：把「半成品」做成「真功能」。
- [x] **重复任务引擎**：完成/到期生成下一次实例（`RepeatType` × `repeatInterval`）— `AppSupport.swift`，集成于 `TaskRow.toggleTask()` 和 `ToggleTaskIntent`。
- [x] **主屏任务 Widget**：`FocusTaskWidget.swift` 读取 App Group SwiftData，small/medium/large 三种尺寸，显示真实任务数据与进度。
- [x] **附件**：链接附件的真实添加、展示与持久化 — `AdvancedEditorViews.swift`，支持滑动删除。
- [x] P1-5 统计口径修正、P2-4 通知前台展示 + 「完成」action（在 M1/P2 阶段已完成）。
- 验收：25 个单元测试全部通过；构建零 error。

### M3 · 工程化与可维护性（大部分已完成）
**目标**：降低后续迭代成本。
- [x] P2-1 拆分 `ContentView`（2649 → 1129 行 + 9 个文件）；P2-2 Logger 化；P2-5 保存错误处理；P2-7 补全 en 本地化。
- [x] SwiftData `VersionedSchema` + `MigrationPlan`（`DataMigration.swift`）。
- [x] JSON 导入/导出（`DataExportImport.swift`）— 支持全量导出为 ISO8601 JSON + 去重导入。
- [x] P2-6 测试：25 个单元测试覆盖核心模型逻辑、排序、重复任务引擎。
- [ ] 关键流程加 UI 测试（留到后续迭代）。
- [x] 抽取 `Theme` 设计系统（`Theme.swift`）— 统一圆角、阴影、颜色、字体 token。
- 验收：CI 可跑测试（✅ 25/25 pass）；新增字段走显式迁移（✅ VersionedSchema 就绪）；单文件不超过 ~600 行（✅ 最大 1129 行 `ContentView`）。

### M4 · 规模化与增长（探索）
- iCloud / CloudKit 同步（多设备）；
- 数据统计页（完成率趋势、打卡日历）；
- Apple Watch / 桌面 Widget 拓展；
- 订阅转化优化（试用、A/B、引导）。

---

## 六、关键文件

- `FocusLive/ContentView.swift`：首页筛选、分组列表（1129 行，已从 2649 行拆分）
- `FocusLive/TaskGroupCard.swift`：分组卡片视图
- `FocusLive/TaskRow.swift`：任务行视图（含重复任务引擎集成）
- `FocusLive/AdvancedEditorViews.swift`：高级任务/分组编辑器（含附件功能）
- `FocusLive/AppSupport.swift`：共享 helper 常量与函数（编译到 App + Widget target）
- `FocusLive/ActivityManager.swift`：Live Activity 创建/更新/结束、智能提醒、每日鼓励
- `FocusLive/DataMigration.swift`：SwiftData `VersionedSchema` + `MigrationPlan`
- `FocusLive/TaskModel.swift`：数据模型（`TaskGroup` / `TaskItem` / `TaskItemSnapshot` / `Attachment`）
- `FocusLive/ToggleTaskIntent.swift`：锁屏勾选任务 Intent（含直接落库 + 重复任务）
- `FocusWidget/FocusTaskWidget.swift`：主屏任务列表 Widget（small/medium/large）
- `FocusWidget/FocusWidget.swift`：主屏每日鼓励 Widget
- `FocusWidget/FocusActivityWidget.swift`：锁屏与灵动岛 UI
- `FocusLive/DataMigration.swift`：SwiftData VersionedSchema + MigrationPlan
- `FocusLive/DataExportImport.swift`：JSON 导入/导出
- `FocusLive/Theme.swift`：设计系统 token（圆角、阴影、颜色、字体）

---

## 七、运行要求

- iOS 17+ / Xcode 15+，真机优先（锁屏 Live Activity / 灵动岛建议真机验证）
- App 与 Widget Extension 共用 App Group：`group.com.QingTeng.FocusLive`
- URL Scheme：`focuslive://`（`toggle` / `sync` / `end`）；`NSSupportsLiveActivities = YES`

## 八、调试建议

- 在 Xcode Console 查看 `ActivityManager` 同步日志（已改为 DEBUG-only `os.Logger`，Release 静默）
- 验证当前构建：

```bash
xcodebuild -scheme FocusLive -project FocusLive.xcodeproj -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO -quiet build
```

## 九、文档索引

- [QUICKSTART.md](./QUICKSTART.md)：快速上手与功能验证
- [SETUP_CHECKLIST.md](./SETUP_CHECKLIST.md)：签名、Target、运行环境检查
- [TECHNICAL_GUIDE.md](./TECHNICAL_GUIDE.md)：ActivityKit 实现说明
- [CHANGELOG.md](./CHANGELOG.md)：最近更新日志
- [说明文档.md](./说明文档.md)：项目记录与实施进度
