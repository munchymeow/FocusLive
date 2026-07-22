//
//  FirstLaunchTutorialView.swift
//  FocusLive
//

import SwiftUI
import SwiftData

struct FirstLaunchTutorialView: View {
    let onStart: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0
    @AppStorage("liveActivityFontSize", store: UserDefaults(suiteName: appGroupID))
    private var fontSizeScale: Double = 1.5
    @AppStorage("liveActivityShowCompletedTasks", store: UserDefaults(suiteName: appGroupID))
    private var showCompletedTasks: Bool = true
    @AppStorage("dailyMotivationEnabled", store: UserDefaults(suiteName: appGroupID))
    private var dailyMotivationEnabled: Bool = true
    @AppStorage("liveActivityBackgroundOpacity", store: UserDefaults(suiteName: appGroupID))
    private var backgroundOpacity: Double = 0.0

    private let recommendedFontScale = 1.5

    private var pageCount: Int { 4 }

    private var isLastPage: Bool {
        currentPage == pageCount - 1
    }

    private var primaryButtonTitle: String {
        isLastPage ? "开始使用" : "下一步"
    }

    private var isRecommendedFontSize: Bool {
        abs(fontSizeScale - recommendedFontScale) < 0.001
    }

    private var previewFontSize: CGFloat {
        let scaled = 14.0 * fontSizeScale
        return CGFloat(min(max(scaled, 12.0), 24.0))
    }

    private var previewTextColor: Color {
        isOpaquePreviewBackground ? .primary : .white
    }

    private var previewSecondaryTextColor: Color {
        isOpaquePreviewBackground ? .secondary : .white.opacity(0.72)
    }

    private var isOpaquePreviewBackground: Bool {
        backgroundOpacity >= 0.5
    }

    private var opaqueBackgroundBinding: Binding<Bool> {
        Binding(
            get: { isOpaquePreviewBackground },
            set: { backgroundOpacity = $0 ? 1.0 : 0.0 }
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                TabView(selection: $currentPage) {
                    welcomeTutorialPage
                        .tag(0)
                    fontSetupPage
                        .tag(1)
                    toggleSetupPage
                        .tag(2)
                    finishTutorialPage
                        .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                HStack(spacing: 12) {
                    if currentPage > 0 {
                        Button(action: goToPreviousPage) {
                            Text("上一步")
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(Color.secondary.opacity(0.12))
                                )
                        }
                        .buttonStyle(.plain)
                    }

                    Button(action: handlePrimaryAction) {
                        Text(primaryButtonTitle)
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [.blue, .cyan],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
            }
            .padding(.vertical, 24)
            .navigationTitle("新手教程")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.large])
        .interactiveDismissDisabled()
    }

    private var welcomeTutorialPage: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
                tutorialIconCard(systemName: "sparkles.rectangle.stack.fill")

                Text("欢迎使用 FocusScreen")
                    .font(.system(size: 28, weight: .bold))
                    .multilineTextAlignment(.center)

