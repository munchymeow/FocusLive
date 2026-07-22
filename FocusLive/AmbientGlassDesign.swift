//
//  AmbientGlassDesign.swift
//  FocusLive
//
//  多风格 UI 设计系统
//  Ambient Glass / Flat / Skeuomorphism / Material / Minimalism / Glassmorphism / Bold Stats
//

import SwiftUI
import Combine

// MARK: - UI 风格枚举

enum AppUIStyle: String, CaseIterable, Identifiable {
    case ambientGlass = "ambient_glass"
    case flatDesign = "flat"
    case skeuomorphism = "skeu"
    case materialDesign = "material"
    case minimalism = "minimal"
    case glassmorphism = "glassmorphism"
    case boldStats = "bold_stats"
    case neoBrutal = "neo_brutal"
    case editorial = "editorial"
    case aurora = "aurora"
    case terminal = "terminal"

    var id: String { rawValue }

    /// 仅 Glassmorphism 对免费用户开放，其余为 Pro 专属。
    var requiresPro: Bool { self != .glassmorphism }

    var displayName: LocalizedStringResource {
        switch self {
        case .ambientGlass: return "Ambient Glass"
        case .flatDesign: return "Flat Receipt"
        case .skeuomorphism: return "Skeuomorphism"
        case .materialDesign: return "Material You"
        case .minimalism: return "Minimal"
        case .glassmorphism: return "Glassmorphism"
        case .boldStats: return "Bold Stats"
        case .neoBrutal: return "Neo Brutal"
        case .editorial: return "Editorial"
        case .aurora: return "Aurora"
        case .terminal: return "Terminal"
        }
    }

    var subtitle: LocalizedStringResource {
        switch self {
        case .ambientGlass: return "环境光晕 + 真玻璃折射"
        case .flatDesign: return "小票纸感 · 等宽文本 · 虚线"
        case .skeuomorphism: return "拟物高光 · 厚重阴影"
        case .materialDesign: return "Material You · 色带层级"
        case .minimalism: return "极简留白 · 细衬线"
        case .glassmorphism: return "毛玻璃 · 免费可用"
        case .boldStats: return "大数字仪表盘"
        case .neoBrutal: return "粗边框 · 硬阴影 · 高对比"
        case .editorial: return "杂志排版 · 大标题 · 衬线"
        case .aurora: return "极光渐变 · 浮动色块"
        case .terminal: return "终端等宽 · 扫描线质感"
        }
    }

    var icon: String {
        switch self {
        case .ambientGlass: return "sparkles"
        case .flatDesign: return "doc.plaintext"
        case .skeuomorphism: return "cube.fill"
        case .materialDesign: return "paintpalette.fill"
        case .minimalism: return "minus.circle"
        case .glassmorphism: return "aqi.medium"
        case .boldStats: return "chart.bar.fill"
        case .neoBrutal: return "square.on.square"
        case .editorial: return "text.book.closed.fill"
        case .aurora: return "rainbow"
        case .terminal: return "chevron.left.forwardslash.chevron.right"
        }
    }

    var accentColor: Color {
        switch self {
        case .ambientGlass: return .blue
        case .flatDesign: return Color(red: 0.15, green: 0.15, blue: 0.15)
        case .skeuomorphism: return Color(red: 0.2, green: 0.4, blue: 0.7)
        case .materialDesign: return .teal
        case .minimalism: return .primary
        case .glassmorphism: return .purple
        case .boldStats: return .orange
        case .neoBrutal: return Color(red: 1.0, green: 0.84, blue: 0.0)
        case .editorial: return Color(red: 0.55, green: 0.12, blue: 0.18)
        case .aurora: return Color(red: 0.45, green: 0.75, blue: 1.0)
        case .terminal: return Color(red: 0.2, green: 0.95, blue: 0.45)
        }
    }
}

// MARK: - 设计 Token 协议

