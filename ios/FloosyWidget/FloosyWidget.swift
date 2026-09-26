import SwiftUI
import WidgetKit

private let appGroup = "group.net.floosy.app"

struct FloosyEntry: TimelineEntry {
  let date: Date
  let balance: String
  let spent: String
  let income: String
}

struct FloosyProvider: TimelineProvider {
  func placeholder(in context: Context) -> FloosyEntry {
    FloosyEntry(date: Date(), balance: "E£0.00", spent: "E£0.00", income: "E£0.00")
  }

  func getSnapshot(in context: Context, completion: @escaping (FloosyEntry) -> Void) {
    completion(entry())
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<FloosyEntry>) -> Void) {
    completion(Timeline(entries: [entry()], policy: .never))
  }

  private func entry() -> FloosyEntry {
    let defaults = UserDefaults(suiteName: appGroup)
    return FloosyEntry(
      date: Date(),
      balance: defaults?.string(forKey: "balance") ?? "E£0.00",
      spent: defaults?.string(forKey: "spent") ?? "E£0.00",
      income: defaults?.string(forKey: "income") ?? "E£0.00"
    )
  }
}

struct FloosyWidgetView: View {
  let entry: FloosyEntry

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Floosy").font(.caption).foregroundStyle(.white.opacity(0.8))
      Text(entry.balance).font(.title2.bold()).foregroundStyle(.white)
      HStack {
        Text("Income \(entry.income)")
        Spacer()
        Text("Spent \(entry.spent)")
      }
      .font(.caption2)
      .foregroundStyle(.white.opacity(0.9))
    }
    .containerBackground(
      LinearGradient(colors: [Color(red: 0.05, green: 0.41, blue: 0.31), Color(red: 0.11, green: 0.59, blue: 0.44)], startPoint: .topLeading, endPoint: .bottomTrailing),
      for: .widget
    )
    .widgetURL(URL(string: "floosy://overview"))
  }
}

@main
struct FloosyWidget: Widget {
  let kind = "FloosyWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: FloosyProvider()) { entry in
      FloosyWidgetView(entry: entry)
    }
    .configurationDisplayName("Floosy summary")
    .description("Balance, income, and spending at a glance.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}
