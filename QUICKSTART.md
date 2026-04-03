# 快速开始指南

## 1. 打开项目

```bash
cd /Users/zhaohaowei/Documents/FocusLive
open FocusLive.xcodeproj
```

## 2. 运行前确认

- 选择真机优先
- 如果只是开发页面和普通业务逻辑，模拟器也可以
- App 和 Widget Extension 的 App Group 要一致：
  `group.com.QingTeng.FocusLive`

## 3. 第一次运行

1. 点击 Xcode 左上角 `Run`
2. 首次启动会自动弹出 `新手教程`
3. 在教程里完成以下设置：
   - 调整锁屏字体大小
     推荐默认：`150%`
   - 试看实时活动预览
   - 选择是否显示已完成事项
   - 选择是否显示每日鼓励
   - 选择透明 / 不透明卡片背景
4. 完成教程后点击 `开始使用`

## 4. 创建第一个分组

1. 点击首页右上角 `+`
2. 菜单会直接从按钮附近展开
3. 可选择：
   - `传统待办事项`
   - `每日打卡`
   - `提醒事项`
4. 添加任务后保存

## 5. 验证首页行为

- 顶部筛选顺序应为：
  `全部` → `未完成` → `已完成` → `隐私空间`
- 默认进入首页时应落在 `全部`
- `全部` 页底部应显示 `每日鼓励` 卡片
- 每日鼓励支持：
  - `换一句`
  - `自定义`

## 6. 验证锁屏实时活动

1. 添加一个有未完成事项的分组
2. 锁屏查看 Live Activity
3. 确认：
   - 标题和任务内容字号同步变化
   - 已完成事项按设置决定是否显示
   - 若显示已完成事项，应带横线标记
   - 透明 / 不透明背景符合设置
4. 点击锁屏任务前的圆圈，确认状态能更新并回写到 App

## 7. 验证灵动岛

如果设备支持灵动岛：

- 收起状态可以看到图标和剩余信息
- 长按后可以看 Expanded 内容
- 如果不想继续显示，可直接左滑灵动岛临时关闭

## 8. 常用设置入口

进入 `我的 > 锁屏卡片设置` 可继续调整：

- 锁屏显示分组
- 显示条数
- 卡片背景：透明 / 不透明
- 任务字体大小
- 任务字体颜色
- 显示已完成事项
- 每日鼓励开关

## 9. 构建验证命令

```bash
xcodebuild -scheme FocusLive -project FocusLive.xcodeproj -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO -quiet build
```

## 10. 常见问题

### 锁屏没有显示实时活动

- 确认使用真机
- 确认有未完成事项
- 确认系统允许 Live Activities 和通知
- 确认签名和 App Group 配置无误

### 锁屏点击任务后没有回写

- 先回到 App 前台
- 检查 Console 是否有 `pendingTaskChanges` 同步日志

### 只想先看 UI

- 可以直接使用模拟器
- 但灵动岛、锁屏、签名、通知仍建议真机验证

## 文档入口

- [README.md](./README.md)
- [SETUP_CHECKLIST.md](./SETUP_CHECKLIST.md)
- [TECHNICAL_GUIDE.md](./TECHNICAL_GUIDE.md)
- [CHANGELOG.md](./CHANGELOG.md)
