//
//  BorderlessRootTabView.swift
//  FocusLive
//
//  测试版无界 TabView：多风格设计系统
//

import SwiftUI
import SwiftData

struct BorderlessRootTabView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Query private var taskGroups: [TaskGroup]
    @StateObject private var uiStyle = UIStyleManager.shared

    var body: some View {
        TabView {
            BorderlessContentView()
                .tabItem {
                    Label(String(localized: "事项"), systemImage: "checklist")
                }

            BorderlessProfileView()
                .tabItem {
                    Label(String(localized: "我的"), systemImage: "person.fill")
                }
        }
        .environmentObject(uiStyle)
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
