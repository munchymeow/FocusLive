//
//  RootTabView.swift
//  FocusLive
//
//  Created by 赵豪伟 on 2026/1/14.
//

import SwiftUI
import SwiftData
import UIKit

/// 根 Tab 类型
enum RootTab: Int {
    case tasks
    case profile
}

struct RootTabView: View {
    @State private var selection: RootTab = .tasks
    
    /// 初始化根 Tab 视图并隐藏系统 TabBar
    /// - Parameters: 无
    /// - Returns: RootTabView 实例
    init() {
        UITabBar.appearance().isHidden = true
    }
    
    var body: some View {
        TabView(selection: $selection) {
            ContentView()
                .tag(RootTab.tasks)
                .tabItem {
                    Label("事项", systemImage: "list.bullet")
                }
            
            ProfileView()
                .tag(RootTab.profile)
                .tabItem {
                    Label("我的", systemImage: "person.fill")
                }
        }
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom) {
            tabBar
        }
    }
    
    private var tabBar: some View {
        HStack(spacing: 8) {
            TabBarButton(
                titleKey: "事项",
                systemImage: "list.bullet",
                isSelected: selection == .tasks,
                action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selection = .tasks
                    }
                }
            )
            
            TabBarButton(
                titleKey: "我的",
                systemImage: "person.fill",
                isSelected: selection == .profile,
                action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selection = .profile
                    }
                }
            )
        }
        .padding(6)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 4)
        )
        .padding(.horizontal, 80)
        .padding(.bottom, 8)
    }
}

struct TabBarButton: View {
    let titleKey: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                Text(titleKey)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(isSelected ? .blue : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color.blue.opacity(0.12) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    RootTabView()
        .modelContainer(for: TaskGroup.self, inMemory: true)
}
