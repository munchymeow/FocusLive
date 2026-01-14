# FocusLive 配置检查清单

## 📋 运行前必须检查的配置

### 1. Xcode 项目设置

#### ✅ Target 配置

**主 App (FocusLive):**
- [ ] Deployment Target: iOS 17.0 或更高
- [ ] Bundle Identifier: 确保唯一（如 `com.zhaohaowei.FocusLive`）
- [ ] Signing & Capabilities: 
  - [ ] 添加 **App Groups** capability
  - [ ] Group Name: `group.zhaohaowei.FocusLive`（需与代码中一致）

**Widget Extension (FocusWidget):**
- [ ] Deployment Target: iOS 17.0 或更高
- [ ] Bundle Identifier: 必须是主 App 的子路径（如 `com.zhaohaowei.FocusLive.FocusWidget`）
- [ ] Signing & Capabilities:
  - [ ] 添加 **App Groups** capability
  - [ ] Group Name: `group.zhaohaowei.FocusLive`（必须与主 App 完全一致）

#### ✅ Info.plist 配置

**FocusLive/Info.plist:**
```xml
<key>NSSupportsLiveActivities</key>
<true/>
```

**FocusWidget/Info.plist:**
- [ ] 确保 `NSExtension` 配置正确
- [ ] `NSExtensionPointIdentifier` = `com.apple.widgetkit-extension`

### 2. 文件引用检查

确保以下文件在正确的 Target 中：

**FocusLive Target 应包含：**
- [x] FocusLiveApp.swift
- [x] ContentView.swift
- [x] TaskModel.swift
- [x] FocusAttributes.swift
- [x] ActivityManager.swift

**FocusWidget Target 应包含：**
- [x] FocusWidgetBundle.swift
- [x] FocusActivityWidget.swift
- [x] FocusWidgetLiveActivity.swift
- [x] ToggleIntent.swift
- [x] FocusAttributes.swift ⚠️ **重要：需要同时添加到两个 Target**
- [x] TaskModel.swift ⚠️ **重要：需要同时添加到两个 Target**

**检查方法：**
1. 选中文件（如 `FocusAttributes.swift`）
2. 打开右侧 File Inspector
3. 在 "Target Membership" 中勾选 **FocusLive** 和 **FocusWidget**

### 3. 共享文件配置

以下文件必须同时添加到两个 Target：

```
✅ FocusAttributes.swift    # Live Activity 数据结构
✅ TaskModel.swift          # TaskItemSnapshot 用于 Widget
```

**如果没有正确配置，会出现以下错误：**
```
Cannot find type 'FocusAttributes' in scope
Cannot find type 'TaskItemSnapshot' in scope
```

### 4. Entitlements 文件

**FocusLive/FocusLive.entitlements:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.zhaohaowei.FocusLive</string>
    </array>
</dict>
</plist>
```

**FocusWidgetExtension.entitlements:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.zhaohaowei.FocusLive</string>
    </array>
</dict>
</plist>
```

### 5. 编译错误排查

#### 常见错误 1: "Cannot find type 'FocusAttributes'"

**原因：** FocusAttributes.swift 没有添加到 FocusWidget Target

**解决方案：**
1. 选中 `FocusAttributes.swift`
2. 在右侧 File Inspector 中
3. 勾选 "Target Membership" → **FocusWidget**

#### 常见错误 2: "Value of type 'Activity<FocusAttributes>' has no member 'activities'"

**原因：** ActivityKit framework 未导入

**解决方案：**
在文件顶部添加：
```swift
import ActivityKit
```

#### 常见错误 3: "Type 'ToggleTaskIntent' does not conform to protocol 'LiveActivityIntent'"

**原因：** 缺少 `@MainActor` 或 `perform()` 方法签名不正确

**解决方案：**
确保 Intent 定义正确：
```swift
struct ToggleTaskIntent: LiveActivityIntent {
    @MainActor
    func perform() async throws -> some IntentResult {
        // ...
        return .result()
    }
}
```

### 6. 运行环境检查

#### ✅ 设备要求

- [ ] iOS 17.0 或更高版本
- [ ] 真机测试（模拟器对 Live Activities 支持有限）
- [ ] 支持 Dynamic Island 的设备（iPhone 14 Pro 及以上）用于测试灵动岛

#### ✅ 系统设置

