//
//  LiveActivitySettingsView.swift
//  FocusLive
//
//  Created by 赵豪伟 on 2026/1/14.
//

import SwiftUI
import SwiftData
import PhotosUI

/// 实时活动展示设置视图（已优化结构与实时预览）
struct LiveActivitySettingsView: View {
    private static let appGroupID = "group.com.QingTeng.FocusLive"
    private static let displayCountKey = "liveActivityMaxCount"
    private static let opacityKey = "liveActivityBackgroundOpacity"
    private static let fontSizeKey = "liveActivityFontSize"
    private static let fontColorKey  = "liveActivityFontColor"
    private static let showCompletedTasksKey = "liveActivityShowCompletedTasks"
    private static let dynamicIslandEnabledKey = "liveActivityDynamicIslandEnabled"
    private static let proStatusKey = "isProUser"
    private static let allowedGroupIDsKey = "liveActivityAllowedGroupIDs"
    private static let smartReminderKey = "smartReminderEnabled"
    
    @AppStorage(Self.displayCountKey, store: UserDefaults(suiteName: Self.appGroupID))
    private var displayCount: Int = 4
    
    @AppStorage(Self.opacityKey, store: UserDefaults(suiteName: Self.appGroupID))
    private var backgroundOpacity: Double = 0.0

    /// 字体大小缩放比例 (0.7 ~ 2.0，默认 1.5)
    @AppStorage(Self.fontSizeKey, store: UserDefaults(suiteName: Self.appGroupID))
    private var fontSizeScale: Double = 1.5

    /// 字体颜色名称（white/black/yellow/orange/green/blue/red/pink/purple/cyan/default）
    @AppStorage(Self.fontColorKey, store: UserDefaults(suiteName: Self.appGroupID))
    private var fontColorName: String = "default"

    @AppStorage(Self.showCompletedTasksKey, store: UserDefaults(suiteName: Self.appGroupID))
    private var showCompletedTasks: Bool = true

    @AppStorage(Self.dynamicIslandEnabledKey, store: UserDefaults(suiteName: Self.appGroupID))
    private var dynamicIslandEnabled: Bool = false

    @AppStorage(Self.proStatusKey, store: UserDefaults(suiteName: Self.appGroupID))
    private var isProUser: Bool = false
    
    @AppStorage(Self.smartReminderKey, store: UserDefaults(suiteName: Self.appGroupID))
    private var smartReminderEnabled: Bool = false
    
    /// 每日鼓励开关
    @AppStorage("dailyMotivationEnabled", store: UserDefaults(suiteName: appGroupID))
    private var dailyMotivationEnabled: Bool = true

    /// AI 总结开关
    @AppStorage("aiSummaryEnabled", store: UserDefaults(suiteName: appGroupID))
    private var aiSummaryEnabled: Bool = false

    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var previewWallpaperImage: UIImage? = nil
    
    @Query private var taskGroups: [TaskGroup]
    @State private var selectedGroupIDs: Set<String> = []

    @Environment(\.colorScheme) private var colorScheme

    private enum LockScreenBackgroundMode: String, CaseIterable, Identifiable {
        case transparent
        case opaque

        var id: String { rawValue }

        var title: String {
            switch self {
            case .transparent: return "透明"
            case .opaque: return "不透明"
            }
        }
    }
    
    private var maxDisplayCount: Int {
        isProUser ? 8 : 3
    }

    private var backgroundMode: LockScreenBackgroundMode {
        get { backgroundOpacity >= 0.5 ? .opaque : .transparent }
        nonmutating set { backgroundOpacity = newValue == .opaque ? 1.0 : 0.0 }
    }

    private var backgroundModeBinding: Binding<LockScreenBackgroundMode> {
        Binding(
            get: { backgroundMode },
            set: {
                backgroundMode = $0
                syncLiveActivities()
            }
        )
    }

    /// 字体颜色选项列表（name, SwiftUI Color, 展示标签）
    private var colorOptions: [(name: String, color: Color, label: String)] {
        [
            ("default", Color(.systemGray5), "默认"),
            ("white",   .white,              "白"),
            ("black",   .black,              "黑"),
            ("yellow",  .yellow,             "黄"),
            ("orange",  .orange,             "橙"),
            ("green",   .green,              "绿"),
            ("blue",    .blue,               "蓝"),
            ("red",     .red,                "红"),
            ("pink",    .pink,               "粉"),
            ("purple",  .purple,             "紫"),
            ("cyan",    .cyan,               "青"),
        ]
    }

