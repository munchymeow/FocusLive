//
//  LabView.swift
//  FocusLive
//
//  实验室：UI 风格选择器 + 实验性功能
//

import SwiftUI

struct LabView: View {
    @AppStorage("labBorderlessUIEnabled", store: UserDefaults(suiteName: appGroupID))
    private var borderlessUIEnabled = false

    @EnvironmentObject private var uiStyle: UIStyleManager
    @Environment(\.colorScheme) private var colorScheme

    private var selectedStyle: AppUIStyle { uiStyle.selectedStyle }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 顶部说明
                warningBanner

                // 无界 UI 开关
                borderlessToggleCard

                // UI 风格选择器
                if borderlessUIEnabled {
                    stylePickerSection
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 80)
        }
        .navigationTitle(String(localized: "实验室"))
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    // MARK: - 警告横幅

    private var warningBanner: some View {
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
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.orange.opacity(colorScheme == .dark ? 0.12 : 0.06))
        )
    }

    // MARK: - 无界 UI 开关

    private var borderlessToggleCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
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
                    Text(String(localized: "多风格设计系统"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Toggle(isOn: $borderlessUIEnabled) {
                Text(String(localized: "启用测试版 UI"))
                    .font(.subheadline.weight(.semibold))
            }
            .tint(.blue)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(colorScheme == .dark ? Color(red: 0.15, green: 0.15, blue: 0.18) : .white)
                .shadow(color: colorScheme == .dark ? Color.black.opacity(0.3) : Color.black.opacity(0.06), radius: 10, y: 4)
        )
    }

    // MARK: - 风格选择器

    private var stylePickerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(localized: "选择 UI 风格"))
                .font(.headline)

            Text(String(localized: "选择你喜欢的设计风格，切换后立即生效。"))
                .font(.caption)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(AppUIStyle.allCases) { candidateStyle in
                    styleCard(candidateStyle)
                }
            }
        }
    }

    private func styleCard(_ newStyle: AppUIStyle) -> some View {
        let isSelected = selectedStyle == newStyle

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                uiStyle.selectedStyle = newStyle
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(newStyle.accentColor.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: newStyle.icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(newStyle.accentColor)
                    }
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.blue)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: newStyle.displayName))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(String(localized: newStyle.subtitle))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(colorScheme == .dark ? Color(red: 0.15, green: 0.15, blue: 0.18) : .white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                    )
                    .shadow(color: colorScheme == .dark ? Color.black.opacity(0.2) : Color.black.opacity(0.04), radius: 8, y: 3)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        LabView()
    }
}