运行前确保：
- [ ] 锁屏通知已开启
- [ ] App 通知权限已授予
- [ ] 未开启"专注模式"（可能影响 Live Activities 显示）

### 7. 首次运行步骤

1. **清理构建缓存**
   ```
   Product → Clean Build Folder (⇧⌘K)
   ```

2. **选择真机运行**
   - 不要使用模拟器（Live Activities 显示不完整）

3. **启动 App**
   - 点击 "添加示例数据" 按钮
   - 观察控制台日志：
     ```
     🔄 同步 Live Activities...
     ✅ 为分组 '工作' 创建新 Activity
     ✅ 为分组 '晚自修' 创建新 Activity
     ✅ 为分组 '生活' 创建新 Activity
     ```

4. **锁定屏幕**
   - 按侧边按钮锁屏
   - 应该看到 3 个实时活动卡片

5. **测试交互**
   - 点击任务前的圆圈按钮
   - 观察任务状态是否切换
   - 解锁 App，确认数据已同步

### 8. 调试技巧

#### 查看控制台日志

运行 App 时，在 Xcode Console 中应该看到：

```
🔄 同步 Live Activities...
   运行中的 Activities: 0 个
   当前分组数: 3 个
   ✅ 为分组 '工作' 创建新 Activity
      ✨ Activity 已创建，ID: 12345678-1234-1234-1234-123456789012
   ✅ 为分组 '晚自修' 创建新 Activity
      ✨ Activity 已创建，ID: 87654321-4321-4321-4321-210987654321
   ✅ 为分组 '生活' 创建新 Activity
      ✨ Activity 已创建，ID: ABCDEFAB-CDEF-CDEF-CDEF-ABCDEFABCDEF
✅ 同步完成！
```

#### 如果没有日志输出

1. 检查 `ActivityManager.swift` 中的 print 语句
2. 确认 `syncActivities()` 方法被调用
3. 在 ContentView 的 `onAppear` 中添加断点

#### 如果锁屏没有显示 Live Activity

1. **检查 Info.plist**
   - 确认 `NSSupportsLiveActivities` = `true`

2. **检查 Activity 数量限制**
   ```swift
   print("当前 Activity 数量: \(Activity<FocusAttributes>.activities.count)")
   ```
   - iOS 16.2+: 每个 App 最多 2 个同时运行的 Activity
   - 如果超过限制，旧的会被自动结束

3. **检查设备设置**
   - 设置 → 通知 → FocusLive → 允许通知

### 9. 性能测试

#### 内存占用

在 Xcode 中打开 Memory Debugger：
- 正常情况：< 50MB
- 如果 > 100MB，检查是否有内存泄漏

#### CPU 占用

- 更新 Activity 时应 < 10%
- 如果持续 > 50%，检查是否有死循环

### 10. 发布前检查

- [ ] 移除所有 `print()` 调试语句（或使用 `#if DEBUG`）
- [ ] 测试深色/浅色模式下的 UI
- [ ] 测试不同语言环境（本地化）
- [ ] 在多个设备上测试（iPhone 14 Pro, iPhone 15, iPad）
- [ ] 电池测试（Live Activities 是否过度耗电）
- [ ] 压力测试（创建/删除 10+ 个分组）

## 🚨 已知问题

1. **模拟器限制**
   - Live Activities 在模拟器上可能不显示或显示不完整
   - Dynamic Island 在非支持设备上无法测试

2. **Activity 数量限制**
   - iOS 16.2-16.4: 每个 App 最多 1 个
   - iOS 17.0+: 每个 App 最多 2 个
   - **本项目默认创建 3 个**，需要优化或让用户选择优先级

3. **更新延迟**
   - 锁屏交互可能有 1-2 秒延迟（系统限制）

## ✅ 配置完成确认

全部勾选后即可运行：

- [ ] Target 设置正确（iOS 17.0+）
- [ ] App Groups 已配置
- [ ] 共享文件已添加到两个 Target
- [ ] Info.plist 已配置 `NSSupportsLiveActivities`
- [ ] 使用真机测试
- [ ] 锁屏上能看到 Live Activities
- [ ] 点击交互正常工作
- [ ] 控制台有正确的日志输出

---

**如果遇到问题，请参考：**
- [README.md](README.md) - 项目概述
- [TECHNICAL_GUIDE.md](TECHNICAL_GUIDE.md) - 技术详解
- Apple Developer Forums - ActivityKit
