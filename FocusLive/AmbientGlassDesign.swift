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

    var id: String { rawValue }

    var displayName: LocalizedStringResource {
        switch self {
        case .ambientGlass: return "Ambient Glass"
        case .flatDesign: return "Flat Design"
        case .skeuomorphism: return "Skeuomorphism"
        case .materialDesign: return "Material Design"
        case .minimalism: return "Minimalism"
        case .glassmorphism: return "Glassmorphism"
        case .boldStats: return "Bold Stats"
        }
    }

    var subtitle: LocalizedStringResource {
        switch self {
        case .ambientGlass: return "环境光晕 + 毛玻璃 + 渐变"
        case .flatDesign: return "纯色扁平、无阴影无渐变"
        case .skeuomorphism: return "拟物质感、纹理与立体阴影"
        case .materialDesign: return "Material You 风格、色彩提取"
        case .minimalism: return "极简留白、仅文字层级"
        case .glassmorphism: return "毛玻璃卡片、高斯模糊背景"
        case .boldStats: return "大胆数据仪表盘 + 毛玻璃点缀"
        }
    }

    var icon: String {
        switch self {
        case .ambientGlass: return "sparkles"
        case .flatDesign: return "square.fill"
        case .skeuomorphism: return "cube.fill"
        case .materialDesign: return "paintpalette.fill"
        case .minimalism: return "minus.circle"
        case .glassmorphism: return "aqi.medium"
        case .boldStats: return "chart.bar.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .ambientGlass: return .blue
        case .flatDesign: return .blue
        case .skeuomorphism: return Color(red: 0.2, green: 0.4, blue: 0.7)
        case .materialDesign: return .teal
        case .minimalism: return .primary
        case .glassmorphism: return .purple
        case .boldStats: return .orange
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
    func headerFont(size: CGFloat) -> Font
    func groupTitleFont(size: CGFloat) -> Font
    func accentGradient(for colorScheme: ColorScheme) -> LinearGradient
    func successGradient(for colorScheme: ColorScheme) -> LinearGradient
    func cardBackgroundShape(cornerRadius: CGFloat) -> AnyShapeStyle
    func cardStroke(for colorScheme: ColorScheme, cornerRadius: CGFloat) -> AnyShapeStyle
}

// MARK: - 风格 Token 实现

extension AppUIStyle: UIStyleTokens {
    func background(for colorScheme: ColorScheme) -> Color {
        switch self {
        case .ambientGlass:
            // 精炼色板：暖灰系 off-black/off-white，避免纯黑
            return colorScheme == .dark
                ? Color(red: 0.07, green: 0.07, blue: 0.09)
                : Color(red: 0.96, green: 0.96, blue: 0.97)
        case .flatDesign:
            // 小票纸张色：暖白米色 / 深炭灰
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
        }
    }

    func cardFill(for colorScheme: ColorScheme) -> Color {
        switch self {
        case .ambientGlass:
            // 真玻璃：半透明 + 材质感
            return colorScheme == .dark ? Color.white.opacity(0.05) : Color.white.opacity(0.75)
        case .flatDesign:
            // 小票：无填充，纯纸张
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
        }
    }

    func cardBorder(for colorScheme: ColorScheme) -> Color {
        switch self {
        case .ambientGlass:
            // 1px 内折射边框：白色高光
            return colorScheme == .dark ? Color.white.opacity(0.1) : Color.white.opacity(0.9)
        case .flatDesign:
            // 小票虚线分隔色
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
        }
    }

    func cardShadow(for colorScheme: ColorScheme) -> Color {
        switch self {
        case .ambientGlass:
            // 扩散阴影：宽而淡，偏背景色调
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
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .ambientGlass: return 22
        case .flatDesign: return 0  // 小票无圆角
        case .skeuomorphism: return 16
        case .materialDesign: return 16
        case .minimalism: return 0
        case .glassmorphism: return 24
        case .boldStats: return 20
        }
    }

    var sectionSpacing: CGFloat {
        switch self {
        case .ambientGlass: return 24
        case .flatDesign: return 18  // 小票紧凑间距
        case .skeuomorphism: return 18
        case .materialDesign: return 16
        case .minimalism: return 32
        case .glassmorphism: return 20
        case .boldStats: return 24
        }
    }

    var groupSpacing: CGFloat {
        switch self {
        case .ambientGlass: return 14
        case .flatDesign: return 8  // 小票紧凑行距
        case .skeuomorphism: return 14
        case .materialDesign: return 12
        case .minimalism: return 16
        case .glassmorphism: return 14
        case .boldStats: return 16
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
        }
    }

    var pagePadding: CGFloat {
        switch self {
        case .ambientGlass: return 20
        case .flatDesign: return 24  // 小票宽边距，模拟纸张
        case .skeuomorphism: return 16
        case .materialDesign: return 16
        case .minimalism: return 24
        case .glassmorphism: return 20
        case .boldStats: return 20
        }
    }

    var showAmbientBlobs: Bool {
        switch self {
        case .ambientGlass, .glassmorphism, .boldStats: return true
        case .flatDesign, .skeuomorphism, .materialDesign, .minimalism: return false
        }
    }

    var useDashedDividers: Bool {
        self == .flatDesign
    }

    var useMonospaceText: Bool {
        self == .flatDesign
    }

    func headerFont(size: CGFloat) -> Font {
        switch self {
        case .ambientGlass, .glassmorphism, .boldStats:
            return .system(size: size, weight: .bold, design: .rounded)
        case .flatDesign:
            return .system(size: size, weight: .bold, design: .monospaced)
        case .skeuomorphism:
            return .system(size: size, weight: .heavy, design: .serif)
        case .materialDesign:
            return .system(size: size, weight: .bold, design: .default)
        case .minimalism:
            return .system(size: size, weight: .light, design: .serif)
        }
    }

    func groupTitleFont(size: CGFloat) -> Font {
        switch self {
        case .ambientGlass, .glassmorphism, .boldStats:
            return .system(size: size, weight: .bold, design: .rounded)
        case .flatDesign:
            return .system(size: size, weight: .semibold, design: .monospaced)
        case .skeuomorphism:
            return .system(size: size, weight: .bold, design: .serif)
        case .materialDesign:
            return .system(size: size, weight: .semibold, design: .default)
        case .minimalism:
            return .system(size: size, weight: .medium, design: .serif)
        }
    }

    func accentGradient(for colorScheme: ColorScheme) -> LinearGradient {
        switch self {
        case .ambientGlass, .glassmorphism:
            return LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .flatDesign:
            return LinearGradient(colors: [.blue], startPoint: .topLeading, endPoint: .bottomTrailing)
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
        }
    }

    func successGradient(for colorScheme: ColorScheme) -> LinearGradient {
        switch self {
        case .boldStats:
            return LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
        default:
            return LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
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
            return AnyShapeStyle(cardFill(for: .dark)) // placeholder, actual color passed at call site
        }
    }

    func cardStroke(for colorScheme: ColorScheme, cornerRadius: CGFloat) -> AnyShapeStyle {
        return AnyShapeStyle(cardBorder(for: colorScheme))
    }
}

// MARK: - 当前风格管理（ObservableObject 支持热切换）

@MainActor
final class UIStyleManager: ObservableObject {
    static let shared = UIStyleManager()

    @Published var selectedStyle: AppUIStyle {
        didSet {
            UserDefaults(suiteName: appGroupID)?.set(selectedStyle.rawValue, forKey: "selectedUIStyle")
        }
    }

    private init() {
        let defaults = UserDefaults(suiteName: appGroupID)
        let raw = defaults?.string(forKey: "selectedUIStyle") ?? AppUIStyle.ambientGlass.rawValue
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
            .background(
                Group {
                    if style == .minimalism || style == .flatDesign {
                        // 小票/极简：无背景，无阴影，纯纸张
                        Color.clear
                    } else if style == .ambientGlass {
                        // 真玻璃折射：底色 + 内边框高光 + 内阴影 + 外扩散阴影
                        RoundedRectangle(cornerRadius: cr, style: .continuous)
                            .fill(style.cardFill(for: colorScheme))
                            .overlay(
                                // 1px 内折射边框：顶部高光
                                RoundedRectangle(cornerRadius: cr, style: .continuous)
                                    .stroke(
                                        LinearGradient(
                                            colors: colorScheme == .dark
                                                ? [Color.white.opacity(0.12), Color.white.opacity(0.04)]
                                                : [Color.white.opacity(0.9), Color.white.opacity(0.3)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        ),
                                        lineWidth: 1
                                    )
                            )
                            .overlay(
                                // 内阴影：模拟玻璃边缘折射
                                RoundedRectangle(cornerRadius: cr, style: .continuous)
                                    .stroke(
                                        LinearGradient(
                                            colors: colorScheme == .dark
                                                ? [Color.black.opacity(0.15), Color.clear]
                                                : [Color.black.opacity(0.04), Color.clear],
                                            startPoint: .bottom,
                                            endPoint: .top
                                        ),
                                        lineWidth: 1
                                    )
                            )
                    } else if style == .skeuomorphism {
                        RoundedRectangle(cornerRadius: cr, style: .continuous)
                            .fill(style.cardFill(for: colorScheme))
                            .overlay(
                                RoundedRectangle(cornerRadius: cr, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.05), Color.clear],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: cr, style: .continuous)
                                    .stroke(style.cardBorder(for: colorScheme), lineWidth: 1)
                            )
                    } else if style == .glassmorphism {
                        RoundedRectangle(cornerRadius: cr, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: cr, style: .continuous)
                                    .stroke(Color.white.opacity(colorScheme == .dark ? 0.15 : 0.5), lineWidth: 0.5)
                            )
                    } else {
                        RoundedRectangle(cornerRadius: cr, style: .continuous)
                            .fill(style.cardFill(for: colorScheme))
                            .overlay(
                                RoundedRectangle(cornerRadius: cr, style: .continuous)
                                    .stroke(style.cardBorder(for: colorScheme), lineWidth: 0.5)
                            )
                    }
                }
            )
            // 扩散阴影：宽而淡
            .shadow(color: style.cardShadow(for: colorScheme), radius: style == .skeuomorphism ? 12 : 15, y: style == .skeuomorphism ? 6 : 5)
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
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
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
                if style == .ambientGlass || style == .glassmorphism {
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
                // 8 秒周期缓慢浮动，营造空间呼吸感
                withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
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
