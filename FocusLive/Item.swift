//
//  Item.swift
//  FocusLive
//
//  Created by 赵豪伟 on 2026/1/13.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
