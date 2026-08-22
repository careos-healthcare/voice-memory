import SwiftUI
import WidgetKit

struct QuickCaptureComplicationEntry: TimelineEntry {
  let date: Date
}

struct QuickCaptureComplicationProvider: TimelineProvider {
  func placeholder(in context: Context) -> QuickCaptureComplicationEntry {
    QuickCaptureComplicationEntry(date: Date())
  }

  func getSnapshot(in context: Context, completion: @escaping (QuickCaptureComplicationEntry) -> Void) {
    completion(QuickCaptureComplicationEntry(date: Date()))
  }

  func getTimeline(
    in context: Context,
    completion: @escaping (Timeline<QuickCaptureComplicationEntry>) -> Void
  ) {
    let entry = QuickCaptureComplicationEntry(date: Date())
    let refresh = Calendar.current.date(byAdding: .hour, value: 4, to: Date())
      ?? Date().addingTimeInterval(4 * 3600)
    completion(Timeline(entries: [entry], policy: .after(refresh)))
  }
}

struct ArchiveMeComplicationView: View {
  var body: some View {
    ZStack {
      AccessoryWidgetBackground()
      Image(systemName: "mic.fill")
        .font(.title3.weight(.bold))
        .foregroundStyle(.white)
    }
  }
}

struct ArchiveMeComplication: Widget {
  let kind = "ArchiveMeComplication"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: QuickCaptureComplicationProvider()) { _ in
      ArchiveMeComplicationView()
    }
    .configurationDisplayName("Quick record")
    .description("One tap to open ArchiveMe quick record on Apple Watch.")
    .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
  }
}