    /// 当前选中颜色的展示名
    private var fontColorDisplayName: String {
        colorOptions.first { $0.name == fontColorName }?.label ?? "默认"
    }

    private var selectableGroups: [TaskGroup] {
        taskGroups
            .filter { !($0.isPrivate ?? false) }
            .sorted { ($0.sortOrder ?? 0) < ($1.sortOrder ?? 0) }
    }

    /// 计算实时预览文本颜色
    private var previewTextColor: Color {
        switch fontColorName {
        case "white":  return .white
        case "black":  return .black
        case "yellow": return .yellow
        case "orange": return .orange
        case "green":  return .green
        case "blue":   return .blue
        case "red":    return .red
        case "pink":   return .pink
        case "purple": return .purple
        case "cyan":   return .cyan
        default:       return backgroundMode == .opaque ? (colorScheme == .dark ? .white : .black) : .white
        }
    }
    
    var body: some View {
        Form {
            // MARK: 1. 实时预览区
            Section {
                livePreviewCard
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)

                HStack {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label(previewWallpaperImage == nil ? "导入相册壁纸预览" : "更换壁纸", systemImage: "photo")
                            .font(.subheadline.weight(.medium))
                    }

                    if previewWallpaperImage != nil {
                        Spacer()
                        Button(role: .destructive) {
                            previewWallpaperImage = nil
                            UserDefaults(suiteName: Self.appGroupID)?.removeObject(forKey: "customWallpaperData")
                        } label: {
                            Label("清除壁纸", systemImage: "trash")
                                .font(.subheadline)
                        }
                    }
                }
            } header: {
                Label("锁屏实时卡片预览", systemImage: "eye.fill")
            } footer: {
                Text("可导入自定相册壁纸，测试卡片在真实锁屏背景下的透明度与文字可视度。")
            }

            // MARK: 2. 外观与展示配置
            Section {
                // 背景模式
                Picker("卡片背景", selection: backgroundModeBinding) {
                    ForEach(LockScreenBackgroundMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                // 显示条数
                Stepper(value: $displayCount, in: 1...maxDisplayCount) {
                    HStack {
                        Label("显示条数", systemImage: "list.number")
                        Spacer()
                        Text("\(displayCount) 条")
                            .foregroundStyle(.secondary)
                    }
                }

                if displayCount > 4 {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("建议 4 条以内，过多可能导致锁屏遮挡。")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }

                // 字体大小
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label("字体大小", systemImage: "textformat.size")
                        Spacer()
                        Text(String(format: "%.0f%%", fontSizeScale * 100))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Slider(value: $fontSizeScale, in: 0.7...2.0, step: 0.05) {
                        Text("字体大小")
                    } minimumValueLabel: {
                        Text("小").font(.caption2)
                    } maximumValueLabel: {
                        Text("大").font(.caption2)
                    }
                }

                // 任务字体颜色（已修复遮挡 bug）
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("任务字体颜色", systemImage: "paintpalette")
                        Spacer()
                        Text(fontColorDisplayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // 水平滚动颜色选盘：增加了左右/上下 Padding，防止“默认(A)”最左侧环形边框和阴影被裁剪
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(colorOptions, id: \.name) { option in
                                Button {
                                    fontColorName = option.name
                                    syncLiveActivities()
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(option.color)
                                            .frame(width: 32, height: 32)
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.accentColor, lineWidth: fontColorName == option.name ? 2.5 : 0)
                                            )
                                            .shadow(color: .black.opacity(0.12), radius: 2, x: 0, y: 1)

                                        if option.name == "default" {
                                            Text("A")
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundStyle(.primary)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 6)
                    }
                }

                // 完成状态与灵动岛
                Toggle(isOn: $showCompletedTasks) {
                    Label("显示已完成事项", systemImage: "checkmark.circle")
                }

                Toggle(isOn: $dynamicIslandEnabled) {
                    Label("显示灵动岛", systemImage: "sparkles")
                }
            } header: {
                Text("外观样式")
            } footer: {
                Text("iOS 不支持仅保留锁屏而彻底关闭灵动岛；关闭“显示灵动岛”后会自动最小化展示。")
            }

