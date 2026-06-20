//
//  AmbientGlassDesign.swift
//  FocusLive
//
//  Ambient Glass 设计语言共享组件
//  环境光晕 + 毛玻璃内容层 + 渐变交互层
//

import SwiftUI

// MARK: - 设计 Token

enum AmbientGlass {
    /// 页面背景色
    static func background(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.06, green: 0.06, blue: 0.08)
            : Color(red: 0.97, green: 0.97, blue: 0.99)
    }

    /// 毛玻璃容器底色
    static func glassFill(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.white.opacity(0.04)
            : Color.black.opacity(0.02)
    }

    /// 毛玻璃容器边框
    static func glassBorder(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color.black.opacity(0.05)
    }

    /// 毛玻璃容器阴影
    static func glassShadow(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.black.opacity(0.2)
            : Color.black.opacity(0.04)
    }

    /// 主渐变色（蓝→青）
    static let accentGradient = LinearGradient(
        colors: [.blue, .cyan],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// 横向渐变色（蓝→青）
    static let accentGradientHorizontal = LinearGradient(
        colors: [.blue, .cyan],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// 完成渐变色（绿→薄荷）
    static let successGradient = LinearGradient(
        colors: [.green, .mint],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// 圆角半径
    static let cornerRadius: CGFloat = 20
    static let smallCornerRadius: CGFloat = 14
    static let iconCornerRadius: CGFloat = 10

    /// 间距
    static let sectionSpacing: CGFloat = 20
    static let groupSpacing: CGFloat = 14
    static let rowSpacing: CGFloat = 12
    static let pagePadding: CGFloat = 20
}

// MARK: - 环境光晕组件

struct AmbientBlobs: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            // 光晕 1：蓝青渐变，左上偏移
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

            // 光晕 2：薄荷蓝渐变，右下偏移
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

            // 光晕 3：紫色点缀
            Circle()
                .fill(Color.purple.opacity(colorScheme == .dark ? 0.10 : 0.06))
                .frame(width: 200, height: 200)
                .blur(radius: 60)
                .offset(x: 100, y: -60)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - 毛玻璃容器修饰符

struct GlassCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: AmbientGlass.cornerRadius, style: .continuous)
                    .fill(AmbientGlass.glassFill(for: colorScheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: AmbientGlass.cornerRadius, style: .continuous)
                            .stroke(AmbientGlass.glassBorder(for: colorScheme), lineWidth: 0.5)
                    )
            )
            .shadow(color: AmbientGlass.glassShadow(for: colorScheme), radius: 10, y: 4)
    }
}

extension View {
    func glassCard() -> some View {
        modifier(GlassCardModifier())
    }
}
