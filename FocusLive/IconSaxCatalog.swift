//
//  IconSaxCatalog.swift
//  FocusLive
//
//  IconSax 开源图标库集成。
//  资源来源：https://github.com/lusaxweb/iconsax （MIT 风格开放许可，无明确 LICENSE 文件）。
//  图标以矢量 SVG 形式打包进 Asset Catalog，开启 preserves-vector-representation
//  让 SwiftUI 在任何缩放下保持锐利边缘；渲染走 UIImage（系统级 SVG 解码），
//  无需第三方库，支持 Widget / Live Activity 等所有进程。
//
//  字符串约定：
//   - iconName 形如 "iconsax.briefcase" → 渲染 IconSax 资源
//   - 普通 SF Symbol 名（如 "folder.fill"）→ 走 GroupIcon 原路径
//   - emoji → 文本回退
//

import SwiftUI

/// IconSax 图标分类目录，结构与 SFSymbolCatalog 对齐。
struct IconSaxCatalog {
    struct Category: Identifiable {
        let id: String
        let name: String
        /// 资源名（不含 "iconsax." 前缀，渲染时再加）
        let icons: [String]
    }

    /// 全部分类。按 IconSax 网站分组思路组织。
    /// 仅引用实际打包进 Asset Catalog 的图标名（不含 "iconsax." 前缀）。
    static let categories: [Category] = [
        Category(id: "work", name: "工作", icons: [
            "briefcase", "bag", "document", "folder", "book", "book-1",
            "cpu", "wallet", "shop", "gift", "task-square", "note",
            "text", "edit", "archive", "box", "category", "setting-2"
        ]),
        Category(id: "time", name: "时间", icons: [
            "calendar", "clock", "timer"
        ]),
        Category(id: "life", name: "生活", icons: [
            "home", "heart", "coffee", "cup", "car", "airplane", "location",
            "camera", "image", "video", "music", "shopping-cart",
            "volume-high", "volume-low", "lamp-on", "flash"
        ]),
        Category(id: "health", name: "健康", icons: [
            "activity"
        ]),
        Category(id: "nature", name: "自然", icons: [
            "sun", "moon", "cloud"
        ]),
        Category(id: "social", name: "社交", icons: [
            "user", "profile", "message", "sms", "call", "notification",
            "book-saved", "like", "dislike"
        ]),
        Category(id: "status", name: "状态", icons: [
            "tick-circle", "close-circle", "tick-square", "star",
            "medal", "flag", "chart-2", "trend-up", "search-normal"
        ])
    ]

    static let allIcons: [String] = categories.flatMap { $0.icons }

    /// IconSax 存储名约定前缀。
    /// 数据层用点号（"iconsax.briefcase"），Asset Catalog 用连字符（"iconsax-briefcase"）。
    static let prefix = "iconsax."

    /// 判断字符串是否为 IconSax 资源名（以 "iconsax." 开头）。
    static func isIconSaxName(_ name: String) -> Bool {
        name.hasPrefix(prefix)
    }

    /// 把 icon key（如 "briefcase"）转成存储名（"iconsax.briefcase"）。
    static func storageName(for key: String) -> String {
        if key.hasPrefix(prefix) { return key }
        return prefix + key
    }

    /// 兼容旧调用名。
    static func resourceName(for key: String) -> String {
        storageName(for: key)
    }

    /// 把存储名或 key 转成 Asset Catalog 资源名（"iconsax-briefcase"）。
    static func assetName(for name: String) -> String {
        let key = name.hasPrefix(prefix)
            ? String(name.dropFirst(prefix.count))
            : name
        return "iconsax-\(key)"
    }
}

/// 渲染 IconSax 图标。优先用矢量 SVG 资源（preserves-vector-representation）。
struct IconSaxView: View {
    let name: String
    var size: CGFloat = 22
    var tint: Color = .blue

    private var assetName: String {
        IconSaxCatalog.assetName(for: name)
    }

    var body: some View {
        Image(assetName)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .foregroundStyle(tint)
    }
}