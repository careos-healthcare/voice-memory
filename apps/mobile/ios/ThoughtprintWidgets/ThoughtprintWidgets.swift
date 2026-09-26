import SwiftUI
import WidgetKit

private enum QuickCaptureLink {
  static let route = "/record?autostart=1"
  static let url = URL(string: "voicememory://record?autostart=1")!

  static func storePendingRoute() {
    let defaults = UserDefaults(suiteName: "group.com.voicememory.mobile")
    defaults?.set(route, forKey: "quick_capture_widget_pending_route")
  }
}

struct ThoughtprintRecordEntry: TimelineEntry {
  let date: Date
}

struct ThoughtprintRecordProvider: TimelineProvider {
  func placeholder(in context: Context) -> ThoughtprintRecordEntry {
    ThoughtprintRecordEntry(date: Date())
  }

  func getSnapshot(in context: Context, completion: @escaping (ThoughtprintRecordEntry) -> Void) {
    completion(ThoughtprintRecordEntry(date: Date()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<ThoughtprintRecordEntry>) -> Void) {
    let entry = ThoughtprintRecordEntry(date: Date())
    completion(Timeline(entries: [entry], policy: .never))
  }
}

struct ThoughtprintRecordWidgetView: View {
  var entry: ThoughtprintRecordEntry

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Thoughtprint")
        .font(.headline)
      Text("Record")
        .font(.title2)
      Text("One tap")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .padding()
    .widgetURL(QuickCaptureLink.url)
  }
}

struct ThoughtprintHomeWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "ThoughtprintRecordHome", provider: ThoughtprintRecordProvider()) { entry in
      ThoughtprintRecordWidgetView(entry: entry)
    }
    .configurationDisplayName("Record")
    .description("Open Thoughtprint and start a recording.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

struct ThoughtprintLockWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "ThoughtprintRecordLock", provider: ThoughtprintRecordProvider()) { entry in
      ThoughtprintRecordWidgetView(entry: entry)
    }
    .configurationDisplayName("Record")
    .description("Start a recording from the Lock Screen.")
    .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
  }
}

@main
struct ThoughtprintWidgetsBundle: WidgetBundle {
  var body: some Widget {
    ThoughtprintHomeWidget()
    ThoughtprintLockWidget()
    if #available(iOS 16.1, *) {
      RecordingLiveActivityWidget()
    }
    if #available(iOS 18, *) {
      StartRecordingControl()
    }
  }
}
