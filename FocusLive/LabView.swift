//
//  LabView.swift
//  FocusLive
//
//  实验室：UI 风格选择器 + 实验性功能
//
//  v3：活预览 + matched 选中指示 + 触觉反馈
//  - 仅 Glassmorphism 对免费用户开放，其余风格 Pro 专属
//  - 新增 Neo Brutal / Editorial / Aurora / Terminal 大胆布局语言
//

import SwiftUI
import SwiftData

struct LabView: View {
    @AppStorage("labBorderlessUIEnabled", store: UserDefaults(suiteName: appGroupID))
    private var borderlessUIEnabled = false

    @Query private var taskGroups: [TaskGroup]
    @EnvironmentObject private var uiStyle: UIStyleManager
    @EnvironmentObject private var storeKitManager: StoreKitManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Namespace private var styleSelectionNamespace
    @State private var showSubscriptionSheet = false

    private var selectedStyle: AppUIStyle { uiStyle.selectedStyle }
    private var isProUser: Bool { storeKitManager.isProUser }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                warningBanner
                borderlessToggleCard

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
        .sheet(isPresented: $showSubscriptionSheet) {
            NavigationStack {
                SubscriptionView()
                    .environmentObject(storeKitManager)
            }
        }
        .onAppear {
            enforceProStyleAccessIfNeeded()
        }
        .onChange(of: storeKitManager.isProUser) { _, _ in
            enforceProStyleAccessIfNeeded()
        }
        .onChange(of: borderlessUIEnabled) { _, _ in
            ActivityManager.shared.scheduleSyncActivities(groups: taskGroups)
        }
        .onChange(of: uiStyle.selectedStyle) { _, _ in
            ActivityManager.shared.scheduleSyncActivities(groups: taskGroups)
        }
    }

    // MARK: - 警告横幅

    private var warningBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(String(localized: "实验室功能为预览性质，可能不稳定，可随时关闭。"), systemImage: "flask.fill")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.orange)
            Text(String(localized: "免费可体验 Glassmorphism；其余 UI 风格为 Pro 会员专属。卡片即真实预览，点击切换。"))
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
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Text(String(localized: "选择 UI 风格"))
                    .font(.headline)
                Spacer()
                if !isProUser {
                    Label(String(localized: "Pro 专属风格已锁定"), systemImage: "lock.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.orange)
                }
            }
            Text(String(localized: "卡片即真实预览——点击直接切换。免费用户仅可使用 Glassmorphism。"))
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(styleGroups, id: \.title) { group in
                VStack(alignment: .leading, spacing: 12) {
                    Text(group.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(group.styles, id: \.rawValue) { candidate in
                            styleCard(candidate)
                        }
                    }
                }
            }
        }
    }

    private struct StyleGroup {
        let title: String
        let styles: [AppUIStyle]
    }

    private var styleGroups: [StyleGroup] {
        [
            .init(title: "免费 · 玻璃", styles: [.glassmorphism]),
            .init(title: "玻璃 · 折射", styles: [.ambientGlass, .aurora]),
            .init(title: "纸 · 小票 / 终端", styles: [.flatDesign, .terminal]),
            .init(title: "拟物 · 阴影", styles: [.skeuomorphism]),
            .init(title: "极简 · 杂志", styles: [.minimalism, .editorial]),
            .init(title: "数据 · 硬边", styles: [.boldStats, .neoBrutal]),
            .init(title: "材质 · Material You", styles: [.materialDesign])
        ]
    }

    // MARK: - 风格卡

    @ViewBuilder
    private func styleCard(_ candidate: AppUIStyle) -> some View {
        let isSelected = selectedStyle == candidate
        let locked = candidate.requiresPro && !isProUser

        Button {
            selectStyle(candidate)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(String(localized: candidate.displayName))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            if candidate.requiresPro {
                                Text("PRO")
                                    .font(.system(size: 9, weight: .black, design: .rounded))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.orange))
                            }
                        }
                        Text(String(localized: candidate.subtitle))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(candidate.accentColor)
                            .matchedGeometryEffect(id: "labStyleCheck", in: styleSelectionNamespace)
                            .transition(.scale.combined(with: .opacity))
                    } else if locked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                stylePreview(candidate)
                    .frame(height: 128)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        if locked {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.black.opacity(colorScheme == .dark ? 0.35 : 0.12))
                        }
                    }
                    .overlay(alignment: .bottomTrailing) {
                        if isSelected {
                            Capsule()
                                .fill(candidate.accentGradient(for: colorScheme))
                                .frame(width: 28, height: 4)
                                .padding(8)
                                .matchedGeometryEffect(id: "labStylePill", in: styleSelectionNamespace)
                        }
                    }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(colorScheme == .dark ? Color(red: 0.15, green: 0.15, blue: 0.18) : .white)
                    .overlay {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(candidate.accentColor, lineWidth: 2)
                                .matchedGeometryEffect(id: "labStyleBorder", in: styleSelectionNamespace)
                        }
                    }
                    .shadow(color: colorScheme == .dark ? Color.black.opacity(0.2) : Color.black.opacity(0.04), radius: 8, y: 3)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(String(localized: candidate.displayName)))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityHint(locked ? Text(String(localized: "需要 Pro 会员")) : Text(""))
    }

    private func selectStyle(_ candidate: AppUIStyle) {
        if candidate.requiresPro && !isProUser {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            showSubscriptionSheet = true
            return
        }

        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        withAnimation(reduceMotion ? MotionTokens.quickState(reduceMotion: true) : .spring(response: 0.32, dampingFraction: 0.86)) {
            uiStyle.selectedStyle = candidate
        }
    }

    private func enforceProStyleAccessIfNeeded() {
        if selectedStyle.requiresPro && !isProUser {
            withAnimation(MotionTokens.quickState) {
                uiStyle.selectedStyle = .glassmorphism
            }
        }
    }

    // MARK: - 迷你预览

    @ViewBuilder
    private func stylePreview(_ candidate: AppUIStyle) -> some View {
        let progress: Double = 0.62
        let completed: Int = 3
        let total: Int = 5

        ZStack {
            if candidate.showAmbientBlobs {
                miniAmbientBlobs(candidate)
                    .opacity(0.55)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else if candidate == .terminal {
                Color(red: 0.04, green: 0.07, blue: 0.05)
            } else if candidate == .neoBrutal {
                candidate.accentColor.opacity(0.18)
            } else if candidate == .editorial {
                Color(red: 0.97, green: 0.95, blue: 0.92).opacity(colorScheme == .dark ? 0.08 : 1)
            }

            VStack(alignment: .leading, spacing: candidate == .editorial ? 8 : 6) {
                HStack(spacing: 6) {
                    if candidate != .flatDesign && candidate != .terminal {
                        ZStack {
                            Circle()
                                .fill(candidate.accentColor.opacity(0.18))
                                .frame(width: 22, height: 22)
                            Image(systemName: candidate.icon)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(candidate.accentColor)
                        }
                    }
                    Text(candidate == .editorial ? "晚间笔记" : (candidate == .terminal ? "~/FOCUS" : "工作"))
                        .font(candidate.groupTitleFont(size: candidate == .editorial ? 13 : 11))
                        .foregroundStyle(candidate == .terminal ? Color(red: 0.2, green: 0.95, blue: 0.45) : .primary)
                    Spacer()
                    Text("\(completed)/\(total)")
                        .font(candidate.bodyFont(size: 10).weight(.semibold))
                        .foregroundStyle(candidate.accentColor)
                }

                if candidate == .boldStats || candidate == .neoBrutal {
                    Text("\(Int(progress * 100))%")
                        .font(candidate.headerFont(size: 28))
                        .foregroundStyle(candidate.accentGradient(for: colorScheme))
                }

                miniRow(candidate, isCompleted: true, title: candidate == .terminal ? "sync --done" : "周报整理")
                miniRow(candidate, isCompleted: false, title: candidate == .terminal ? "build --pending" : "项目复盘")

                Spacer(minLength: 0)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: candidate == .neoBrutal ? 0 : 4)
                            .fill(candidate.accentColor.opacity(0.15))
                        RoundedRectangle(cornerRadius: candidate == .neoBrutal ? 0 : 4)
                            .fill(candidate.accentGradient(for: colorScheme))
                            .frame(width: geo.size.width * progress)
                    }
                }
                .frame(height: candidate == .neoBrutal ? 8 : 5)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: candidate.cornerRadius > 0 ? min(candidate.cornerRadius, 12) : 0, style: .continuous)
                    .fill(candidate.cardFill(for: colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: candidate.cornerRadius > 0 ? min(candidate.cornerRadius, 12) : 0, style: .continuous)
                    .stroke(candidate.cardBorder(for: colorScheme), lineWidth: candidate == .neoBrutal ? 2 : 0.5)
            )
        }
    }

    private func miniAmbientBlobs(_ candidate: AppUIStyle) -> some View {
        ZStack {
            Circle()
                .fill(candidate.accentColor.opacity(0.35))
                .frame(width: 90, height: 90)
                .blur(radius: 28)
                .offset(x: -36, y: -28)
            Circle()
                .fill(Color.purple.opacity(0.25))
                .frame(width: 80, height: 80)
                .blur(radius: 26)
                .offset(x: 38, y: 30)
        }
    }

    @ViewBuilder
    private func miniRow(_ candidate: AppUIStyle, isCompleted: Bool, title: String) -> some View {
        HStack(spacing: 6) {
            if candidate == .flatDesign || candidate == .terminal {
                Text(isCompleted ? "[x]" : "[ ]")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(candidate == .terminal ? Color(red: 0.2, green: 0.95, blue: 0.45) : .primary)
            } else {
                ZStack {
                    Circle()
                        .stroke(isCompleted ? Color.green : Color.gray.opacity(0.35), lineWidth: 1.5)
                        .frame(width: 12, height: 12)
                    if isCompleted {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 12, height: 12)
                        Image(systemName: "checkmark")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            Text(title)
                .font(candidate.bodyFont(size: 10))
                .foregroundStyle(isCompleted ? .secondary : (candidate == .terminal ? Color(red: 0.2, green: 0.95, blue: 0.45) : .primary))
                .strikethrough(isCompleted && candidate != .terminal, color: .secondary)
            Spacer()
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: candidate == .neoBrutal ? 0 : 4)
                .fill(isCompleted ? Color.green.opacity(0.05) : Color.gray.opacity(0.04))
        )
    }
}

#Preview {
    NavigationStack {
        LabView()
            .environmentObject(UIStyleManager.shared)
            .environmentObject(StoreKitManager())
    }
}