            // MARK: 3. 锁屏显示分组选择
            Section {
                if selectableGroups.isEmpty {
                    Text("暂无可显示的分组")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(selectableGroups) { group in
                        Toggle(isOn: bindingForGroup(group)) {
                            HStack(spacing: 10) {
                                GroupIcon(name: group.iconName, size: 14)
                                Text(group.title)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            } header: {
                Text("锁屏显示分组")
            } footer: {
                Text(isProUser ? "可自由勾选多分组显示在锁屏实时活动。" : "免费版最多可选择 1 个分组显示在锁屏实时活动。")
            }

            // MARK: 4. 高级拓展与 AI 总结
            Section(header: Text("高级功能")) {
                Toggle(isOn: $aiSummaryEnabled) {
                    Label("AI 总结锁屏卡片", systemImage: "sparkles")
                }
                .onChange(of: aiSummaryEnabled) { _, _ in
                    syncLiveActivities()
                }

                if isProUser {
                    Toggle(isOn: $smartReminderEnabled) {
                        Label("智能提醒", systemImage: "bell.badge")
                    }
                }

                Toggle(isOn: $dailyMotivationEnabled) {
                    Label("每日鼓励", systemImage: "quote.bubble")
                }
            }
        }
        .navigationTitle("锁屏卡片设置")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            normalizeSettings()
            loadSelectedGroupsIfNeeded()
            loadWallpaperImageIfNeeded()
            syncLiveActivities()
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    previewWallpaperImage = image
                    if let compressed = image.jpegData(compressionQuality: 0.7) {
                        UserDefaults(suiteName: Self.appGroupID)?.set(compressed, forKey: "customWallpaperData")
                    }
                }
            }
        }
        .onChange(of: isProUser) { _, _ in
            normalizeSettings()
            enforceSelectionLimit()
        }
        .onChange(of: taskGroups) { _, _ in
            syncSelectionWithGroups()
        }
        .onChange(of: displayCount) { _, _ in
            syncLiveActivities()
        }
        .onChange(of: fontSizeScale) { _, _ in
            syncLiveActivities()
        }
        .onChange(of: fontColorName) { _, _ in
            syncLiveActivities()
        }
        .onChange(of: showCompletedTasks) { _, _ in
            syncLiveActivities()
        }
        .onChange(of: dynamicIslandEnabled) { _, _ in
            syncLiveActivities()
        }
        .onChange(of: smartReminderEnabled) { _, newValue in
            if newValue {
                Task {
                    await NotificationManager.shared.requestPermission()
                }
            }
            syncLiveActivities()
        }
        .onChange(of: dailyMotivationEnabled) { _, _ in
            syncLiveActivities()
        }
        .onChange(of: backgroundOpacity) { _, _ in
            syncLiveActivities()
        }
        .onChange(of: selectedGroupIDs) { _, _ in
            syncLiveActivities()
        }
    }

    // MARK: - 实时模拟预览卡片

    private var livePreviewCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 自定义相册壁纸模组下的模拟锁屏时钟
            if previewWallpaperImage != nil {
                VStack(spacing: 2) {
                    Text("09:41")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 2)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 6)
                .padding(.bottom, 4)
            }

            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "checklist")
                        .font(.system(size: 13, weight: .bold))
                    Text("示例待办")
                        .font(.system(size: 13 * CGFloat(fontSizeScale), weight: .bold))
                }
                Spacer()
                Text("1/3")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(previewTextColor)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "circle")
                        .font(.system(size: 11))
                    Text("完成项目代码重构")
                        .font(.system(size: 12 * CGFloat(fontSizeScale), weight: .medium))
                        .lineLimit(1)
                }
                .foregroundStyle(previewTextColor)

                HStack(spacing: 6) {
                    Image(systemName: "circle")
                        .font(.system(size: 11))
                    Text("优化锁屏卡片设置页")
                        .font(.system(size: 12 * CGFloat(fontSizeScale), weight: .medium))
                        .lineLimit(1)
                }
                .foregroundStyle(previewTextColor)

                if showCompletedTasks {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.green)
                        Text("体验锁屏实时活动")
                            .font(.system(size: 12 * CGFloat(fontSizeScale), weight: .medium))
                            .strikethrough()
                            .lineLimit(1)
                    }
                    .foregroundStyle(previewTextColor.opacity(0.6))
                }
            }
        }
        .padding(14)
        .background {
            if backgroundMode == .opaque {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(colorScheme == .dark ? Color.black : Color.white)
                    .shadow(color: .black.opacity(0.1), radius: 6, y: 2)
            } else {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.25), lineWidth: 1)
                    )
            }
        }
        .padding(previewWallpaperImage != nil ? 14 : 0)
        .background {
            if let wallpaper = previewWallpaperImage {
                ZStack {
                    Image(uiImage: wallpaper)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                    Color.black.opacity(0.18)
                }
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
    }
    
    private func loadWallpaperImageIfNeeded() {
        if let data = UserDefaults(suiteName: Self.appGroupID)?.data(forKey: "customWallpaperData"),
           let image = UIImage(data: data) {
            previewWallpaperImage = image
        }
    }
    
    /// 规范化设置范围，防止异常值
    private func normalizeSettings() {
        if displayCount < 1 {
            displayCount = 1
        }
        if displayCount > maxDisplayCount {
            displayCount = maxDisplayCount
        }
        backgroundOpacity = backgroundOpacity >= 0.5 ? 1.0 : 0.0
    }

    /// 获取分组选择绑定
    private func bindingForGroup(_ group: TaskGroup) -> Binding<Bool> {
        Binding(
            get: { selectedGroupIDs.contains(group.id.uuidString) },
            set: { isOn in
                updateSelection(for: group, isSelected: isOn)
            }
        )
    }
    
    /// 初始化分组选择数据
    private func loadSelectedGroupsIfNeeded() {
        guard let defaults = UserDefaults(suiteName: Self.appGroupID) else { return }
        if let stored = defaults.array(forKey: Self.allowedGroupIDsKey) as? [String] {
            selectedGroupIDs = Set(stored)
        } else {
            selectedGroupIDs = Set(defaultSelectedGroupIDs())
            defaults.set(Array(selectedGroupIDs), forKey: Self.allowedGroupIDsKey)
        }
        enforceSelectionLimit()
    }
    
    /// 根据当前分组列表同步选择状态
    private func syncSelectionWithGroups() {
        let validIDs = Set(selectableGroups.map { $0.id.uuidString })
        selectedGroupIDs = selectedGroupIDs.intersection(validIDs)
        enforceSelectionLimit()
        persistSelectedGroupIDs()
    }
    
    /// 更新分组选择状态并同步
    private func updateSelection(for group: TaskGroup, isSelected: Bool) {
        let groupID = group.id.uuidString
        if isSelected {
            if isProUser {
                selectedGroupIDs.insert(groupID)
            } else {
                selectedGroupIDs = [groupID]
            }
        } else {
            selectedGroupIDs.remove(groupID)
        }
        enforceSelectionLimit()
        persistSelectedGroupIDs()
        syncLiveActivities()
    }
    
    /// 强制免费版分组选择上限
    private func enforceSelectionLimit() {
        guard !isProUser else { return }
        if selectedGroupIDs.count > 1 {
            if let firstID = selectedGroupIDs.first {
                selectedGroupIDs = [firstID]
            }
        }
        persistSelectedGroupIDs()
    }
    
    /// 获取默认选择分组列表
    private func defaultSelectedGroupIDs() -> [String] {
        let ids = selectableGroups.map { $0.id.uuidString }
        return isProUser ? ids : Array(ids.prefix(1))
    }
    
    /// 保存分组选择结果
    private func persistSelectedGroupIDs() {
        guard let defaults = UserDefaults(suiteName: Self.appGroupID) else { return }
        defaults.set(Array(selectedGroupIDs), forKey: Self.allowedGroupIDsKey)
    }
    
    /// 触发 Live Activity 刷新以应用最新设置
    private func syncLiveActivities() {
        Task { @MainActor in
            ActivityManager.shared.scheduleSyncActivities(groups: taskGroups)
        }
    }
}

#Preview {
    NavigationStack {
        LiveActivitySettingsView()
    }
}
