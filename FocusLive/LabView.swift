//
//  LabView.swift
//  FocusLive
//
//  实验室：体验实验性功能与新版 UI
//

import SwiftUI

struct LabView: View {
    @AppStorage("labBorderlessUIEnabled", store: UserDefaults(suiteName: appGroupID))
    private var borderlessUIEnabled = false

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 顶部说明
                VStack(alignment: .leading, spacing: 8) {
                    Label("实验室功能为预览性质，可能不稳定，可随时关闭。", systemImage: "flask.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.orange)
                    Text("开启后整个 App 将切换到新版 UI，关闭则立即回到当前版本。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.orange.opacity(colorScheme == .dark ? 0.12 : 0.06))
                )

                // 测试版 UI 卡片
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 10) {
                        Image(systemName: "rectangle.dashed")
                            .font(.system(size: 32))
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("测试版 UI")
                                .font(.title3.weight(.bold))
                            Text("无界 / 无卡片 / 无边框的极简设计")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }

                    // 预览占位
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.tertiarySystemBackground))
                            .frame(height: 160)

                        VStack(spacing: 8) {
                            Image(systemName: "rectangle.on.rectangle.angled")
                                .font(.system(size: 36))
                                .foregroundStyle(.secondary)
                            Text("无界设计预览")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Toggle(isOn: $borderlessUIEnabled) {
                        Text("启用测试版 UI")
                            .font(.subheadline.weight(.semibold))
                    }
                    .tint(.blue)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.6), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.06), radius: 10, x: 0, y: 4)
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 80)
        }
        .navigationTitle("实验室")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    private var cardBackground: Color {
        colorScheme == .dark
            ? Color(red: 0.15, green: 0.15, blue: 0.18)
            : .white
    }
}

#Preview {
    NavigationStack {
        LabView()
    }
}
