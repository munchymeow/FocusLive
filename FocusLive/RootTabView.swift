//
//  RootTabView.swift
//  FocusLive
//
//  Created by 赵豪伟 on 2026/1/14.
//

import SwiftUI
import SwiftData

private let liveActivityAppearanceKey = "liveActivitySystemAppearance"

struct RootTabView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Query private var taskGroups: [TaskGroup]

    var body: some View {
        TabView {
            ContentView()
                .tabItem {
                    Label("事项", systemImage: "checklist")
                }

            ProfileView()
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
        UserDefaults(suiteName: appGroupID)?.set(appearance, forKey: liveActivityAppearanceKey)
    }

    private func syncLiveActivitiesForAppearanceChange() {
        Task { @MainActor in
            ActivityManager.shared.scheduleSyncActivities(groups: taskGroups)
        }
    }
}

#Preview {
    RootTabView()
        .modelContainer(for: TaskGroup.self, inMemory: true)
}
