# 🚀 快速开始指南

## 1分钟上手 FocusLive

### 第一步：配置项目（5分钟）

#### 1. 打开 Xcode 项目

```bash
cd /Users/zhaohaowei/Documents/FocusLive
open FocusLive.xcodeproj
```

#### 2. 配置共享文件 Target Membership ⚠️ **关键步骤**

**必须将以下两个文件同时添加到两个 Target：**

**FocusAttributes.swift:**
1. 在项目导航器中选中 `FocusLive/FocusAttributes.swift`
2. 打开右侧 File Inspector（文件检查器）
3. 在 "Target Membership" 中：
   - ✅ 勾选 **FocusLive**
   - ✅ 勾选 **FocusWidget**

**TaskModel.swift:**
1. 在项目导航器中选中 `FocusLive/TaskModel.swift`
2. 打开右侧 File Inspector
3. 在 "Target Membership" 中：
   - ✅ 勾选 **FocusLive**
   - ✅ 勾选 **FocusWidget**

#### 3. 验证 App Groups（已配置）

确认 `FocusLive.entitlements` 和 `FocusWidgetExtension.entitlements` 都包含：

```xml
<key>com.apple.security.application-groups</key>
<array>
    <string>group.zhaohaowei.FocusLive</string>
</array>
```

✅ **已自动配置，无需修改**

#### 4. 连接真机

- 使用数据线连接 iPhone（iOS 17.0+）
- 在 Xcode 顶部选择你的设备
- **不要使用模拟器**（Live Activities 支持有限）

### 第二步：首次运行（2分钟）

#### 1. 构建并运行

```
点击 Xcode 左上角的 ▶️ 按钮
或按快捷键 ⌘R
```

#### 2. 添加示例数据

App 启动后：
1. 看到 "还没有任务分组" 提示
2. 点击 **"添加示例数据"** 按钮
3. 系统自动创建 3 个分组：
   - 💼 工作（4个任务）
   - 🌙 晚自修（3个任务）
   - ❤️ 生活（3个任务）

#### 3. 观察控制台日志

在 Xcode Console 中应该看到：

```
🔄 同步 Live Activities...
   运行中的 Activities: 0 个
   当前分组数: 3 个
   ✅ 为分组 '工作' 创建新 Activity
      ✨ Activity 已创建，ID: ...
   ✅ 为分组 '晚自修' 创建新 Activity
      ✨ Activity 已创建，ID: ...
   ✅ 为分组 '生活' 创建新 Activity
      ✨ Activity 已创建，ID: ...
✅ 同步完成！
```

✅ **如果看到这些日志，说明 Live Activities 已成功创建！**

### 第三步：锁屏测试（1分钟）

#### 1. 锁定屏幕

按 iPhone 侧边按钮锁屏

#### 2. 观察 Live Activities

你应该看到：

```
┌─────────────────────────────┐
│ 💼 工作            2/4      │
│ ▓▓▓▓▓▓▓▓░░░░░░░░            │
│ ○ 完成项目方案              │
│ ○ 团队会议                  │
│ ○ 代码审查                  │
└─────────────────────────────┘

┌─────────────────────────────┐
│ 🌙 晚自修          1/3      │
│ ▓▓▓▓░░░░░░░░░░░░            │
│ ○ 写英语作业                │
│ ○ 物理练习题                │
└─────────────────────────────┘

┌─────────────────────────────┐
│ ❤️ 生活            1/3      │
│ ▓▓▓▓░░░░░░░░░░░░            │
│ ○ 买菜                      │
│ ○ 健身                      │
└─────────────────────────────┘
```

#### 3. 测试交互

1. **点击任意任务前的圆圈 ○**
2. 圆圈变成 ✓（打勾）
3. 进度条实时更新
4. 任务文字变灰并添加删除线

### 第四步：测试灵动岛（iPhone 14 Pro+）

如果你的设备支持灵动岛：

#### 收起状态（Compact）

