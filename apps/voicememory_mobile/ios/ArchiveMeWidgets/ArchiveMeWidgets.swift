import AppIntents
import SwiftUI
import WidgetKit

private struct ArchiveEntry: TimelineEntry {
  let date: Date
  let payload: [String: Any]
}

private struct ArchiveProvider: TimelineProvider {
  func placeholder(in context: Context) -> ArchiveEntry {
    ArchiveEntry(date: Date(), payload: [:])
  }

  func getSnapshot(in context: Context, completion: @escaping (ArchiveEntry) -> Void) {
    completion(load())
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<ArchiveEntry>) -> Void) {
    let entry = load()
    let refresh = Calendar.current.date(byAdding: .minute, value: 30, to: entry.date)
      ?? entry.date.addingTimeInterval(1_800)
    completion(Timeline(entries: [entry], policy: .after(refresh)))
  }

  private func load() -> ArchiveEntry {
    let payload = (try? SecureAppGroupStore.shared.readJSONObject(
      category: "widget",
      identifier: "current"
    )) ?? [:]
    return ArchiveEntry(date: Date(), payload: payload)
  }
}

private enum WidgetPayload {
  static func dictionary(_ key: String, in payload: [String: Any]) -> [String: Any] {
    payload[key] as? [String: Any] ?? [:]
  }

  static func string(_ key: String, in payload: [String: Any], fallback: String) -> String {
    let value = (payload[key] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return value.isEmpty ? fallback : value
  }

  static func integer(_ key: String, in payload: [String: Any]) -> Int {
    (payload[key] as? NSNumber)?.intValue ?? (payload[key] as? Int) ?? 0
  }

  static func boolean(_ key: String, in payload: [String: Any]) -> Bool {
    (payload[key] as? NSNumber)?.boolValue ?? (payload[key] as? Bool) ?? false
  }

  static func accentColor(in payload: [String: Any]) -> Color {
    switch string("theme", in: payload, fallback: "system") {
    case "midnight": return Color(red: 0.45, green: 0.58, blue: 1)
    case "sunrise": return Color(red: 0.88, green: 0.36, blue: 0.16)
    case "highContrast": return .yellow
    default: return .accentColor
    }
  }

  static func deepLink(route: String, source: String) -> URL {
    let trimmed = route.trimmingCharacters(in: .whitespacesAndNewlines)
    let path = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    var components = URLComponents()
    components.scheme = "archiveme"
    components.host = path.isEmpty ? "record" : path
    components.queryItems = [URLQueryItem(name: "source", value: source)]
    return components.url ?? URL(string: "archiveme://record")!
  }
}

@available(iOSApplicationExtension 16.0, *)
private struct CompleteHabitIntent: AppIntent {
  static let title: LocalizedStringResource = "Complete habit"
  static let description = IntentDescription("Marks this ArchiveMe habit complete for today.")
  static let openAppWhenRun = false

  @Parameter(title: "Step ID")
  var stepId: String

  init() {
    stepId = ""
  }

  init(stepId: String) {
    self.stepId = stepId
  }

  func perform() async throws -> some IntentResult {
    let normalized = stepId.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalized.isEmpty, normalized.count <= 128 else {
      return .result()
    }
    let components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
    guard let year = components.year, let month = components.month, let day = components.day else {
      return .result()
    }
    let localDay = String(format: "%04d-%02d-%02d", year, month, day)
    try SecureAppGroupStore.shared.writeJSONObject(
      [
        "type": "completeHabit",
        "stepId": normalized,
        "localDay": localDay,
      ],
      category: "widget-action"
    )
    WidgetCenter.shared.reloadAllTimelines()
    return .result()
  }
}

private struct WidgetSurface<Content: View>: View {
  @Environment(\.widgetFamily) private var family
  let content: Content

  init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  var body: some View {
    if isAccessoryFamily {
      content
    } else if #available(iOSApplicationExtension 17.0, *) {
      content.containerBackground(.fill.tertiary, for: .widget)
    } else {
      content
        .padding()
        .background(Color(.systemBackground))
    }
  }

