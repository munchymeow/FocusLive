//
//  IconPickerView.swift
//  FocusLive
//
//  三模式图标选择器：SF Symbols（默认）+ IconSax + Emoji
//

import SwiftUI

struct IconPickerView: View {
    @Binding var selectedIcon: String
    var onDismiss: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab: IconTab = .sfSymbols
    @State private var selectedCategoryIndex: Int = 0

    private enum IconTab: String, CaseIterable {
        case sfSymbols = "SF 图标"
        case iconSax = "IconSax"
        case emoji = "Emoji"
    }

    private let columns = [GridItem(.adaptive(minimum: 52))]

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 顶部 tab 切换
                Picker("模式", selection: $selectedTab) {
                    ForEach(IconTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

                if selectedTab == .sfSymbols {
                    sfSymbolsContent
                } else if selectedTab == .iconSax {
                    iconSaxContent
                } else {
                    emojiContent
                }
            }
            .navigationTitle("选择图标")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - SF Symbols Tab

    private var sfSymbolsContent: some View {
        VStack(spacing: 0) {
            // 分类标签栏
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(SFSymbolCatalog.categories.indices, id: \.self) { index in
                        let category = SFSymbolCatalog.categories[index]
                        Button(action: {
                            withAnimation(.easeOut(duration: 0.15)) {
                                selectedCategoryIndex = index
                            }
                        }) {
                            Text(category.name)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(selectedCategoryIndex == index ? .white : .primary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(selectedCategoryIndex == index ? Color.blue : Color.gray.opacity(0.12))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }

            Divider()

            // SF Symbol 网格
            ScrollView {
                let category = SFSymbolCatalog.categories[selectedCategoryIndex]
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(category.symbols, id: \.self) { symbolName in
                        Button(action: {
                            selectedIcon = symbolName
                            onDismiss()
                            dismiss()
                        }) {
                            Image(systemName: symbolName)
                                .font(.system(size: 24))
                                .foregroundStyle(selectedIcon == symbolName ? .blue : .primary)
                                .frame(width: 52, height: 52)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(selectedIcon == symbolName ? Color.blue.opacity(0.15) : Color.gray.opacity(0.08))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(selectedIcon == symbolName ? Color.blue : Color.clear, lineWidth: 2)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
        }
    }

    // MARK: - IconSax Tab

    private var iconSaxContent: some View {
        VStack(spacing: 0) {
            // 分类标签栏
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(IconSaxCatalog.categories.indices, id: \.self) { index in
                        let category = IconSaxCatalog.categories[index]
                        Button(action: {
                            withAnimation(.easeOut(duration: 0.15)) {
                                selectedCategoryIndex = index
                            }
                        }) {
                            Text(category.name)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(selectedCategoryIndex == index ? .white : .primary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(selectedCategoryIndex == index ? Color.blue : Color.gray.opacity(0.12))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }

            Divider()

            // IconSax 网格
            ScrollView {
                let category = IconSaxCatalog.categories[selectedCategoryIndex]
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(category.icons, id: \.self) { iconKey in
                        let full = IconSaxCatalog.resourceName(for: iconKey)
                        Button(action: {
                            selectedIcon = full
                            onDismiss()
                            dismiss()
                        }) {
                            IconSaxView(name: full, size: 24, tint: selectedIcon == full ? .blue : .primary)
                                .frame(width: 52, height: 52)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(selectedIcon == full ? Color.blue.opacity(0.15) : Color.gray.opacity(0.08))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(selectedIcon == full ? Color.blue : Color.clear, lineWidth: 2)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
        }
    }

    // MARK: - Emoji Tab

    private var emojiContent: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(commonEmojis.indices, id: \.self) { index in
                    let emoji = commonEmojis[index]
                    Button(action: {
                        selectedIcon = emoji
                        onDismiss()
                        dismiss()
                    }) {
                        Text(emoji)
                            .font(.system(size: 30))
                            .frame(width: 52, height: 52)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selectedIcon == emoji ? Color.blue.opacity(0.2) : Color.gray.opacity(0.08))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(selectedIcon == emoji ? Color.blue : Color.clear, lineWidth: 2)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }
}
