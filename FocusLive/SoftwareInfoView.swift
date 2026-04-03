//
//  SoftwareInfoView.swift
//  FocusLive
//
//  Created by 赵豪伟 on 2026/1/14.
//

import SwiftUI

struct SoftwareInfoView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("软件说明")
                        .font(.title2.weight(.semibold))
                    Text("FocusScreen 是一款基于实时活动的待办事项应用，可将分组任务同步到锁屏与灵动岛。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("使用提示")
                        .font(.headline)
                    Text("请在系统设置中允许 FocusScreen 的实时活动，以便在锁屏与灵动岛展示任务进度。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Image("point")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("功能简介")
                        .font(.headline)
                    Text("• 支持分组管理与任务排序\n• 支持隐私空间与 Face ID 解锁\n• 支持锁屏实时活动快捷完成任务")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
        }
        .navigationTitle("软件说明")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        SoftwareInfoView()
    }
}
