//
//  SFSymbolCatalog.swift
//  FocusLive
//
//  SF Symbol 分类目录，用于图标选择器。
//

import Foundation

/// SF Symbol 分类目录
struct SFSymbolCatalog {
    struct Category: Identifiable {
        let id: String
        let name: String
        let symbols: [String]
    }

    static let categories: [Category] = [
        Category(id: "work", name: "工作", symbols: [
            "briefcase.fill", "folder.fill", "doc.text.fill", "chart.bar.fill",
            "desktopcomputer", "printer.fill", "phone.fill", "envelope.fill",
            "pencil", "pin.fill", "calendar", "clock.fill",
            "list.bullet", "tray.full.fill", "paperclip", "keyboard.fill"
        ]),
        Category(id: "study", name: "学习", symbols: [
            "books.vertical.fill", "book.closed.fill", "text.book.closed.fill",
            "graduationcap.fill", "building.columns.fill", "microscope.fill",
            "telescope.fill", "flask.fill", "brain.head.profile",
            "pencil.and.ruler.fill", "studentdesk", "character.book.closed.fill"
        ]),
        Category(id: "time", name: "时间", symbols: [
            "alarm.fill", "stopwatch.fill", "clock.fill", "timer",
            "hourglass", "clock.arrow.circlepath", "calendar.badge.clock",
            "deskclock.fill"
        ]),
        Category(id: "priority", name: "优先", symbols: [
            "star.fill", "star.circle.fill", "lightbulb.fill", "flame.fill",
            "exclamationmark.circle.fill", "exclamationmark.2",
            "diamond.fill", "target", "trophy.fill", "rosette",
            "checkmark.seal.fill", "bell.fill", "bell.badge.fill",
            "bolt.fill", "sparkles"
        ]),
        Category(id: "life", name: "生活", symbols: [
            "house.fill", "chair.lounge.fill", "bed.double.fill",
            "shower.fill", "leaf.fill", "leaf.arrow.triangle.circlepath",
            "heart.fill", "pawprint.fill", "paintpalette.fill",
            "fork.knife", "cup.and.saucer.fill", "sofa.fill",
            "lamp.desk.fill", "washer.fill"
        ]),
        Category(id: "health", name: "健康", symbols: [
            "figure.run", "bicycle", "dumbbell.fill", "figure.yoga",
            "figure.pool.swim", "sportscourt.fill", "heart.text.square.fill",
            "cross.case.fill", "pill.fill", "stethoscope",
            "figure.walk", "figure.mind.and.body", "lungs.fill"
        ]),
        Category(id: "shopping", name: "购物", symbols: [
            "cart.fill", "bag.fill", "creditcard.fill", "banknote.fill",
            "shippingbox.fill", "giftcard.fill", "basket.fill",
            "storefront.fill"
        ]),
        Category(id: "travel", name: "出行", symbols: [
            "car.fill", "bus.fill", "tram.fill", "airplane",
            "fuelpump.fill", "steeringwheel", "map.fill", "compass.drawing",
            "bicycle", "ferry.fill", "bed.double.circle.fill",
            "ticket.fill"
        ]),
        Category(id: "social", name: "社交", symbols: [
            "bubble.left.fill", "bubble.left.and.bubble.right.fill",
            "person.2.fill", "person.3.fill", "handshake.fill",
            "gift.fill", "party.popper.fill", "hand.wave.fill",
            "heart.fill", "envelope.heart.fill", "phone.bubble.left.fill"
        ]),
        Category(id: "entertainment", name: "娱乐", symbols: [
            "gamecontroller.fill", "film.fill", "music.mic.fill",
            "guitars.fill", "paintbrush.fill", "camera.fill",
            "tv.fill", "theatermasks.fill", "headphones",
            "die.face.fill", "dice.fill", "popcorn.fill",
            "cup.and.saucer.fill", "radio.fill"
        ]),
        Category(id: "weather", name: "天气", symbols: [
            "sun.max.fill", "moon.stars.fill", "star.fill",
            "rainbow", "cloud.fill", "cloud.rain.fill",
            "snowflake", "water.waves", "tornado",
            "sunrise.fill", "sunset.fill", "cloud.bolt.fill"
        ])
    ]

    /// 所有 SF Symbol 的平铺列表（供快速查找）
    static let allSymbols: [String] = categories.flatMap { $0.symbols }
}
