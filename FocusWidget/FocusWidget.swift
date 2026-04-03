//
//  FocusWidget.swift
//  FocusWidget
//
//  Created by 赵豪伟 on 2026/1/13.
//

import WidgetKit
import SwiftUI

private struct DailyMotivationQuote {
    let quote: String
    let author: String
}

private let dailyMotivationQuotes: [DailyMotivationQuote] = [
    .init(quote: "慢一点没关系，持续向前就已经很好。", author: "去做"),
    .init(quote: "先完成眼前这一件，小小推进也算胜利。", author: "去做"),
    .init(quote: "把注意力还给当下，杂音就会慢慢退后。", author: "去做"),
    .init(quote: "今天不必完美，但要保持在路上。", author: "去做"),
    .init(quote: "专注不是紧绷，而是温和地回到手头的事。", author: "去做"),
    .init(quote: "当你开始行动，焦虑就失去了一半力量。", author: "去做"),
    .init(quote: "每一次认真完成，都会让明天更轻一点。", author: "去做"),
    .init(quote: "先做最重要的一步，节奏自然会出现。", author: "去做"),
    .init(quote: "允许自己慢，但不要停。", author: "去做"),
    .init(quote: "今天的专注，会在未来变成底气。", author: "去做"),
    .init(quote: "真正的进步，往往来自日复一日的小坚持。", author: "去做"),
    .init(quote: "把复杂留给过程，把此刻留给这一件事。", author: "去做")
]

enum WidgetDisplayData {
    case motivation(quote: String, author: String)

    static var placeholderData: WidgetDisplayData {
        .motivation(quote: "先完成眼前这一件，小小推进也算胜利。", author: "去做")
    }
}

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(
            date: Date(),
            configuration: ConfigurationAppIntent(),
            displayData: motivationDisplayData(for: Date())
        )
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        SimpleEntry(
            date: Date(),
            configuration: configuration,
            displayData: motivationDisplayData(for: Date())
        )
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let now = Date()
        let entry = SimpleEntry(
            date: now,
            configuration: configuration,
            displayData: motivationDisplayData(for: now)
        )

        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        let nextRefresh = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? now.addingTimeInterval(86_400)

        return Timeline(entries: [entry], policy: .after(nextRefresh))
    }

    private func motivationDisplayData(for date: Date) -> WidgetDisplayData {
        let quote = quoteForDate(date)
        return .motivation(quote: quote.quote, author: quote.author)
    }

    private func quoteForDate(_ date: Date) -> DailyMotivationQuote {
        let dayIndex = Int(Calendar.current.startOfDay(for: date).timeIntervalSinceReferenceDate / 86_400)
        let safeIndex = abs(dayIndex) % dailyMotivationQuotes.count
        return dailyMotivationQuotes[safeIndex]
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationAppIntent
    let displayData: WidgetDisplayData
}

struct FocusWidgetEntryView: View {
    var entry: Provider.Entry

    @Environment(\.widgetFamily) private var family
    @Environment(\.redactionReasons) private var redactionReasons

    private var isSmall: Bool {
        family == .systemSmall
    }

    var body: some View {
        let content = Group {
            switch entry.displayData {
            case .motivation(let quote, let author):
                motivationView(quote: quote, author: author)
            }
        }

        if redactionReasons.contains(.placeholder) {
            content.unredacted()
        } else {
            content
        }
    }

    private func motivationView(quote: String, author: String) -> some View {
        VStack(alignment: .leading, spacing: isSmall ? 10 : 14) {
            if isSmall {
                smallHeaderView
                smallMotivationBody(quote: quote, author: author)
            } else {
                headerView
                mediumMotivationBody(quote: quote, author: author)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(isSmall ? 14 : 16)
    }

    private var headerView: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.orange.opacity(0.9), Color.yellow.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: isSmall ? 24 : 28, height: isSmall ? 24 : 28)

                Image(systemName: "sparkles")
                    .font(.system(size: isSmall ? 10 : 11, weight: .bold))
                    .foregroundStyle(.white)
            }

            Text("每日鼓励")
                .font(isSmall ? .headline : .title3.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer()

            Text("Today")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var smallHeaderView: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.orange.opacity(0.9), Color.yellow.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 24, height: 24)

                Image(systemName: "sparkles")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
            }

            ViewThatFits(in: .horizontal) {
                Text("每日鼓励")
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text("今日")
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            Text(entry.date.formatted(.dateTime.month().day()))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.secondary.opacity(0.08))
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func smallMotivationBody(quote: String, author: String) -> some View {
        ViewThatFits(in: .vertical) {
            smallQuoteLayout(quote: quote, author: author, font: .callout.weight(.semibold), lineLimit: 4, showAuthor: true)
            smallQuoteLayout(quote: quote, author: author, font: .subheadline.weight(.medium), lineLimit: 5, showAuthor: true)
            smallQuoteLayout(quote: quote, author: author, font: .caption.weight(.medium), lineLimit: 6, showAuthor: false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func mediumMotivationBody(quote: String, author: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            RoundedRectangle(cornerRadius: 999, style: .continuous)
                .fill(Color.orange.opacity(0.16))
                .frame(width: 54, height: 5)

            Text(decoratedQuote(quote))
                .font(.body.weight(.medium))
                .lineLimit(5)
                .minimumScaleFactor(0.82)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            HStack {
                Text("保持专注，慢慢推进。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("——\(author)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func decoratedQuote(_ quote: String) -> String {
        if quote.hasPrefix("“") {
            return quote
        }
        return "“\(quote)”"
    }

    private func smallQuoteLayout(
        quote: String,
        author: String,
        font: Font,
        lineLimit: Int,
        showAuthor: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(decoratedQuote(quote))
                .font(font)
                .lineLimit(lineLimit)
                .minimumScaleFactor(0.72)
                .multilineTextAlignment(.leading)
                .lineSpacing(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            if showAuthor {
                Text("——\(author)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct FocusWidget: Widget {
    let kind: String = "FocusWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            FocusWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("FocusScreen 每日鼓励")
        .description("主屏幕每天显示一则新的鼓励文案。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

extension ConfigurationAppIntent {
    fileprivate static var smiley: ConfigurationAppIntent {
        let intent = ConfigurationAppIntent()
        intent.favoriteEmoji = "😀"
        return intent
    }

    fileprivate static var starEyes: ConfigurationAppIntent {
        let intent = ConfigurationAppIntent()
        intent.favoriteEmoji = "🤩"
        return intent
    }
}

#Preview(as: .systemSmall) {
    FocusWidget()
} timeline: {
    SimpleEntry(date: .now, configuration: .smiley, displayData: .placeholderData)
}

#Preview(as: .systemMedium) {
    FocusWidget()
} timeline: {
    SimpleEntry(date: .now, configuration: .starEyes, displayData: .placeholderData)
}
