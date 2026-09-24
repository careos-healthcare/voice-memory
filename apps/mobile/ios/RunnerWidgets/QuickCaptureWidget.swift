import AppIntents
import SwiftUI
import WidgetKit

/// Home-screen mic that opens ArchiveMe directly into recording.
///
/// `StartRecordingIntent.openAppWhenRun` is true, so the button launches the
/// Flutter engine on `archiveme://action/record`. Register this widget in the
/// extension bundle next to the Live Activity:
///
/// ```swift
/// @main
/// struct ArchiveMeWidgets: WidgetBundle {
///   var body: some Widget {
///     if #available(iOS 17.0, *) {
///       QuickCaptureWidget()
///     }
///   }
/// }
/// ```
@available(iOS 17.0, *)
struct QuickCaptureWidget: Widget {
  static let kind = "com.voicememory.mobile.quick_capture"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: Self.kind, provider: QuickCaptureTimeline()) { _ in
      QuickCaptureWidgetView()
    }
    .configurationDisplayName("Record")
    .description("Start a recording.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

@available(iOS 17.0, *)
private struct QuickCaptureEntry: TimelineEntry {
  let date: Date
}

@available(iOS 17.0, *)
private struct QuickCaptureTimeline: TimelineProvider {
  func placeholder(in context: Context) -> QuickCaptureEntry {
    QuickCaptureEntry(date: Date())
  }

  func getSnapshot(
    in context: Context,
    completion: @escaping (QuickCaptureEntry) -> Void
  ) {
    completion(QuickCaptureEntry(date: Date()))
  }

  func getTimeline(
    in context: Context,
    completion: @escaping (Timeline<QuickCaptureEntry>) -> Void
  ) {
    let timeline = Timeline(
      entries: [QuickCaptureEntry(date: Date())],
      policy: .never
    )
    completion(timeline)
  }
}

@available(iOS 17.0, *)
private struct QuickCaptureWidgetView: View {
  var body: some View {
    if #available(iOS 18.0, *) {
      Button(intent: StartRecordingIntent()) {
        Image(systemName: "mic.fill")
          .font(.system(size: 36, weight: .semibold))
          .foregroundStyle(.red)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
      .buttonStyle(.plain)
    } else {
      Image(systemName: "mic.fill")
        .font(.system(size: 36, weight: .semibold))
        .foregroundStyle(.red)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }
}
