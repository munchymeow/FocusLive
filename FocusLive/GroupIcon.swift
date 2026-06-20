//
//  GroupIcon.swift
//  FocusLive
//
//  统一的分组图标渲染入口。
//  若 iconName 是 SF Symbol 名 → Image(systemName:)
//  若 iconName 是 emoji → Text(emoji) 回退显示
//

import SwiftUI

/// 统一分组图标渲染
struct GroupIcon: View {
    let name: String
    var size: CGFloat = 22
    var tint: Color = .blue

    var body: some View {
        if Self.isSFSymbolName(name) {
            Image(systemName: name)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: size * 2, height: size * 2)
                .background(Circle().fill(tint.opacity(0.12)))
        } else {
            Text(name)
                .font(.system(size: size))
                .frame(width: size * 2, height: size * 2)
        }
    }

    /// 判断字符串是否为 SF Symbol 名（非 emoji）
    /// 规则：非空、不含 emoji 字符、仅由 [a-z0-9._-] 组成、以小写字母开头
    static func isSFSymbolName(_ name: String) -> Bool {
        guard !name.isEmpty else { return false }
        let pattern = "^[a-z][a-z0-9._-]*$"
        return name.range(of: pattern, options: .regularExpression) != nil
    }
}
