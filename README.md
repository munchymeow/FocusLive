# FocusLive (FocusScreen)  [去做](https://apps.apple.com/cn/app/%E5%8E%BB%E5%81%9A/id6757796328) ![1784696259872](image/README/1784696259872.png)

[English Documentation](./README_EN.md) | [中文说明文档](./README.md)

[![iOS 17.0+](https://img.shields.io/badge/iOS-17.0%2B-blue.svg?style=for-the-badge&logo=apple)](https://developer.apple.com/ios/)
[![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange.svg?style=for-the-badge&logo=swift)](https://swift.org)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-Framework-blueviolet.svg?style=for-the-badge&logo=swift)](https://developer.apple.com/xcode/swiftui/)
[![SwiftData](https://img.shields.io/badge/SwiftData-Persistence-red.svg?style=for-the-badge&logo=apple)](https://developer.apple.com/documentation/swiftdata)
[![ActivityKit](https://img.shields.io/badge/ActivityKit-Live--Activities-brightgreen.svg?style=for-the-badge&logo=apple)](https://developer.apple.com/documentation/activitykit)

> **FocusLive (去做)** 是一个基于 iOS Live Activities (实时活动) & Dynamic Island (灵动岛) 的待办事项应用。任务分组会自动同步到锁屏与灵动岛，用户可以在锁屏卡片上直接勾选完成，并将变更实时回写落库到 App。目前已经上架苹果应用商店。

---

> [!IMPORTANT]
> 本 README 维护了一份完整的 **架构设计**、**核心功能**、**已知问题修复记录** 与 **分阶段路线图**，作为项目唯一事实来源（Single Source of Truth）。
>
> [小红书介绍](http://xhslink.com/o/84AIEjDK1pY) × [Appstore](https://apps.apple.com/cn/app/%E5%8E%BB%E5%81%9A/id6757796328)

## 一、 当前核心功能 🚀

- 📌 **锁屏实时活动 & 灵动岛**：分组任务自动生成锁屏卡片，灵动岛支持 Compact / Expanded 展态；锁屏端即点即勾选，数据直接写库。
- 🤖 **AI 核心工作重心总结（Humanizer-zh 拟人化引擎）**：
  - 基于 OpenRouter API (`inclusionai/ling-2.6-flash`)，在 App 新增专属 **AI 总结 Tab**。
  - **全任务类型收集**：跨分组自动提取所有未完成的待办事项（含普通待办、每日打卡与提醒事项）。
  - **Humanizer-zh 拟人化 Prompt**：摒弃“以...为基调”、“同步推进”等公文假大空套话，像贴心私人管家一样自然连贯地为你梳理真实日常。
  - **任务指纹防重复机制**：仅在任务新增、删除、修改或勾选完成时比对哈希触发，视图加载与 Tab 切换自动复用持久化缓存，零浪费 API 调用。
  - **Pro 会员权益与 1 次设备试用**：支持设备 1 次免费体验，消费后无缝引导升级 Pro 会员。
- 🎨 **锁屏卡片定制与自适应排版**：
  - 透明 / 不透明背景模式、相册壁纸导入（`PhotosPicker`）与真实锁屏高保真预览。
  - **AI 卡片 140% 动态阶梯字号**：字号最高支持 140% 放大（18pt），根据字数智能缩放（18pt~12pt）并按字数灵活调整垂直 Padding（12pt~16pt），彻底杜绝锁屏文字截断溢出。
  - 11 色任务文本配色，全面支持自适应高对比度渲染。
- 🧪 **实验室 UI 风格库 (11 种大审美设计语言)**：
  - `Ambient Glass`（默认环境光晕真玻璃）
  - `Neo Brutal`（粗边框硬阴影高对比）
  - `Editorial`（杂志排版大标题衬线）
  - `Terminal`（极客命令行绿幕终端）
  - `Aurora`（极光渐变浮动光晕）
  - `Glassmorphism` / `Flat Receipt` / `Skeuomorphism` / `Material You` / `Minimal` / `Bold Stats`
- 📅 **任务形态与重复引擎**：支持 `传统待办事项`、`每日打卡`、`提醒事项` ；支持按日/周/月/年重复推算下一期实例。
- 🔒 **Face ID 隐私空间**：加密保护隐私分组与任务，主界面与锁屏自动掩码隐藏。
- 🔔 **智能提醒与通知**：计划时间到点倒计时系统级渲染，前台通知交互响应。
- 🛍️ **StoreKit 2 Pro 会员订阅**：
  - **月度会员**：`com.qingteng.FocusLive.pro.monthly`
  - **年度会员**：`com.qingteng.FocusLive.pro.yearly`
- ⚡ **快捷指令集成**：支持通过 Siri / App Intents 创建分组与快速添加待办。

---

## 二、 架构设计与关键文件 🛠️

```
+-------------------------------------------------------------------+
|                            App Group                              |
|                    group.com.QingTeng.FocusLive                   |
|                        (FocusLive.store)                          |
+---------------------------------+---------------------------------+
                                  |
            +---------------------+---------------------+
            |                                           |
            v                                           v
+-----------------------+                   +-----------------------+
|        主 App         |                   |   Widget Extension    |
| ([FocusLiveApp.swift](file:///Users/qingteng/Downloads/%E9%A1%B9%E7%9B%AE%E4%BB%A3%E7%A0%81_Projects/%E6%88%91%E7%9A%84%E5%88%B6%E4%BD%9C/FocusLive/FocusLive/FocusLive/FocusLiveApp.swift))  |                   |  ([FocusWidgetBundle.swift](file:///Users/qingteng/Downloads/%E9%A1%B9%E7%9B%AE%E4%BB%A3%E7%A0%81_Projects/%E6%88%91%E7%9A%84%E5%88%B6%E4%BD%9C/FocusLive/FocusLive/FocusWidget/FocusWidgetBundle.swift))  |
+-----------------------+                   +-----------------------+
|  SwiftUI Views        |                   |  LockScreen Widget    |
|  ActivityManager      |                   |  Dynamic Island       |
|  StoreKitManager      |                   |  HomeScreen Widget    |
+-----------------------+                   +-----------------------+
            ^                                           |
            |           锁屏点击交互触发                  |
            +-------------------------------------------+
                     ToggleTaskIntent (@MainActor)
```

| 层级                   | 关键文件                                                                                                                                                                                                                                            | 职责说明                                                                                                                                                                                                                                                                                   |
| :--------------------- | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **数据模型**     | [TaskModel.swift](file:///Users/qingteng/Downloads/项目代码_Projects/我的制作/FocusLive/FocusLive/FocusLive/TaskModel.swift)                                                                                                                         | `TaskGroup` / `TaskItem` (SwiftData `@Model`)，`TaskGroupSnapshot` 跨进程快照                                                                                                                                                                                                      |
| **版本迁移**     | [DataMigration.swift](file:///Users/qingteng/Downloads/项目代码_Projects/我的制作/FocusLive/FocusLive/FocusLive/DataMigration.swift)                                                                                                                 | SwiftData`VersionedSchema` + `MigrationPlan` 数据平滑迁移                                                                                                                                                                                                                              |
| **数据导入导出** | [DataExportImport.swift](file:///Users/qingteng/Downloads/项目代码_Projects/我的制作/FocusLive/FocusLive/FocusLive/DataExportImport.swift)                                                                                                           | ISO8601 JSON 全量导出与去重恢复                                                                                                                                                                                                                                                            |
| ** Live Activity **    | [ActivityManager.swift](file:///Users/qingteng/Downloads/项目代码_Projects/我的制作/FocusLive/FocusLive/FocusLive/ActivityManager.swift)                                                                                                             | 实时活动创建、哈希 diff 更新、智能提醒与防抖同步                                                                                                                                                                                                                                           |
| **锁屏交互**     | [ToggleTaskIntent.swift](file:///Users/qingteng/Downloads/项目代码_Projects/我的制作/FocusLive/FocusLive/FocusLive/ToggleTaskIntent.swift)                                                                                                           | `LiveActivityIntent`，锁屏直接落库 App Group 数据库                                                                                                                                                                                                                                      |
| **快捷指令**     | [ShortcutsIntents.swift](file:///Users/qingteng/Downloads/项目代码_Projects/我的制作/FocusLive/FocusLive/FocusLive/ShortcutsIntents.swift)                                                                                                           | App Intents 集成 Siri 与快捷指令                                                                                                                                                                                                                                                           |
| **组件 UI**      | [FocusActivityWidget.swift](file:///Users/qingteng/Downloads/项目代码_Projects/我的制作/FocusLive/FocusLive/FocusWidget/FocusActivityWidget.swift)                                                                                                   | 锁屏与灵动岛渲染 UI；[FocusTaskWidget.swift](file:///Users/qingteng/Downloads/项目代码_Projects/我的制作/FocusLive/FocusLive/FocusWidget/FocusTaskWidget.swift) 主屏待办 Widget                                                                                                             |
| **主 UI 视图**   | [ContentView.swift](file:///Users/qingteng/Downloads/项目代码_Projects/我的制作/FocusLive/FocusLive/FocusLive/ContentView.swift)                                                                                                                     | 首页筛选、分组卡片 ([TaskGroupCard.swift](file:///Users/qingteng/Downloads/项目代码_Projects/我的制作/FocusLive/FocusLive/FocusLive/TaskGroupCard.swift))、任务行 ([TaskRow.swift](file:///Users/qingteng/Downloads/项目代码_Projects/我的制作/FocusLive/FocusLive/FocusLive/TaskRow.swift)) |
| **实验室 UI**    | [LabView.swift](file:///Users/qingteng/Downloads/项目代码_Projects/我的制作/FocusLive/FocusLive/FocusLive/LabView.swift)                                                                                                                             | 实验室测试版 UI 控制器，11 种设计语言面板                                                                                                                                                                                                                                                  |
| **设置与订阅**   | [LiveActivitySettingsView.swift](file:///Users/qingteng/Downloads/项目代码_Projects/我的制作/FocusLive/FocusLive/FocusLive/LiveActivitySettingsView.swift)                                                                                           | 锁屏卡片设置页（含即时预览）；[SubscriptionView.swift](file:///Users/qingteng/Downloads/项目代码_Projects/我的制作/FocusLive/FocusLive/FocusLive/SubscriptionView.swift) 内购                                                                                                               |
| **设计系统**     | [Theme.swift](file:///Users/qingteng/Downloads/项目代码_Projects/我的制作/FocusLive/FocusLive/FocusLive/Theme.swift) / [AppSupport.swift](file:///Users/qingteng/Downloads/项目代码_Projects/我的制作/FocusLive/FocusLive/FocusLive/AppSupport.swift) | 全局 Design Tokens (圆角/阴影/颜色/字体/Logger/重复算法)                                                                                                                                                                                                                                   |

---

## 三、 问题审计与修复记录 📝

> 状态说明：`[x]` 表示已修复落地并经过校验。

> [!TIP]
> **最近关键修复记录**：
>
> - **锁屏 Live Activity 背景与实验室模式同步**：修复未开启实验室 UI 时锁屏偶尔残留 `glassmorphism` 紫色渐变背景的问题，未开启时固定回退为 `Ambient Glass` 默认模式；`renderVersion` 引入 `labEnabled` 状态指纹，样式切换零滞后。
> - **锁屏设置页优化与裁剪修复**：[LiveActivitySettingsView.swift](file:///Users/qingteng/Downloads/项目代码_Projects/我的制作/FocusLive/FocusLive/FocusLive/LiveActivitySettingsView.swift) 修复了最左侧“默认 (A)”选色圈边框与阴影被裁切的 Display Bug；重构为 4 个清晰模块并新增顶栏**实时交互预览卡片**。
> - ** StoreKit 2 订阅 Product ID 验证**：确认月度 `com.qingteng.FocusLive.pro.monthly` 与年度 `com.qingteng.FocusLive.pro.yearly` 配置正确。

### 缺陷修复列表 (P0 ~ P2)

- [X] **P0-1 主屏 Widget 数据同步**：`FocusTaskWidget.swift` 直接读取 App Group SwiftData，支持 Small / Medium / Large 三尺寸。
- [X] **P0-2 智能提醒生命周期**：移除长 `Task.sleep`；改用 `staleDate` + 系统级 `Text(timerInterval:)` 倒计时。
- [X] **P0-3 智能提醒判重**：智能提醒 ID 规范化为 `smart_reminder_<kind>_<sourceID>_<time>`，消除重复卡片堆叠。
- [X] **P0-4 锁屏显示条数一致性**：统一 Pro 8 条 / 免费 3 条裁剪上限。
- [X] **P0-5 附件功能**：在 [AdvancedEditorViews.swift](file:///Users/qingteng/Downloads/项目代码_Projects/我的制作/FocusLive/FocusLive/FocusLive/AdvancedEditorViews.swift) 实现真实的 URL 链接附件添加、持久化与左滑删除。
- [X] **P0-6 Emoji 去重与非法字符清理**：替换 `"Fax"` 为 `📠`，选择器去重并改用索引唯一 ID。
- [X] **P1-1 每日打卡重置**：重置日期存入 App Group，锁屏 Intent 落库前亦能触发自动重置。
- [X] **P1-2 锁屏勾选直接落库**：`ToggleTaskIntent` 运行于 `@MainActor`，直接写库 App Group SwiftData。
- [X] **P1-3 Live Activity 防抖与更新 Hash**：高频入口增加 250ms 防抖，`renderVersion` 改为纯样式哈希，避免频繁超预算。
- [X] **P1-4 灵动岛“关闭”文案**：修正为“最小化展示”，符合 iOS 系统行为。
- [X] **P1-5 统计口径修正**：`statsCard` 基于全量待办计算进度，解决已完成筛选下进度恒为 100% 问题。
- [X] **P1-6 StoreKitManager 单例**：移除多余 `.shared` 竞争写，统一根部 `@StateObject` 注入。
- [X] **P1-7 死代码清理**：移除模板 `Item.swift` 及无调用方同步代码。
- [X] **P2-1 ContentView 拆分**：将 2649 行 `ContentView.swift` 拆分为 10 个职责明确的模块文件。
- [X] **P2-2 DEBUG-only Logger**：替代日志中的 `print`，Release 静默。
- [X] **P2-5 错误处理**：显式 `do/catch` 包裹 ModelContext 保存并向用户反馈提示。
- [X] **P2-6 单元测试覆盖**：25 个用例覆盖模型、排序、算期逻辑 ([TaskModelTests.swift](file:///Users/qingteng/Downloads/项目代码_Projects/我的制作/FocusLive/FocusLive/FocusLiveTests/TaskModelTests.swift))。
- [X] **P2-7 本地化补全**：补全 `zh-Hans` / `en` 133 条国际化文案。

---

## 四、 运行环境与调试 🛠️

> [!NOTE]
> - **iOS 版本**：iOS 17.0+
> - **Xcode**：Xcode 15.0+
> - **App Group Identifier**：`group.com.QingTeng.FocusLive`
> - **URL Scheme**：`focuslive://` (`toggle` / `sync` / `end`)

### 命令行编译验证

```bash
xcodebuild -scheme FocusLive -project FocusLive.xcodeproj -derivedDataPath ./build -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO -quiet build
```

---

## 五、 文档索引 📂

- 📘 [TECHNICAL_GUIDE.md](./TECHNICAL_GUIDE.md)：ActivityKit 与跨进程架构指南
- ⚡ [QUICKSTART.md](./QUICKSTART.md)：快速上手与测试流程
- ✅ [SETUP_CHECKLIST.md](./SETUP_CHECKLIST.md)：环境部署与签名校验
- 📋 [CHANGELOG.md](./CHANGELOG.md)：版本更新日志
- 📄 [说明文档.md](./说明文档.md)：实施进度与项目说明


Designed By [QingTengStudio](https://qingtengstudio.com/) × [munchymeow](https://buymeacoffee.com/munchymeow)
