//
//  MotionTokens.swift
//  FocusLive
//
//  集中管理动画 token：缓动曲线、弹簧、duration。
//  所有 withAnimation / .animation 调用应优先引用这里，避免各处魔法数字散落。
//  Apple Design 原则：默认 critically-damped（dampingFraction 1.0），仅 momentum
//  交互加 bounce；高频控件避免 easeInOut 的慢起；reduceMotion 降为短交叉淡入。
//

import SwiftUI

enum MotionTokens {
    // MARK: - 弹簧
    /// 任务勾选 / 标准列表态切换。dampingFraction 0.8 提供极轻回弹。
    static let taskToggle: Animation = .spring(response: 0.25, dampingFraction: 0.8)

    /// 分组卡片展开/折叠。
    static let groupExpand: Animation = .spring(response: 0.3, dampingFraction: 0.8)

    /// 按压反馈：非惯性手势，应即时下沉、无 overshoot。
    static let press: Animation = .spring(response: 0.2, dampingFraction: 0.9)

    /// 高频控件状态切换（筛选栏、Icon 分类、样式选择等）。
    /// easeOut 起势快、收势缓，避免 easeInOut 的视觉「卡」感。
    static let quickState: Animation = .easeOut(duration: 0.18)

    /// Onboarding 翻页（属罕见一次性，可略长）。
    static let pageTurn: Animation = .easeOut(duration: 0.22)

    // MARK: - reduceMotion 降级
    /// 减弱动态效果时所有非反馈类动画降为短交叉淡入。
    static func toggle(reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeOut(duration: 0.15) : taskToggle
    }

    static func groupExpand(reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeOut(duration: 0.15) : groupExpand
    }

    static func quickState(reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeOut(duration: 0.1) : quickState
    }
}