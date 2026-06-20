//
//  LiveActivitySettingsView.swift
//  FocusLive
//
//  Created by 赵豪伟 on 2026/1/14.
//

import SwiftUI
import SwiftData

/// 实时活动展示设置视图
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
    
    @Query private var taskGroups: [TaskGroup]
    @State private var selectedGroupIDs: Set<String> = []

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
    
    var body: some View {
        Form {
            Section {
                if selectableGroups.isEmpty {
                    Text("暂无可显示的分组")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(selectableGroups) { group in
                        Toggle(isOn: bindingForGroup(group)) {
                            HStack(spacing: 10) {
                                Text(group.iconName)
                                Text(group.title)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            } header: {
                Text("锁屏显示分组")
            } footer: {
                Text(isProUser ? "选择显示分组后，仅这些分组会出现在锁屏实时活动。" : "免费版仅可选择 1 个分组显示在锁屏实时活动。")
            }
            
            Section {
                Stepper(value: $displayCount, in: 1...maxDisplayCount) {
                    HStack {
                        Text("显示条数")
                        Spacer()
                        Text("\(displayCount)")
                            .foregroundStyle(.secondary)
                    }
                }

                if displayCount > 4 {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                        Text("建议显示 4 条以内，条数过多可能导致锁屏卡片内容被遮挡裁剪。")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("卡片背景")

                    Picker("卡片背景", selection: backgroundModeBinding) {
                        ForEach(LockScreenBackgroundMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text("透明模式默认白字；不透明模式会根据浅色白底黑字、深色黑底白字自动切换。")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("任务字体大小")
                        Spacer()
                        Text(String(format: "%.0f%%", fontSizeScale * 100))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Slider(value: $fontSizeScale, in: 0.7...2.0, step: 0.05) {
                        Text("字体大小")
                    } minimumValueLabel: {
                        Text("小")
                            .font(.caption2)
                    } maximumValueLabel: {
                        Text("大")
                            .font(.caption2)
                    }
                }
                .onChange(of: fontSizeScale) { _, _ in
                    syncLiveActivities()
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("任务字体颜色")
                        Spacer()
                        Text(fontColorDisplayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
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
                                                    .stroke(Color.accentColor, lineWidth: fontColorName == option.name ? 3 : 0)
                                            )
                                            .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                                        if option.name == "default" {
                                            Text("A")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundStyle(.primary)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                .onChange(of: fontColorName) { _, _ in
                    syncLiveActivities()
                }

                Toggle("显示灵动岛", isOn: $dynamicIslandEnabled)
                    .onChange(of: dynamicIslandEnabled) { _, _ in
                        syncLiveActivities()
                    }

                Toggle("显示已完成事项", isOn: $showCompletedTasks)
                    .onChange(of: showCompletedTasks) { _, _ in
                        syncLiveActivities()
                    }
            } header: {
                Text("锁屏实时活动")
            } footer: {
                Text("默认任务文字会根据卡片背景与系统深浅色自动切换黑白；手动选色会覆盖默认效果。iOS 不支持仅保留锁屏而彻底关闭灵动岛，关闭“显示灵动岛”后会改为尽量最小化展示。")
            }
            
            if isProUser {
                Section {
                    Toggle("智能提醒", isOn: $smartReminderEnabled)
                        .onChange(of: smartReminderEnabled) { _, newValue in
                            if newValue {
                                Task {
                                    await NotificationManager.shared.requestPermission()
                                }
                            }
                            syncLiveActivities()
                        }

                } header: {
                    Text("高级功能")
                } footer: {
                    Text("开启后，系统会在任务计划时间前 2 小时自动发送本地通知提醒，同时锁屏页优先显示最近截止的任务。")
                }
            }
            
            Section(header: Text("每日鼓励")) {
                Toggle("每日鼓励", isOn: $dailyMotivationEnabled)
                    .onChange(of: dailyMotivationEnabled) { _, _ in
                        syncLiveActivities()
                    }
                    
                    if dailyMotivationEnabled {
                        Text("开启后，每日鼓励会显示在首页“全部”页底部，并同步到锁屏每日鼓励卡片。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
        }
        .navigationTitle("锁屏卡片设置")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            normalizeSettings()
            loadSelectedGroupsIfNeeded()
            syncLiveActivities()
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
        .onChange(of: backgroundOpacity) { _, _ in
            syncLiveActivities()
        }
        .onChange(of: selectedGroupIDs) { _, _ in
            syncLiveActivities()
        }
    }
    
    /// 规范化设置范围，防止异常值
    /// - Parameters: 无
    /// - Returns: Void
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
    /// - Parameter group: 任务分组
    /// - Returns: Toggle 的绑定值
    private func bindingForGroup(_ group: TaskGroup) -> Binding<Bool> {
        Binding(
            get: { selectedGroupIDs.contains(group.id.uuidString) },
            set: { isOn in
                updateSelection(for: group, isSelected: isOn)
            }
        )
    }
    
    /// 初始化分组选择数据
    /// - Returns: Void
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
    /// - Returns: Void
    private func syncSelectionWithGroups() {
        let validIDs = Set(selectableGroups.map { $0.id.uuidString })
        selectedGroupIDs = selectedGroupIDs.intersection(validIDs)
        enforceSelectionLimit()
        persistSelectedGroupIDs()
    }
    
    /// 更新分组选择状态并同步
    /// - Parameters:
    ///   - group: 任务分组
    ///   - isSelected: 是否选择
    /// - Returns: Void
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
    /// - Returns: Void
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
    /// - Returns: 分组 ID 列表
    private func defaultSelectedGroupIDs() -> [String] {
        let ids = selectableGroups.map { $0.id.uuidString }
        return isProUser ? ids : Array(ids.prefix(1))
    }
    
    /// 保存分组选择结果
    /// - Returns: Void
    private func persistSelectedGroupIDs() {
        guard let defaults = UserDefaults(suiteName: Self.appGroupID) else { return }
        defaults.set(Array(selectedGroupIDs), forKey: Self.allowedGroupIDsKey)
    }
    
    /// 触发 Live Activity 刷新以应用最新设置
    /// - Returns: Void
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
