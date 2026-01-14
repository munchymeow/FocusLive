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
    private static let proStatusKey = "isProUser"
    private static let allowedGroupIDsKey = "liveActivityAllowedGroupIDs"
    
    @AppStorage(Self.displayCountKey, store: UserDefaults(suiteName: Self.appGroupID))
    private var displayCount: Int = 4
    
    @AppStorage(Self.opacityKey, store: UserDefaults(suiteName: Self.appGroupID))
    private var backgroundOpacity: Double = 0.9
    
    @AppStorage(Self.proStatusKey, store: UserDefaults(suiteName: Self.appGroupID))
    private var isProUser: Bool = false
    
    @Query private var taskGroups: [TaskGroup]
    @State private var selectedGroupIDs: Set<String> = []
    
    private var maxDisplayCount: Int {
        isProUser ? 5 : 3
    }

    private var selectableGroups: [TaskGroup] {
        taskGroups
            .filter { !($0.isPrivate ?? false) }
            .sorted { ($0.sortOrder ?? 0) < ($1.sortOrder ?? 0) }
    }
    
    var body: some View {
        Form {
            Section {
                Stepper(value: $displayCount, in: 1...maxDisplayCount) {
                    HStack {
                        Text("显示条数")
                        Spacer()
                        Text("\(displayCount)")
                            .foregroundStyle(.secondary)
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("背景透明度")
                    Slider(value: $backgroundOpacity, in: 0.4...1.0, step: 0.05)
                    Text(String(format: "%.2f", backgroundOpacity))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("锁屏实时活动")
            } footer: {
                Text("设置会同步到锁屏实时活动与灵动岛展示。")
            }
            
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
        }
        .navigationTitle("锁屏卡片设置")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            normalizeSettings()
            loadSelectedGroupsIfNeeded()
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
        if backgroundOpacity < 0.4 {
            backgroundOpacity = 0.4
        }
        if backgroundOpacity > 1.0 {
            backgroundOpacity = 1.0
        }
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
            ActivityManager.shared.syncActivities(groups: taskGroups)
        }
    }
}

#Preview {
    NavigationStack {
        LiveActivitySettingsView()
    }
}