                Text("先花 10 秒把最常用的显示设置定好，后面会更顺手。")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 20)

                VStack(alignment: .leading, spacing: 14) {
                    tutorialBullet(
                        systemName: "plus.circle.fill",
                        title: "先认识一下",
                        body: "点击右上角加号创建分组，可以选择传统待办、每日打卡或提醒事项。"
                    )

                    tutorialBullet(
                        systemName: "hand.tap.fill",
                        title: "常用交互很直接",
                        body: "点击标题即可直接编辑，长按任务可以设置时间、提醒、优先级和隐私。"
                    )

                    tutorialBullet(
                        systemName: "apps.iphone.badge.plus",
                        title: "后面都能再改",
                        body: "你可以随时在\"我的 > 锁屏卡片设置\"里重新调整，不用担心第一次选错。"
                    )

                    tutorialBullet(
                        systemName: "rectangle.portrait.and.arrow.right",
                        title: "灵动岛可最小化展示",
                        body: "如果不想在灵动岛展示内容，可以在锁屏卡片设置里关闭\"显示灵动岛\"。锁屏卡片会继续显示。"
                    )
                }
                .padding(.horizontal, 20)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
        }
    }

    private var fontSetupPage: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
                tutorialIconCard(systemName: "textformat.size")

                Text("调一下你喜欢的字号")
                    .font(.system(size: 28, weight: .bold))
                    .multilineTextAlignment(.center)

                Text("推荐默认 150%，试试看预览效果，标题和任务内容会一起变化。")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 20)

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("任务字体大小")
                            .font(.headline)

                        Spacer()

                        Text(String(format: "%.0f%%", fontSizeScale * 100))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    Slider(value: $fontSizeScale, in: 0.7...2.0, step: 0.05)

                    HStack {
                        if isRecommendedFontSize {
                            Text("推荐默认")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.blue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(Color.blue.opacity(0.12))
                                )
                        }

                        Spacer()

                        Button("恢复推荐默认") {
                            fontSizeScale = recommendedFontScale
                        }
                        .font(.subheadline.weight(.semibold))
                    }
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.secondary.opacity(0.08))
                )
                .padding(.horizontal, 4)

                VStack(alignment: .leading, spacing: 12) {
                    Text("实时活动预览")
                        .font(.headline)

                    FirstLaunchPreviewCard(
                        fontSize: previewFontSize,
                        showCompletedTasks: showCompletedTasks,
                        isOpaqueBackground: isOpaquePreviewBackground,
                        textColor: previewTextColor,
                        secondaryTextColor: previewSecondaryTextColor
                    )
                }
                .padding(.horizontal, 4)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
        }
    }

    private var toggleSetupPage: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
                tutorialIconCard(systemName: "switch.2")

                Text("先把常用开关选好")
                    .font(.system(size: 28, weight: .bold))
                    .multilineTextAlignment(.center)

                Text("这些设置会同步影响首页和锁屏卡片显示。")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 20)

                VStack(spacing: 14) {
                    tutorialToggleCard(
                        title: "显示已完成事项",
                        subtitle: "开启后，完成的待办会保留在卡片里，并用横线标记。",
                        isOn: $showCompletedTasks
                    )

                    tutorialToggleCard(
                        title: "首页显示每日鼓励",
                        subtitle: "开启后，\"全部\"页底部会显示一条鼓励，也会同步到锁屏鼓励卡片。",
                        isOn: $dailyMotivationEnabled
                    )

                    tutorialToggleCard(
                        title: "不透明卡片背景",
                        subtitle: "开启后更稳重，关闭则更贴近壁纸和锁屏氛围。",
                        isOn: opaqueBackgroundBinding
                    )
                }
                .padding(.horizontal, 4)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
        }
    }

    private var finishTutorialPage: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                tutorialIconCard(systemName: "hands.sparkles.fill")

                Text("完成得差不多了")
                    .font(.system(size: 28, weight: .bold))
                    .multilineTextAlignment(.center)

                Text("当前设置：")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 12) {
                    summaryRow("字体大小 \(Int(fontSizeScale * 100))%")
                    summaryRow(showCompletedTasks ? "已完成事项会显示" : "已完成事项默认隐藏")
                    summaryRow(dailyMotivationEnabled ? "首页显示每日鼓励" : "首页不显示每日鼓励")
                    summaryRow(isOpaquePreviewBackground ? "锁屏卡片使用不透明背景" : "锁屏卡片使用透明背景")
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.secondary.opacity(0.08))
                )
                .padding(.horizontal, 4)

                Text("祝你用得愉快，也祝你每天都能稳稳推进。")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 20)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
        }
    }

    @ViewBuilder
    private func tutorialIconCard(systemName: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.18), Color.cyan.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 120, height: 120)

            Image(systemName: systemName)
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(.blue)
        }
    }

    @ViewBuilder
    private func tutorialBullet(systemName: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(body)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    @ViewBuilder
    private func tutorialToggleCard(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    @ViewBuilder
    private func summaryRow(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text(text)
                .font(.subheadline)
            Spacer(minLength: 0)
        }
    }

    private func goToPreviousPage() {
        withAnimation(.easeOut(duration: 0.22)) {
            currentPage = max(0, currentPage - 1)
        }
    }

    private func handlePrimaryAction() {
        if isLastPage {
            onStart()
            dismiss()
            return
        }

        withAnimation(.easeOut(duration: 0.22)) {
            currentPage = min(pageCount - 1, currentPage + 1)
        }
    }
}

struct FirstLaunchPreviewCard: View {
    let fontSize: CGFloat
    let showCompletedTasks: Bool
    let isOpaqueBackground: Bool
    let textColor: Color
    let secondaryTextColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: max(14, fontSize * 0.95)))

                Text("晚自修")
                    .font(.system(size: fontSize, weight: .semibold))
                    .foregroundStyle(textColor)

                Spacer()

                Text("1/3")
                    .font(.system(size: fontSize, weight: .medium))
                    .foregroundStyle(secondaryTextColor)
            }

            VStack(alignment: .leading, spacing: 8) {
                previewRow(title: "写英语作业", isCompleted: false)
                previewRow(title: "物理练习题", isCompleted: false)

                if showCompletedTasks {
                    previewRow(title: "复习数学", isCompleted: true)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(previewBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(isOpaqueBackground ? Color.black.opacity(0.06) : Color.white.opacity(0.16), lineWidth: 1)
                )
        )
    }

    private var previewBackground: AnyShapeStyle {
        if isOpaqueBackground {
            return AnyShapeStyle(Color(.systemBackground))
        }

        return AnyShapeStyle(
            LinearGradient(
                colors: [Color.blue.opacity(0.92), Color.cyan.opacity(0.76)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    @ViewBuilder
    private func previewRow(title: String, isCompleted: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: max(13, fontSize * 0.95), weight: .medium))
                .foregroundStyle(isCompleted ? .green : secondaryTextColor)

            Text(title)
                .font(.system(size: fontSize, weight: .medium))
                .foregroundStyle(isCompleted ? textColor.opacity(0.58) : textColor)
                .strikethrough(isCompleted, color: textColor.opacity(0.7))
                .lineLimit(1)

            Spacer(minLength: 0)
        }
    }
}
