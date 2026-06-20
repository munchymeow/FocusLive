//
//  BorderlessRootTabView.swift
//  FocusLive
//
//  测试版无界 TabView：无卡片、无边框的极简设计
//

import SwiftUI
import SwiftData

struct BorderlessRootTabView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Query private var taskGroups: [TaskGroup]

    var body: some View {
        TabView {
            BorderlessContentView()
                .tabItem {
                    Label("事项", systemImage: "checklist")
                }

            BorderlessProfileView()
                .tabItem {
                    Label("我的", systemImage: "person.fill")
                }
        }
        .onAppear {
            persistLiveActivityAppearance()
            syncLiveActivitiesForAppearanceChange()
        }
        .onChange(of: colorScheme) { _, newValue in
            persistLiveActivityAppearance(newValue)
            syncLiveActivitiesForAppearanceChange()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            persistLiveActivityAppearance()
            syncLiveActivitiesForAppearanceChange()
        }
    }

    private func persistLiveActivityAppearance(_ scheme: ColorScheme? = nil) {
        let resolvedScheme = scheme ?? colorScheme
        let appearance = resolvedScheme == .dark ? "dark" : "light"
        UserDefaults(suiteName: appGroupID)?.set(appearance, forKey: "liveActivitySystemAppearance")
    }

    private func syncLiveActivitiesForAppearanceChange() {
        Task { @MainActor in
            ActivityManager.shared.scheduleSyncActivities(groups: taskGroups)
        }
    }
}

#Preview {
    BorderlessRootTabView()
        .modelContainer(for: TaskGroup.self, inMemory: true)
}
