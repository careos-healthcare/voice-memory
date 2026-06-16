import SwiftUI
import WidgetKit

// Keys mirror Runner/ObjectiveWidgetStorage.swift and buildWidgetPayload() in Dart.
private enum WidgetPayloadKeys {
  static let appGroupId = "group.com.voicememory.app"
  static let title = "title"
  static let body = "body"
  static let checkQuestion = "checkQuestion"
  static let primaryActionLabel = "primaryActionLabel"
  static let route = "route"
}

private struct TodayCheckEntry: TimelineEntry {
  let date: Date
  let title: String
  let body: String
  let checkQuestion: String
  let actionLabel: String
  let route: String
}

private enum TodayCheckPayload {
  static func read() -> TodayCheckEntry {
    let defaults = UserDefaults(suiteName: WidgetPayloadKeys.appGroupId)
    let title = defaults?.string(forKey: WidgetPayloadKeys.title)?.trimmingCharacters(
      in: .whitespacesAndNewlines
    ) ?? ""
    let body = defaults?.string(forKey: WidgetPayloadKeys.body)?.trimmingCharacters(
      in: .whitespacesAndNewlines
    ) ?? ""

    if title.isEmpty && body.isEmpty {
      return defaultsEntry()
    }

    return TodayCheckEntry(
      date: Date(),
      title: title.isEmpty ? defaultTitle : title,
      body: body.isEmpty ? defaultBody : body,
      checkQuestion: defaults?.string(forKey: WidgetPayloadKeys.checkQuestion)?
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
      actionLabel: nonEmpty(
        defaults?.string(forKey: WidgetPayloadKeys.primaryActionLabel),
        fallback: defaultAction
      ),
      route: nonEmpty(defaults?.string(forKey: WidgetPayloadKeys.route), fallback: "/record")
    )
  }

  static func launchURL(for route: String) -> URL {
    let trimmed = route.trimmingCharacters(in: .whitespacesAndNewlines)
    let path = trimmed.hasPrefix("/") ? String(trimmed.dropFirst()) : trimmed
    let safePath = path.isEmpty ? "record" : path
    return URL(string: "archiveme://\(safePath)")
      ?? URL(string: "archiveme://record")!
  }

  private static let defaultTitle = "Today\u{2019}s check"
  private static let defaultBody = "Open ArchiveMe to continue."
  private static let defaultAction = "Open"

  private static func defaultsEntry() -> TodayCheckEntry {
    TodayCheckEntry(
      date: Date(),
      title: defaultTitle,
      body: defaultBody,
      checkQuestion: "",
      actionLabel: defaultAction,
      route: "/record"
    )
  }

  private static func nonEmpty(_ value: String?, fallback: String) -> String {
    let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return trimmed.isEmpty ? fallback : trimmed
  }
}

private struct TodayCheckProvider: TimelineProvider {
  func placeholder(in context: Context) -> TodayCheckEntry {
    TodayCheckPayload.read()
  }

  func getSnapshot(in context: Context, completion: @escaping (TodayCheckEntry) -> Void) {
    completion(TodayCheckPayload.read())
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<TodayCheckEntry>) -> Void) {
    let entry = TodayCheckPayload.read()
    let refresh = Calendar.current.date(byAdding: .hour, value: 1, to: Date())
      ?? Date().addingTimeInterval(3600)
    completion(Timeline(entries: [entry], policy: .after(refresh)))
  }
}

private struct TodayCheckWidgetView: View {
  let entry: TodayCheckEntry

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(entry.title)
        .font(.headline)
        .lineLimit(2)
      Text(entry.body)
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .lineLimit(2)
      if !entry.checkQuestion.isEmpty {
        Text(entry.checkQuestion)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }
      Spacer(minLength: 0)
      Text(entry.actionLabel)
        .font(.caption.weight(.semibold))
        .foregroundStyle(.tint)
        .lineLimit(1)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .padding(12)
    .widgetURL(TodayCheckPayload.launchURL(for: entry.route))
  }
}

struct TodayCheckWidget: Widget {
  let kind = "TodayCheckWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: TodayCheckProvider()) { entry in
      if #available(iOS 17.0, *) {
        TodayCheckWidgetView(entry: entry)
          .containerBackground(.fill.tertiary, for: .widget)
      } else {
        TodayCheckWidgetView(entry: entry)
          .background(Color(.systemBackground))
      }
    }
    .configurationDisplayName("Today\u{2019}s check")
    .description("ArchiveMe keeps one useful check ready.")
    .supportedFamilies([.systemSmall])
  }
}

@main
struct TodayCheckWidgetBundle: WidgetBundle {
  var body: some Widget {
    TodayCheckWidget()
  }
}
