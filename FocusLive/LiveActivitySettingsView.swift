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
    private static let smartReminderKey = "smartReminderEnabled"
    private let dailyMotivationKey = "dailyMotivationEnabled"
    private let lastMotivationDateKey = "lastMotivationDate"
    private let currentMotivationIndexKey = "currentMotivationIndex"
    
    @AppStorage(Self.displayCountKey, store: UserDefaults(suiteName: Self.appGroupID))
    private var displayCount: Int = 4
    
    @AppStorage(Self.opacityKey, store: UserDefaults(suiteName: Self.appGroupID))
    private var backgroundOpacity: Double = 0.9
    
    @AppStorage(Self.proStatusKey, store: UserDefaults(suiteName: Self.appGroupID))
    private var isProUser: Bool = false
    
    @AppStorage(Self.smartReminderKey, store: UserDefaults(suiteName: Self.appGroupID))
    private var smartReminderEnabled: Bool = false
    
    /// 每日鼓励开关
    @AppStorage("dailyMotivationEnabled", store: UserDefaults(suiteName: appGroupID))
    private var dailyMotivationEnabled: Bool = true
    
    @Query private var taskGroups: [TaskGroup]
    @State private var selectedGroupIDs: Set<String> = []
    
    private var maxDisplayCount: Int {
        isProUser ? 8 : 3
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
                
                VStack(alignment: .leading, spacing: 8) {
                    Slider(value: $backgroundOpacity, in: 0.0...1.0, step: 0.1) {
                        Text("背景透明度")
                    } minimumValueLabel: {
                        Text("0%")
                    } maximumValueLabel: {
                        Text("100%")
                    }
                    Text(String(format: "%.2f", backgroundOpacity))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("锁屏实时活动")
            } footer: {
                Text("设置会同步到锁屏实时活动与灵动岛展示。")
            }
            
            if isProUser {
                Section {
                    Toggle("智能提醒", isOn: $smartReminderEnabled)
                } header: {
                    Text("高级功能")
                } footer: {
                    Text("开启后，锁屏页会首要显示距离截止时间最近的任务，并显示倒计时提醒。")
                }
            }
            
            Section(header: Text("每日鼓励")) {
                Toggle("每日鼓励", isOn: $dailyMotivationEnabled)
                    .onChange(of: dailyMotivationEnabled) { _, newValue in
                        if newValue {
                            checkAndCreateMotivationActivity()
                        } else {
                            endMotivationActivity()
                        }
                    }
                    
                    if dailyMotivationEnabled {
                        Text("当没有设置锁屏显示分组时，每天随机显示一条励志名言")
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
            // 检查励志名言活动
            checkAndCreateMotivationActivity()
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
            // 分组选择变化时，检查是否需要显示励志名言
            checkAndCreateMotivationActivity()
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
        if backgroundOpacity < 0.0 {
            backgroundOpacity = 0.0
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
    
    /// 励志名言列表
    private var motivationalQuotes: [String] {
        guard let url = Bundle.main.url(forResource: "motivational_quotes", withExtension: "csv"),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            return []
        }
        
        return content.components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }
    
    /// 触发 Live Activity 刷新以应用最新设置
    /// - Returns: Void
    private func syncLiveActivities() {
        Task { @MainActor in
            ActivityManager.shared.syncActivities(groups: taskGroups)
        }
    }
    
    /// 检查并创建励志名言活动
    private func checkAndCreateMotivationActivity() {
        guard dailyMotivationEnabled else { return }
        
        // 检查是否有活跃的分组活动
        let hasActiveGroupActivities = ActivityManager.shared.hasActiveGroupActivities()
        print("💡 检查励志名言: 每日鼓励=\(dailyMotivationEnabled), 有分组活动=\(hasActiveGroupActivities)")
        
        if hasActiveGroupActivities {
            // 如果有分组活动，结束名言活动
            ActivityManager.shared.endMotivationActivity()
            print("💡 有分组活动，结束名言活动")
            return
        }
        
        // 检查是否需要更新名言（每天更换）
        let defaults = UserDefaults(suiteName: Self.appGroupID)
        let lastDate = defaults?.object(forKey: "lastMotivationDate") as? Date
        let today = Calendar.current.startOfDay(for: Date())
        
        if lastDate == nil || !Calendar.current.isDate(lastDate!, inSameDayAs: today) {
            // 需要更新名言
            print("💡 需要更新名言，创建新活动")
            createMotivationActivity()
        } else {
            print("💡 名言已是今天的，无需更新")
        }
    }
    
    /// 创建励志名言活动
    private func createMotivationActivity() {
        guard !motivationalQuotes.isEmpty else { return }
        
        let defaults = UserDefaults(suiteName: Self.appGroupID)
        var currentIndex = defaults?.integer(forKey: "currentMotivationIndex") ?? 0
        
        // 获取当前名言
        let quote = motivationalQuotes[currentIndex]
        
        // 更新索引（循环）
        currentIndex = (currentIndex + 1) % motivationalQuotes.count
        defaults?.set(currentIndex, forKey: "currentMotivationIndex")
        defaults?.set(Date(), forKey: "lastMotivationDate")
        
        // 解析名言格式："名言"——作者
        let components = quote.components(separatedBy: "——")
        let quoteText = components.first?.trimmingCharacters(in: CharacterSet.whitespaces) ?? quote
        let author = components.count > 1 ? components.last?.trimmingCharacters(in: CharacterSet.whitespaces) : nil
        
        // 创建名言活动
        ActivityManager.shared.createMotivationActivity(quote: quoteText, author: author)
    }
    
    /// 结束励志名言活动
    private func endMotivationActivity() {
        ActivityManager.shared.endMotivationActivity()
    }
}

#Preview {
    NavigationStack {
        LiveActivitySettingsView()
    }
}