protocol UIStyleTokens {
    func background(for colorScheme: ColorScheme) -> Color
    func cardFill(for colorScheme: ColorScheme) -> Color
    func cardBorder(for colorScheme: ColorScheme) -> Color
    func cardShadow(for colorScheme: ColorScheme) -> Color
    var cornerRadius: CGFloat { get }
    var sectionSpacing: CGFloat { get }
    var groupSpacing: CGFloat { get }
    var rowSpacing: CGFloat { get }
    var pagePadding: CGFloat { get }
    var showAmbientBlobs: Bool { get }
    /// 是否使用虚线分隔（小票风格）
    var useDashedDividers: Bool { get }
    /// 是否使用等宽字体（小票风格）
    var useMonospaceText: Bool { get }
    /// 分组是否包在独立卡片里（而不是仅靠留白）
    var wrapsGroupsInCards: Bool { get }
    /// 统计区是否使用大数字仪表盘布局
    var usesBoldStatsLayout: Bool { get }
    /// 任务行是否使用等宽文本
    func bodyFont(size: CGFloat) -> Font
    func headerFont(size: CGFloat) -> Font
    func groupTitleFont(size: CGFloat) -> Font
    func accentGradient(for colorScheme: ColorScheme) -> LinearGradient
    func successGradient(for colorScheme: ColorScheme) -> LinearGradient
    func cardBackgroundShape(cornerRadius: CGFloat) -> AnyShapeStyle
    func cardStroke(for colorScheme: ColorScheme, cornerRadius: CGFloat) -> AnyShapeStyle
    /// 锁屏 Live Activity 的视觉语言（可被 Widget 独立消费）
    var liveActivityLanguage: LiveActivityVisualLanguage { get }
}

/// 锁屏 Live Activity 与主 App 设计系统的桥接语言。
enum LiveActivityVisualLanguage: String {
    case ambientGlass
    case flatReceipt
    case skeuomorphism
    case material
    case minimal
    case glassmorphism
    case boldStats
    case neoBrutal
    case editorial
    case aurora
    case terminal
}

// MARK: - 风格 Token 实现

extension AppUIStyle: UIStyleTokens {
    func background(for colorScheme: ColorScheme) -> Color {
        switch self {
        case .ambientGlass:
            return colorScheme == .dark
                ? Color(red: 0.07, green: 0.07, blue: 0.09)
                : Color(red: 0.96, green: 0.96, blue: 0.97)
        case .flatDesign:
            return colorScheme == .dark
                ? Color(red: 0.13, green: 0.13, blue: 0.12)
                : Color(red: 0.95, green: 0.93, blue: 0.86)
        case .skeuomorphism:
            return colorScheme == .dark
                ? Color(red: 0.12, green: 0.12, blue: 0.14)
                : Color(red: 0.88, green: 0.87, blue: 0.85)
        case .materialDesign:
            return colorScheme == .dark
                ? Color(red: 0.10, green: 0.10, blue: 0.12)
                : Color(red: 0.96, green: 0.96, blue: 0.94)
        case .minimalism:
            return colorScheme == .dark ? .black : .white
        case .glassmorphism:
            return colorScheme == .dark
                ? Color(red: 0.08, green: 0.06, blue: 0.12)
                : Color(red: 0.94, green: 0.92, blue: 0.98)
        case .boldStats:
            return colorScheme == .dark
                ? Color(red: 0.07, green: 0.07, blue: 0.10)
                : Color(red: 0.98, green: 0.97, blue: 0.95)
        case .neoBrutal:
            return colorScheme == .dark
                ? Color(red: 0.08, green: 0.08, blue: 0.08)
                : Color(red: 0.98, green: 0.96, blue: 0.90)
        case .editorial:
            return colorScheme == .dark
                ? Color(red: 0.09, green: 0.08, blue: 0.07)
                : Color(red: 0.98, green: 0.97, blue: 0.94)
        case .aurora:
            return colorScheme == .dark
                ? Color(red: 0.05, green: 0.06, blue: 0.12)
                : Color(red: 0.93, green: 0.95, blue: 1.0)
        case .terminal:
            return Color(red: 0.04, green: 0.06, blue: 0.05)
        }
    }