```
[💼] ··· [-2]
```
- 左侧：分组图标
- 右侧：剩余任务数

#### 展开状态（Expanded）

长按灵动岛查看：

```
┌─────────────────────────────┐
│ 💼 工作            2/4      │
├─────────────────────────────┤
│ 下一个任务                  │
│ 完成项目方案                │
│                             │
│ ┌─────────────────────────┐ │
│ │  ✓ 标记完成             │ │
│ └─────────────────────────┘ │
└─────────────────────────────┘
```

点击 "标记完成" 按钮即可完成任务。

### 第五步：测试自动同步（1分钟）

#### 在 App 内操作

1. 解锁 iPhone
2. 打开 FocusLive App
3. 点击任意任务的圆圈按钮
4. 再次锁屏

✅ **锁屏上的 Live Activity 应该已自动更新**

#### 添加新分组

1. 在 App 中点击右上角 "+" 按钮
2. 自动创建 "新分组 4"
3. 锁屏（可能因为系统限制只显示前 2 个）

#### 删除分组

1. 左滑分组卡片删除
2. 观察控制台日志：
   ```
   🔄 同步 Live Activities...
   ❌ 分组 ID '...' 已删除，结束对应 Activity
      🛑 Activity 已结束
   ```

## ⚠️ 常见问题

### Q1: 锁屏上没有显示 Live Activities

**检查清单：**
- [ ] 是否使用真机（模拟器不支持）
- [ ] iOS 版本 ≥ 17.0
- [ ] Info.plist 中 `NSSupportsLiveActivities` = `true` ✅ 已配置
- [ ] App 通知权限已开启
- [ ] 观察控制台是否有错误日志

### Q2: 编译错误 "Cannot find type 'FocusAttributes'"

**解决方案：**
1. 选中 `FocusAttributes.swift`
2. 在右侧 File Inspector 中
3. 勾选 "Target Membership" → **FocusWidget**

（参考上面的"配置共享文件"步骤）

### Q3: 点击锁屏任务没有反应

**可能原因：**
1. Intent 执行延迟（等待 1-2 秒）
2. Widget Extension 崩溃（查看控制台）
3. `ToggleIntent.swift` 没有正确添加到 FocusWidget Target

### Q4: 只显示 2 个 Live Activities

**这是正常的！**
- iOS 17 限制每个 App 最多 2 个同时运行的 Activity
- 需要优化逻辑让用户选择优先显示哪些分组

## 🎯 下一步

### 功能测试

- [ ] 在 App 内添加/删除任务
- [ ] 在锁屏上标记任务完成
- [ ] 切换深色/浅色模式
- [ ] 测试多个分组
- [ ] 长时间运行（电池测试）

### 自定义开发

1. **修改任务图标**
   - 编辑 `TaskModel.swift` 中的 `iconName`
   - 使用 SF Symbols 浏览器选择图标

2. **调整 UI 样式**
   - 编辑 `FocusActivityWidget.swift`
   - 修改颜色、字体、布局

3. **添加新功能**
   - 参考 [README.md](README.md) 的"扩展方向"
   - 查看 [TECHNICAL_GUIDE.md](TECHNICAL_GUIDE.md) 的技术细节

## 📚 文档索引

- **[README.md](README.md)** - 项目概述和架构说明
- **[TECHNICAL_GUIDE.md](TECHNICAL_GUIDE.md)** - ActivityKit 深度技术解析
- **[SETUP_CHECKLIST.md](SETUP_CHECKLIST.md)** - 完整配置检查清单

## 🆘 需要帮助？

如果遇到问题：

1. 查看控制台日志
2. 对照 [SETUP_CHECKLIST.md](SETUP_CHECKLIST.md) 检查配置
3. 阅读 [TECHNICAL_GUIDE.md](TECHNICAL_GUIDE.md) 了解原理
4. 在 GitHub 提 Issue（附上日志截图）

---

**祝你开发顺利！🎉**

如果项目对你有帮助，别忘了给个 Star ⭐
