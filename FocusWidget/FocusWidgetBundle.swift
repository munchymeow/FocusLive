//
//  FocusWidgetBundle.swift
//  FocusWidget
//
//  Created by 赵豪伟 on 2026/1/13.
//

import WidgetKit
import SwiftUI

@main
struct FocusWidgetBundle: WidgetBundle {
    var body: some Widget {
        FocusWidget()
        FocusTaskWidget()    // 主屏任务列表 Widget
        FocusWidgetControl()
        FocusActivityWidget()  // Live Activity 视图
    }
}
