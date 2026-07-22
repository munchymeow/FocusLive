//
//  Theme.swift
//  FocusLive
//
//  Design system tokens — centralized colors, corner radii, shadows.
//

import SwiftUI

// MARK: - Design Tokens

enum Theme {
    // MARK: Corner Radii
    static let cardCornerRadius: CGFloat = 20
    static let smallCornerRadius: CGFloat = 12
    static let buttonCornerRadius: CGFloat = 10
    static let progressCornerRadius: CGFloat = 4
    static let capsuleCornerRadius: CGFloat = 999

    // MARK: Shadows
    static func cardShadow(colorScheme: ColorScheme) -> some View {
        Color.clear
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.06),
                radius: 12, x: 0, y: 4
            )
    }

    static func elevatedShadow(colorScheme: ColorScheme) -> some View {
        Color.clear
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.08),
                radius: 14, x: 0, y: 6
            )
    }

    // MARK: Colors
    static let accentColor = Color.blue
    static let successColor = Color.green
    static let warningColor = Color.orange

    static func cardBackground(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(.systemGray6)
            : Color.white
    }

    static func secondaryBackground(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(.systemGray5)
            : Color(.systemGray6)
    }

    // MARK: Typography
    static let sectionHeaderFont: Font = .subheadline.weight(.semibold)
    static let bodyFont: Font = .subheadline
    static let captionFont: Font = .caption
    static let smallCaptionFont: Font = .caption2
}