    func cardFill(for colorScheme: ColorScheme) -> Color {
        switch self {
        case .ambientGlass:
            return colorScheme == .dark ? Color.white.opacity(0.05) : Color.white.opacity(0.75)
        case .flatDesign:
            return .clear
        case .skeuomorphism:
            return colorScheme == .dark
                ? Color(red: 0.18, green: 0.18, blue: 0.20)
                : Color(red: 0.92, green: 0.91, blue: 0.89)
        case .materialDesign:
            return colorScheme == .dark
                ? Color(red: 0.15, green: 0.15, blue: 0.18)
                : Color(red: 0.98, green: 0.98, blue: 0.96)
        case .minimalism:
            return .clear
        case .glassmorphism:
            return colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.6)
        case .boldStats:
            return colorScheme == .dark ? Color.white.opacity(0.06) : Color.white.opacity(0.9)
        case .neoBrutal:
            return colorScheme == .dark ? Color(red: 0.12, green: 0.12, blue: 0.12) : Color.white
        case .editorial:
            return colorScheme == .dark ? Color.white.opacity(0.04) : Color.white.opacity(0.9)
        case .aurora:
            return colorScheme == .dark ? Color.white.opacity(0.06) : Color.white.opacity(0.55)
        case .terminal:
            return Color(red: 0.06, green: 0.10, blue: 0.08).opacity(0.9)
        }
    }

    func cardBorder(for colorScheme: ColorScheme) -> Color {
        switch self {
        case .ambientGlass:
            return colorScheme == .dark ? Color.white.opacity(0.1) : Color.white.opacity(0.9)
        case .flatDesign:
            return colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.25)
        case .skeuomorphism:
            return colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.15)
        case .materialDesign:
            return .clear
        case .minimalism:
            return .clear
        case .glassmorphism:
            return colorScheme == .dark ? Color.white.opacity(0.15) : Color.white.opacity(0.8)
        case .boldStats:
            return colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08)
        case .neoBrutal:
            return colorScheme == .dark ? Color.white : Color.black
        case .editorial:
            return colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08)
        case .aurora:
            return Color.white.opacity(colorScheme == .dark ? 0.18 : 0.55)
        case .terminal:
            return Color(red: 0.2, green: 0.95, blue: 0.45).opacity(0.45)
        }
    }

    func cardShadow(for colorScheme: ColorScheme) -> Color {
        switch self {
        case .ambientGlass:
            return colorScheme == .dark ? Color.black.opacity(0.25) : Color.black.opacity(0.06)
        case .flatDesign:
            return .clear
        case .skeuomorphism:
            return colorScheme == .dark ? Color.black.opacity(0.4) : Color.black.opacity(0.15)
        case .materialDesign:
            return colorScheme == .dark ? Color.black.opacity(0.3) : Color.black.opacity(0.08)
        case .minimalism:
            return .clear
        case .glassmorphism:
            return colorScheme == .dark ? Color.black.opacity(0.2) : Color.black.opacity(0.06)
        case .boldStats:
            return colorScheme == .dark ? Color.black.opacity(0.25) : Color.black.opacity(0.06)
        case .neoBrutal:
            return Color.black.opacity(colorScheme == .dark ? 0.8 : 0.9)
        case .editorial:
            return Color.black.opacity(colorScheme == .dark ? 0.2 : 0.05)
        case .aurora:
            return Color.blue.opacity(colorScheme == .dark ? 0.25 : 0.1)
        case .terminal:
            return Color.green.opacity(0.15)
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .ambientGlass: return 22
        case .flatDesign: return 0
        case .skeuomorphism: return 16
        case .materialDesign: return 16
        case .minimalism: return 0
        case .glassmorphism: return 24
        case .boldStats: return 20
        case .neoBrutal: return 4
        case .editorial: return 2
        case .aurora: return 28
        case .terminal: return 0
        }
    }

    var sectionSpacing: CGFloat {
        switch self {
        case .ambientGlass: return 24
        case .flatDesign: return 18
        case .skeuomorphism: return 18
        case .materialDesign: return 16
        case .minimalism: return 32
        case .glassmorphism: return 20
        case .boldStats: return 24
        case .neoBrutal: return 16
        case .editorial: return 28
        case .aurora: return 22
        case .terminal: return 14
        }
    }

    var groupSpacing: CGFloat {
        switch self {
        case .ambientGlass: return 14
        case .flatDesign: return 8
        case .skeuomorphism: return 14
        case .materialDesign: return 12
        case .minimalism: return 16
        case .glassmorphism: return 14
        case .boldStats: return 16
        case .neoBrutal: return 10
        case .editorial: return 18
        case .aurora: return 14
        case .terminal: return 8
        }
    }

    var rowSpacing: CGFloat {
        switch self {
        case .ambientGlass: return 12
        case .flatDesign: return 10
        case .skeuomorphism: return 12
        case .materialDesign: return 12
        case .minimalism: return 12
        case .glassmorphism: return 12
        case .boldStats: return 14
        case .neoBrutal: return 10
        case .editorial: return 14
        case .aurora: return 12
        case .terminal: return 8
        }
    }

    var pagePadding: CGFloat {
        switch self {
        case .ambientGlass: return 20
        case .flatDesign: return 24
        case .skeuomorphism: return 16
        case .materialDesign: return 16
        case .minimalism: return 24
        case .glassmorphism: return 20
        case .boldStats: return 20
        case .neoBrutal: return 16
        case .editorial: return 22
        case .aurora: return 20
        case .terminal: return 14
        }
    }

    var showAmbientBlobs: Bool {
        switch self {
        case .ambientGlass, .glassmorphism, .boldStats, .aurora: return true
        case .flatDesign, .skeuomorphism, .materialDesign, .minimalism, .neoBrutal, .editorial, .terminal: return false
        }
    }

    var useDashedDividers: Bool {
        self == .flatDesign || self == .terminal
    }

    var useMonospaceText: Bool {
        self == .flatDesign || self == .terminal
    }

    var wrapsGroupsInCards: Bool {
        switch self {
        case .ambientGlass, .glassmorphism, .materialDesign, .skeuomorphism, .boldStats, .neoBrutal, .aurora:
            return true
        case .flatDesign, .minimalism, .editorial, .terminal:
            return false
        }
    }

    var usesBoldStatsLayout: Bool {
        self == .boldStats || self == .neoBrutal
    }

    func bodyFont(size: CGFloat) -> Font {
        switch self {
        case .ambientGlass, .glassmorphism, .aurora:
            return .system(size: size, weight: .medium, design: .rounded)
        case .flatDesign, .terminal:
            return .system(size: size, weight: .medium, design: .monospaced)
        case .skeuomorphism, .editorial, .minimalism:
            return .system(size: size, weight: self == .minimalism ? .regular : .medium, design: .serif)
        case .materialDesign:
            return .system(size: size, weight: .medium, design: .default)
        case .boldStats, .neoBrutal:
            return .system(size: size, weight: self == .neoBrutal ? .heavy : .semibold, design: .rounded)
        }
    }

    func headerFont(size: CGFloat) -> Font {
        switch self {
        case .ambientGlass, .glassmorphism, .boldStats, .aurora:
            return .system(size: size, weight: .bold, design: .rounded)
        case .flatDesign, .terminal:
            return .system(size: size, weight: .bold, design: .monospaced)
        case .skeuomorphism, .editorial:
            return .system(size: size, weight: .heavy, design: .serif)
        case .materialDesign:
            return .system(size: size, weight: .bold, design: .default)
        case .minimalism:
            return .system(size: size, weight: .light, design: .serif)
        case .neoBrutal:
            return .system(size: size, weight: .black, design: .rounded)
        }
    }

    func groupTitleFont(size: CGFloat) -> Font {
        switch self {
        case .ambientGlass, .glassmorphism, .boldStats, .aurora:
            return .system(size: size, weight: .bold, design: .rounded)
        case .flatDesign, .terminal:
            return .system(size: size, weight: .semibold, design: .monospaced)
        case .skeuomorphism, .editorial:
            return .system(size: size, weight: .bold, design: .serif)
        case .materialDesign:
            return .system(size: size, weight: .semibold, design: .default)
        case .minimalism:
            return .system(size: size, weight: .medium, design: .serif)
        case .neoBrutal:
            return .system(size: size, weight: .black, design: .rounded)
        }
    }

    func accentGradient(for colorScheme: ColorScheme) -> LinearGradient {
        switch self {
        case .ambientGlass:
            return LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .glassmorphism:
            return LinearGradient(colors: [.purple, .pink.opacity(0.85), .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .flatDesign:
            return LinearGradient(colors: [Color(red: 0.15, green: 0.15, blue: 0.15)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .skeuomorphism:
            return LinearGradient(
                colors: [Color(red: 0.2, green: 0.4, blue: 0.7), Color(red: 0.3, green: 0.5, blue: 0.8)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .materialDesign:
            return LinearGradient(colors: [.teal, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .minimalism:
            return LinearGradient(colors: [.primary], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .boldStats:
            return LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .neoBrutal:
            return LinearGradient(colors: [Color(red: 1.0, green: 0.84, blue: 0.0), Color.orange], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .editorial:
            return LinearGradient(colors: [Color(red: 0.55, green: 0.12, blue: 0.18), Color(red: 0.75, green: 0.25, blue: 0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .aurora:
            return LinearGradient(colors: [.cyan, .purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .terminal:
            return LinearGradient(colors: [Color(red: 0.2, green: 0.95, blue: 0.45)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    func successGradient(for colorScheme: ColorScheme) -> LinearGradient {
        LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    func cardBackgroundShape(cornerRadius: CGFloat) -> AnyShapeStyle {
        switch self {
        case .skeuomorphism:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Color.white.opacity(0.06), Color.black.opacity(0.06)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        default:
            return AnyShapeStyle(cardFill(for: .dark))
        }
    }

    func cardStroke(for colorScheme: ColorScheme, cornerRadius: CGFloat) -> AnyShapeStyle {
        AnyShapeStyle(cardBorder(for: colorScheme))
    }

    var liveActivityLanguage: LiveActivityVisualLanguage {
        switch self {
        case .ambientGlass: return .ambientGlass
        case .flatDesign: return .flatReceipt
        case .skeuomorphism: return .skeuomorphism
        case .materialDesign: return .material
        case .minimalism: return .minimal
        case .glassmorphism: return .glassmorphism
        case .boldStats: return .boldStats
        case .neoBrutal: return .neoBrutal
        case .editorial: return .editorial
        case .aurora: return .aurora
        case .terminal: return .terminal
        }
    }
}


// MARK: - 当前风格管理（ObservableObject 支持热切换）

@MainActor
final class UIStyleManager: ObservableObject {
    static let shared = UIStyleManager()

    @Published var selectedStyle: AppUIStyle {
        didSet {
            UserDefaults(suiteName: appGroupID)?.set(selectedStyle.rawValue, forKey: selectedUIStyleKey)
            // 通知主界面触发 Activity 同步；renderVersion 也会因 style key 变化而刷新。
            NotificationCenter.default.post(name: .focusLiveUIStyleDidChange, object: selectedStyle.rawValue)
        }
    }

    private init() {
        let defaults = UserDefaults(suiteName: appGroupID)
        let raw = defaults?.string(forKey: selectedUIStyleKey) ?? AppUIStyle.ambientGlass.rawValue
        self.selectedStyle = AppUIStyle(rawValue: raw) ?? .ambientGlass
    }
}

// MARK: - 毛玻璃容器修饰符（风格感知）

struct StyledGlassCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let style: AppUIStyle

    func body(content: Content) -> some View {
        let cr = style.cornerRadius
        content
            .background {
                cardBackground(cornerRadius: cr)
            }
            .shadow(
                color: style.cardShadow(for: colorScheme),
                radius: shadowRadius,
                y: shadowY
            )
    }

    private var shadowRadius: CGFloat {
        switch style {
        case .skeuomorphism: return 14
        case .materialDesign: return 8
        case .boldStats: return 18
        case .ambientGlass, .glassmorphism, .aurora: return 16
        case .neoBrutal: return 0
        case .editorial: return 6
        case .flatDesign, .minimalism, .terminal: return 0
        }
    }

    private var shadowY: CGFloat {
        switch style {
        case .skeuomorphism: return 8
        case .boldStats: return 10
        case .materialDesign: return 4
        case .neoBrutal: return 0
        case .editorial: return 3
        default: return 6
        }
    }

    @ViewBuilder
    private func cardBackground(cornerRadius cr: CGFloat) -> some View {
        switch style {
        case .minimalism, .flatDesign, .editorial, .terminal:
            if style == .editorial {
                RoundedRectangle(cornerRadius: cr, style: .continuous)
                    .fill(style.cardFill(for: colorScheme))
                    .overlay(alignment: .leading) {
                        Rectangle().fill(style.accentColor).frame(width: 3)
                    }
            } else if style == .terminal {
                RoundedRectangle(cornerRadius: cr, style: .continuous)
                    .fill(style.cardFill(for: colorScheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: cr, style: .continuous)
                            .stroke(Color(red: 0.2, green: 0.95, blue: 0.45).opacity(0.5), lineWidth: 1)
                    )
            } else {
                Color.clear
            }

        case .ambientGlass:
            RoundedRectangle(cornerRadius: cr, style: .continuous)
                .fill(style.cardFill(for: colorScheme))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cr, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cr, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: colorScheme == .dark
                                    ? [Color.white.opacity(0.18), Color.white.opacity(0.04)]
                                    : [Color.white.opacity(0.95), Color.white.opacity(0.25)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                )

        case .glassmorphism, .aurora:
            RoundedRectangle(cornerRadius: cr, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: cr, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: style == .aurora
                                    ? [Color.cyan.opacity(0.14), Color.purple.opacity(0.1), Color.pink.opacity(0.08)]
                                    : [
                                        Color.purple.opacity(colorScheme == .dark ? 0.12 : 0.08),
                                        Color.blue.opacity(colorScheme == .dark ? 0.08 : 0.04)
                                    ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cr, style: .continuous)
                        .stroke(Color.white.opacity(colorScheme == .dark ? 0.22 : 0.55), lineWidth: 0.8)
                )

        case .skeuomorphism:
            RoundedRectangle(cornerRadius: cr, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: colorScheme == .dark
                            ? [Color(red: 0.22, green: 0.22, blue: 0.25), Color(red: 0.14, green: 0.14, blue: 0.16)]
                            : [Color(red: 0.97, green: 0.96, blue: 0.93), Color(red: 0.88, green: 0.86, blue: 0.82)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cr, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(colorScheme == .dark ? 0.18 : 0.7),
                                    Color.black.opacity(colorScheme == .dark ? 0.35 : 0.12)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1.2
                        )
                )

        case .materialDesign:
            RoundedRectangle(cornerRadius: cr, style: .continuous)
                .fill(style.cardFill(for: colorScheme))
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.teal.opacity(colorScheme == .dark ? 0.55 : 0.75))
                        .frame(height: 4)
                        .clipShape(RoundedRectangle(cornerRadius: cr, style: .continuous))
                        .mask(
                            VStack(spacing: 0) {
                                Rectangle().frame(height: 4)
                                Spacer(minLength: 0)
                            }
                        )
                }

        case .boldStats:
            RoundedRectangle(cornerRadius: cr, style: .continuous)
                .fill(style.cardFill(for: colorScheme))
                .overlay(
                    RoundedRectangle(cornerRadius: cr, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.orange.opacity(0.55), Color.yellow.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.2
                        )
                )

        case .neoBrutal:
            RoundedRectangle(cornerRadius: cr, style: .continuous)
                .fill(style.cardFill(for: colorScheme))
                .overlay(
                    RoundedRectangle(cornerRadius: cr, style: .continuous)
                        .stroke(Color.primary, lineWidth: 2.5)
                )
                .background(
                    RoundedRectangle(cornerRadius: cr, style: .continuous)
                        .fill(Color.primary)
                        .offset(x: 4, y: 4)
                )
        }
    }

}

extension View {
    func styledGlassCard(_ style: AppUIStyle) -> some View {
        modifier(StyledGlassCardModifier(style: style))
    }

    /// 触感反馈：按下时轻微下沉
    func pressFeedback() -> some View {
        self.buttonStyle(PressFeedbackStyle())
    }
}

struct PressFeedbackStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            // 按下不是 momentum 手势，应即时下沉、无 overshoot。
            // reduceMotion：去掉缩放与弹簧，保留极短淡入做反馈。
            .animation(
                reduceMotion
                    ? .easeOut(duration: 0.12)
                    : MotionTokens.press,
                value: configuration.isPressed
            )
    }
}

// MARK: - 小票虚线分隔符

struct ReceiptDivider: View {
    @Environment(\.colorScheme) private var colorScheme
    let style: AppUIStyle
    var leadingIndent: CGFloat = 0

    var body: some View {
        if style.useDashedDividers {
            // 小票虚线：一行 dash 字符
            Text(String(repeating: "-", count: 48))
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundStyle(style.cardBorder(for: colorScheme))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, leadingIndent)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        } else {
            Divider()
                .opacity(0.4)
                .padding(.leading, leadingIndent)
        }
    }
}

// MARK: - 小票头部装饰

struct ReceiptHeader: View {
    let title: String
    let style: AppUIStyle
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if style.useDashedDividers {
            VStack(spacing: 6) {
                Text(String(repeating: "=", count: 48))
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(style.cardBorder(for: colorScheme))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(title.uppercased())
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .tracking(1.5)
                Text(String(repeating: "=", count: 48))
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(style.cardBorder(for: colorScheme))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        } else {
            EmptyView()
        }
    }
}

// MARK: - 环境光晕组件（带微妙浮动）

struct AmbientBlobs: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let style: AppUIStyle
    @State private var animateBlobs = false

    init(style: AppUIStyle) {
        self.style = style
    }

    var body: some View {
        if style.showAmbientBlobs {
            ZStack {
                // 光晕 1：蓝青渐变（缓慢浮动）
                Circle()
                    .fill(
                        LinearGradient(
                            colors: colorScheme == .dark
                                ? [Color.cyan.opacity(0.25), Color.blue.opacity(0.18)]
                                : [Color.cyan.opacity(0.15), Color.blue.opacity(0.10)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 300, height: 300)
                    .blur(radius: 80)
                    .offset(x: -140, y: -220)
                    .offset(y: animateBlobs ? 12 : -12)
                    .opacity(animateBlobs ? 0.9 : 1)

                // 光晕 2：薄荷蓝渐变（反相浮动）
                Circle()
                    .fill(
                        LinearGradient(
                            colors: colorScheme == .dark
                                ? [Color.mint.opacity(0.18), Color.blue.opacity(0.12)]
                                : [Color.mint.opacity(0.10), Color.blue.opacity(0.06)],
                            startPoint: .topTrailing,
                            endPoint: .bottomLeading
                        )
                    )
                    .frame(width: 280, height: 280)
                    .blur(radius: 70)
                    .offset(x: 140, y: 260)
                    .offset(y: animateBlobs ? -12 : 12)
                    .opacity(animateBlobs ? 0.8 : 1)

                // 光晕 3：紫色点缀
                if style == .ambientGlass || style == .glassmorphism || style == .aurora {
                    Circle()
                        .fill(Color.purple.opacity(colorScheme == .dark ? 0.10 : 0.06))
                        .frame(width: 200, height: 200)
                        .blur(radius: 60)
                        .offset(x: 100, y: -60)
                        .offset(x: animateBlobs ? 8 : -8)
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear {
                // reduceMotion: 静止停在中间态，不启动持续循环。
                // 正常：4 秒缓慢浮动，远离 0.2Hz（5s 周期）的前庭触发区间。
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                    animateBlobs = true
                }
            }
        }
    }
}

// MARK: - Glassmorphism 背景模糊

struct GlassmorphismBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    let style: AppUIStyle

    init(style: AppUIStyle) {
        self.style = style
    }

    var body: some View {
        if style == .glassmorphism {
            ZStack {
                // 彩色圆形背景
                Circle()
                    .fill(Color.purple.opacity(0.3))
                    .frame(width: 200, height: 200)
                    .blur(radius: 60)
                    .offset(x: -80, y: -150)
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 180, height: 180)
                    .blur(radius: 50)
                    .offset(x: 100, y: 200)
            }
            .allowsHitTesting(false)
        }
    }
}
