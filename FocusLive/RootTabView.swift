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
    @AppStorage("labBorderlessUIEnabled", store: UserDefaults(suiteName: appGroupID))
    private var borderlessUIEnabled = false

    var body: some View {
        Group {
            if borderlessUIEnabled {
                BorderlessRootTabView()
            } else {
                normalTabView
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
        .onChange(of: borderlessUIEnabled) { _, _ in
            syncLiveActivitiesForAppearanceChange()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            persistLiveActivityAppearance()
            syncLiveActivitiesForAppearanceChange()
        }
    }

    private var normalTabView: some View {
        TabView {
            ContentView()
                .tabItem {
                    Label(String(localized: "事项"), systemImage: "checklist")
                }

            AISummaryView()
                .tabItem {
                    Label(String(localized: "AI 总结"), systemImage: "sparkles")
                }

            ProfileView()
                .tabItem {
                    Label(String(localized: "我的"), systemImage: "person.fill")
                }
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
