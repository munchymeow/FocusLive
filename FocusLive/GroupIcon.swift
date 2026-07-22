//
//  GroupIcon.swift
//  FocusLive
//
//  统一的分组图标渲染入口。
//  若 iconName 以 "iconsax." 开头 → IconSaxView 模板渲染（矢量 SVG 资源）
//  若 iconName 是 SF Symbol 名 → Image(systemName:) 渲染
//  若 iconName 是 emoji → Text(emoji) 回退显示
//
//  Widget / Live Activity 也编译此文件，与主 App 共用同一渲染路径。
//

import SwiftUI

/// 统一分组图标渲染
struct GroupIcon: View {
    let name: String
    var size: CGFloat = 22
    var tint: Color = .blue
    /// 是否显示圆形色底（主 App 默认开启；灵动岛 / 紧凑 Widget 关闭）。
    var showsChrome: Bool = true

    var body: some View {
        iconContent
            .frame(
                width: showsChrome ? size * 2 : size,
                height: showsChrome ? size * 2 : size
            )
            .background {
                if showsChrome {
                    Circle().fill(tint.opacity(0.12))
                }
            }
            // 灵动岛 / 紧凑区域空间极小，强制裁进框内，避免被系统裁切半边。
            .clipped()
            .contentShape(Rectangle())
    }

    @ViewBuilder
    private var iconContent: some View {
        if IconSaxCatalog.isIconSaxName(name) {
            IconSaxView(name: name, size: size * (showsChrome ? 1 : 0.92), tint: tint)
        } else if Self.isSFSymbolName(name) {
            Image(systemName: name)
                .font(.system(size: size * (showsChrome ? 1 : 0.82), weight: .semibold))
                .foregroundStyle(tint)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .frame(width: size, height: size)
                .scaledToFit()
        } else {
            Text(name)
                .font(.system(size: size * (showsChrome ? 1 : 0.78)))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .frame(width: size, height: size)
        }
    }

    /// 判断字符串是否为 SF Symbol 名（非 emoji）
    static func isSFSymbolName(_ name: String) -> Bool {
        guard !name.isEmpty else { return false }
        if IconSaxCatalog.isIconSaxName(name) { return false }
        if name.contains(" ") || name.contains(where: { $0.isLetter && !$0.isASCII }) { return false }
        let pattern = "^[a-zA-Z][a-zA-Z0-9._-]*$"
        return name.range(of: pattern, options: .regularExpression) != nil
    }
}