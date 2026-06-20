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
            VStack(alignment: .leading, spacing: AmbientGlass.sectionSpacing) {
                // 顶部说明
                VStack(alignment: .leading, spacing: 8) {
                    Label(String(localized: "实验室功能为预览性质，可能不稳定，可随时关闭。"), systemImage: "flask.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.orange)
                    Text(String(localized: "开启后整个 App 将切换到新版 UI，关闭则立即回到当前版本。"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: AmbientGlass.smallCornerRadius, style: .continuous)
                        .fill(Color.orange.opacity(colorScheme == .dark ? 0.12 : 0.06))
                )

                // 测试版 UI 卡片
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: AmbientGlass.iconCornerRadius, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.blue.opacity(0.9), Color.cyan.opacity(0.6)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 44, height: 44)
                            Image(systemName: "rectangle.dashed")
                                .font(.system(size: 20))
                                .foregroundStyle(.white)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(String(localized: "测试版 UI"))
                                .font(.title3.weight(.bold))
                            Text(String(localized: "Ambient Glass 设计语言"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }

                    // 预览区域
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(AmbientGlass.glassFill(for: colorScheme))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(AmbientGlass.glassBorder(for: colorScheme), lineWidth: 0.5)
                            )
                            .frame(height: 160)

                        VStack(spacing: 12) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 32))
                                .foregroundStyle(AmbientGlass.accentGradient)
                            VStack(spacing: 4) {
                                Text(String(localized: "环境光晕 + 毛玻璃 + 渐变"))
                                    .font(.subheadline.weight(.medium))
                                Text(String(localized: "三层视觉系统，兼顾呼吸感与精致感"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Toggle(isOn: $borderlessUIEnabled) {
                        Text(String(localized: "启用测试版 UI"))
                            .font(.subheadline.weight(.semibold))
                    }
                    .tint(.blue)
                }
                .padding(16)
                .glassCard()
            }
            .padding(.horizontal, AmbientGlass.pagePadding)
            .padding(.top, 16)
            .padding(.bottom, 80)
        }
        .navigationTitle(String(localized: "实验室"))
        .navigationBarTitleDisplayMode(.inline)
        .background(AmbientGlass.background(for: colorScheme).ignoresSafeArea())
    }
}

#Preview {
    NavigationStack {
        LabView()
    }
}
