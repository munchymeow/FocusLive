# FocusLive

FocusLive 是一个基于 iOS Live Activities 的待办事项应用。任务分组会自动同步到锁屏和灵动岛，用户可以在锁屏上直接勾选完成，并把结果回写到 App。

## 当前功能概览

- 首页筛选顺序：`全部`、`未完成`、`已完成`、`隐私空间`
- 默认首页入口：`全部`
- 首次启动：进入交互式新手教程，可直接设置字体大小、已完成显示、每日鼓励和卡片背景
- 添加分组：通过右上角 `+` 按钮下拉菜单创建 `传统待办事项`、`每日打卡`、`提醒事项`
- 锁屏卡片：支持透明 / 不透明背景、已完成事项显示开关、字体大小调节、字体颜色自定义
- 每日鼓励：可在首页 `全部` 页底部显示，支持随机刷新和自定义内容，并同步到锁屏鼓励卡片
- 灵动岛：支持 Compact / Expanded 展示；如果不想继续显示，可直接左滑灵动岛临时关闭

## 首次使用流程

1. 打开 App，首次启动会自动弹出新手教程
2. 在教程中调整锁屏字体大小
   推荐默认：`150%`
3. 预览实时活动样式，并选择是否显示已完成事项、每日鼓励、是否使用不透明卡片背景
4. 完成教程后，点击右上角 `+` 创建第一个分组
5. 添加任务后，有未完成事项的分组会自动同步到锁屏 Live Activity

## 日常使用

### App 内

- 点击右上角 `+` 新建分组
- 点击标题直接编辑
- 长按任务进入高级设置
- 在 `我的 > 锁屏卡片设置` 中调整实时活动显示策略

### 锁屏 / 灵动岛

- 点击任务前的圆圈可以直接标记完成
- 已完成事项可选保留，并以横线标记
- 背景支持透明 / 不透明两种模式
- 标题字号与任务内容字号会同步变化
- 灵动岛支持系统手势左滑关闭

## 关键文件

- `FocusLive/ContentView.swift`：首页筛选、分组列表、首次启动教程、每日鼓励卡片
- `FocusLive/ActivityManager.swift`：Live Activity 创建、更新、结束、每日鼓励同步
- `FocusLive/LiveActivitySettingsView.swift`：锁屏卡片设置
- `FocusLive/TaskModel.swift`：数据模型（`TaskGroup`、`TaskItem`、`TaskItemSnapshot`）
- `FocusLive/FocusAttributes.swift`：Activity `Attributes` 与 `ContentState`
- `FocusLive/ToggleTaskIntent.swift`：锁屏勾选任务 Intent
- `FocusWidget/FocusActivityWidget.swift`：锁屏与灵动岛 UI
- `FocusWidget/FocusWidget.swift`：主屏 Widget

## 运行要求

- iOS 17+
- Xcode 15+
- 真机优先
  模拟器可用于 UI 和大部分业务逻辑开发，但锁屏 Live Activity / 灵动岛仍建议真机验证
- App 与 Widget Extension 需要使用同一个 App Group：
  `group.com.QingTeng.FocusLive`

## 调试建议

- 在 Xcode Console 查看 `ActivityManager` 同步日志
- 如需验证当前构建，可执行：

```bash
xcodebuild -scheme FocusLive -project FocusLive.xcodeproj -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO -quiet build
```

## 文档索引

- [QUICKSTART.md](./QUICKSTART.md)：快速上手与功能验证
- [SETUP_CHECKLIST.md](./SETUP_CHECKLIST.md)：签名、Target、运行环境检查
- [TECHNICAL_GUIDE.md](./TECHNICAL_GUIDE.md)：ActivityKit 实现说明
- [CHANGELOG.md](./CHANGELOG.md)：最近更新日志
- [说明文档.md](./说明文档.md)：项目记录与实施进度