  private var isAccessoryFamily: Bool {
    if #available(iOSApplicationExtension 16.0, *) {
      return family == .accessoryCircular || family == .accessoryRectangular
    }
    return false
  }
}

private struct QuickCaptureView: View {
  @Environment(\.widgetFamily) private var family
  let entry: ArchiveEntry

  var body: some View {
    let lockScreenEnabled = WidgetPayload.boolean("lockScreenEnabled", in: entry.payload)
    WidgetSurface {
      if isAccessoryFamily && !lockScreenEnabled {
        Label("Private", systemImage: "lock.fill")
          .font(.caption)
      } else if #available(iOSApplicationExtension 16.0, *), family == .accessoryCircular {
        VStack(spacing: 2) {
          Image(systemName: "waveform")
          Text("New")
            .font(.caption2)
        }
        .widgetURL(WidgetPayload.deepLink(route: "/record", source: "quick-capture-widget"))
      } else {
        VStack(alignment: .leading, spacing: 8) {
          Image(systemName: "waveform.circle.fill")
            .font(.title)
            .foregroundStyle(.tint)
          Spacer(minLength: 0)
          Text("Quick capture")
            .font(.headline)
          Text("Record a thought")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .widgetURL(WidgetPayload.deepLink(route: "/record", source: "quick-capture-widget"))
      }
    }
    .tint(WidgetPayload.accentColor(in: entry.payload))
  }

  private var isAccessoryFamily: Bool {
    if #available(iOSApplicationExtension 16.0, *) {
      return family == .accessoryCircular || family == .accessoryRectangular
    }
    return false
  }
}

private struct HabitStreakView: View {
  @Environment(\.widgetFamily) private var family
  let entry: ArchiveEntry

  var body: some View {
    let habit = WidgetPayload.dictionary("habitStreak", in: entry.payload)
    let title = WidgetPayload.string("title", in: habit, fallback: "Habit streak")
    let streak = WidgetPayload.integer("currentStreak", in: habit)
    let stepId = WidgetPayload.string("stepId", in: habit, fallback: "")
    let route = WidgetPayload.string("route", in: habit, fallback: "/life-os")
    let lockScreenEnabled = WidgetPayload.boolean("lockScreenEnabled", in: entry.payload)
    WidgetSurface {
      if isAccessoryFamily && !lockScreenEnabled {
        Label("Private", systemImage: "lock.fill")
          .font(.caption)
      } else if #available(iOSApplicationExtension 17.0, *), !stepId.isEmpty {
        Button(intent: CompleteHabitIntent(stepId: stepId)) {
          habitContent(title: title, streak: streak)
        }
        .buttonStyle(.plain)
      } else {
        habitContent(title: title, streak: streak)
          .widgetURL(WidgetPayload.deepLink(route: route, source: "habit-streak-widget"))
      }
    }
    .tint(WidgetPayload.accentColor(in: entry.payload))
  }

  private var isAccessoryFamily: Bool {
    if #available(iOSApplicationExtension 16.0, *) {
      return family == .accessoryCircular || family == .accessoryRectangular
    }
    return false
  }

  @ViewBuilder
  private func habitContent(title: String, streak: Int) -> some View {
    if #available(iOSApplicationExtension 16.0, *), family == .accessoryCircular {
      VStack(spacing: 0) {
        Image(systemName: "flame.fill")
        Text("\(streak)")
          .font(.headline)
      }
    } else if #available(iOSApplicationExtension 16.0, *), family == .accessoryRectangular {
      HStack {
        Image(systemName: "flame.fill")
        VStack(alignment: .leading, spacing: 1) {
          Text(title).font(.headline).lineLimit(1)
          Text("\(streak)-day streak").font(.caption).lineLimit(1)
        }
      }
    } else {
      VStack(alignment: .leading, spacing: 6) {
        Label("Habit streak", systemImage: "flame.fill")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
        Spacer(minLength: 0)
        Text("\(streak)")
          .font(.system(size: 36, weight: .bold, design: .rounded))
        Text(streak == 1 ? "day · \(title)" : "days · \(title)")
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
  }
}

