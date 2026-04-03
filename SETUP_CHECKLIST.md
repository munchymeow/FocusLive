# FocusLive 配置检查清单

## 1. 基础环境

- [ ] Xcode 15+
- [ ] iOS 17+
- [ ] 已选择真机进行锁屏 / 灵动岛验证
- [ ] 如果只是改 UI，可接受先用模拟器

## 2. Signing & Capabilities

### 主 App：`FocusLive`

- [ ] Bundle Identifier 唯一
- [ ] 已开启 `Automatically manage signing`
- [ ] 已添加 `App Groups`
- [ ] Group Name 为 `group.com.QingTeng.FocusLive`

### Widget Extension：`FocusWidgetExtension`

- [ ] Bundle Identifier 为主 App 的子路径
- [ ] 已开启 `Automatically manage signing`
- [ ] 已添加 `App Groups`
- [ ] Group Name 同样为 `group.com.QingTeng.FocusLive`

## 3. Info.plist / Entitlements

- [ ] `FocusLive/Info.plist` 已开启 `NSSupportsLiveActivities`
- [ ] `FocusLive/FocusLive.entitlements` 包含 App Group
- [ ] `FocusWidgetExtension.entitlements` 包含同一个 App Group

## 4. 关键文件检查

### 主 App 侧

- [ ] `FocusLive/ContentView.swift`
- [ ] `FocusLive/ActivityManager.swift`
- [ ] `FocusLive/LiveActivitySettingsView.swift`
- [ ] `FocusLive/ToggleTaskIntent.swift`
- [ ] `FocusLive/TaskModel.swift`
- [ ] `FocusLive/FocusAttributes.swift`

### Widget / Live Activity 侧

- [ ] `FocusWidget/FocusWidgetBundle.swift`
- [ ] `FocusWidget/FocusWidget.swift`
- [ ] `FocusWidget/FocusActivityWidget.swift`
- [ ] `FocusWidget/FocusWidgetLiveActivity.swift`
- [ ] `FocusWidget/AppIntent.swift`

### 共享模型

- [ ] `FocusLive/TaskModel.swift` 同时加入需要的 Target
- [ ] `FocusLive/FocusAttributes.swift` 同时加入需要的 Target

如果 Widget 侧找不到共享类型，优先检查 Target Membership。

## 5. 首次运行验证

- [ ] App 首次启动会自动弹出新手教程
- [ ] 教程中可直接调节字体大小
- [ ] 教程中可预览实时活动样式
- [ ] 教程中可设置常用开关
- [ ] 完成教程后进入首页默认 `全部`

## 6. 首页行为验证

- [ ] 筛选顺序为 `全部 / 未完成 / 已完成 / 隐私空间`
- [ ] 默认首页筛选是 `全部`
- [ ] `+` 按钮弹出的是按钮下方菜单，而不是底部弹层
- [ ] `全部` 页底部可显示 `每日鼓励`
- [ ] 每日鼓励支持刷新和自定义

## 7. 锁屏实时活动验证

- [ ] 有未完成事项的分组会自动创建 Live Activity
- [ ] 标题和任务内容字号同步变化
- [ ] 默认字体大小为 `150%`
- [ ] 背景模式支持透明 / 不透明
- [ ] 已完成事项可按设置决定是否显示
- [ ] 若显示已完成事项，锁屏上会用横线标记
- [ ] 锁屏点击任务后能回写到 App

## 8. 灵动岛验证

- [ ] 设备支持灵动岛（如 iPhone 14 Pro 及以上）
- [ ] Compact / Expanded 展示正常
- [ ] 左滑灵动岛可临时关闭显示

## 9. 设置页验证

进入 `我的 > 锁屏卡片设置`，确认：

- [ ] 锁屏显示分组可选
- [ ] 显示条数可调
- [ ] 背景透明 / 不透明切换生效
- [ ] 字体大小、字体颜色切换生效
- [ ] `显示已完成事项` 开关生效
- [ ] `每日鼓励` 开关会同时影响首页底部和锁屏鼓励卡片

## 10. 调试日志

运行时 Console 中建议看到类似日志：

```text
🔄 同步 Live Activities...
   运行中的 Activities: 0 个
   当前分组数: 1 个
   有效分组数(有未完成任务): 1 个
   ✅ 为分组 '晚自修' 创建新 Activity
✅ 同步完成！
```

如果没有日志：

- [ ] 确认 `ContentView.onAppear` 已触发
- [ ] 确认 `ActivityManager.syncActivities(groups:)` 已调用
- [ ] 检查是否没有可显示分组或没有未完成任务

## 11. 构建检查

```bash
xcodebuild -scheme FocusLive -project FocusLive.xcodeproj -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO -quiet build
```

- [ ] 构建通过

## 12. 发布前回归

- [ ] 浅色 / 深色模式检查
- [ ] 真机锁屏勾选任务回写检查
- [ ] 新手教程完整流程检查
- [ ] 每日鼓励刷新 / 自定义检查
- [ ] 中英文文案检查
- [ ] iPhone / iPad 基本布局检查