private struct ClusterPulseView: View {
  @Environment(\.widgetFamily) private var family
  let entry: ArchiveEntry

  var body: some View {
    let cluster = WidgetPayload.dictionary("clusterPulse", in: entry.payload)
    let title = WidgetPayload.string("title", in: cluster, fallback: "Cluster pulse")
    let summary = WidgetPayload.string(
      "summary",
      in: cluster,
      fallback: "Open ArchiveMe to refresh your private patterns."
    )
    let direction = WidgetPayload.string("direction", in: cluster, fallback: "steady")
    let route = WidgetPayload.string("route", in: cluster, fallback: "/life-os")
    let lockScreenEnabled = WidgetPayload.boolean("lockScreenEnabled", in: entry.payload)
    WidgetSurface {
      if isAccessoryFamily && !lockScreenEnabled {
        Label("Private", systemImage: "lock.fill")
          .font(.caption)
      } else if #available(iOSApplicationExtension 16.0, *), family == .accessoryRectangular {
        HStack {
          Image(systemName: "point.3.connected.trianglepath.dotted")
          VStack(alignment: .leading, spacing: 1) {
            Text(title).font(.headline).lineLimit(1)
            Text(summary).font(.caption).lineLimit(1)
          }
        }
        .widgetURL(WidgetPayload.deepLink(route: route, source: "cluster-pulse-widget"))
      } else {
        VStack(alignment: .leading, spacing: 8) {
          HStack {
            Label("Cluster pulse", systemImage: "point.3.connected.trianglepath.dotted")
              .font(.caption.weight(.semibold))
            Spacer()
            Text(direction.capitalized)
              .font(.caption2.weight(.medium))
              .foregroundStyle(.secondary)
          }
          Text(title)
            .font(.headline)
            .lineLimit(1)
          Text(summary)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(3)
          Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .widgetURL(WidgetPayload.deepLink(route: route, source: "cluster-pulse-widget"))
      }
    }
    .tint(WidgetPayload.accentColor(in: entry.payload))
  }

  private var isAccessoryFamily: Bool {
    if #available(iOSApplicationExtension 16.0, *) {
      return family == .accessoryCircular || family == .accessoryRectangular
    }
    return false
  }
}

private struct QuickCaptureWidget: Widget {
  let kind = "ArchiveMeQuickCapture"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: ArchiveProvider()) { entry in
      QuickCaptureView(entry: entry)
    }
    .configurationDisplayName("Quick capture")
    .description("Jump directly into a private voice capture.")
    .supportedFamilies(quickCaptureFamilies)
  }

  private var quickCaptureFamilies: [WidgetFamily] {
    if #available(iOSApplicationExtension 16.0, *) {
      return [.systemSmall, .accessoryCircular, .accessoryRectangular]
    }
    return [.systemSmall]
  }
}

private struct HabitStreakWidget: Widget {
  let kind = "ArchiveMeHabitStreak"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: ArchiveProvider()) { entry in
      HabitStreakView(entry: entry)
    }
    .configurationDisplayName("Habit streak")
    .description("See your current habit streak without exposing its data at rest.")
    .supportedFamilies(habitFamilies)
  }

  private var habitFamilies: [WidgetFamily] {
    if #available(iOSApplicationExtension 16.0, *) {
      return [.systemSmall, .accessoryCircular, .accessoryRectangular]
    }
    return [.systemSmall]
  }
}

private struct ClusterPulseWidget: Widget {
  let kind = "ArchiveMeClusterPulse"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: ArchiveProvider()) { entry in
      ClusterPulseView(entry: entry)
    }
    .configurationDisplayName("Cluster pulse")
    .description("Keep a private pattern summary close by.")
    .supportedFamilies(clusterFamilies)
  }

  private var clusterFamilies: [WidgetFamily] {
    if #available(iOSApplicationExtension 16.0, *) {
      return [.systemMedium, .accessoryRectangular]
    }
    return [.systemMedium]
  }
}

@main
struct ArchiveMeWidgetBundle: WidgetBundle {
  var body: some Widget {
    QuickCaptureWidget()
    HabitStreakWidget()
    ClusterPulseWidget()
  }
}
