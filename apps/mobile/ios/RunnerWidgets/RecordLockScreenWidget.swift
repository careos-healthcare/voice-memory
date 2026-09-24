import SwiftUI
import WidgetKit

/// Lock Screen widget that opens ArchiveMe on the recording screen.
///
/// This file is the widget-extension source. It does not appear on the Lock
/// Screen until it is a member of a Widget Extension target:
///
/// 1. In Xcode, File → New → Target → Widget Extension. Name it
///    `ArchiveMeWidgets`. Skip "Include Configuration App Intent".
/// 2. Set the extension's deployment target to iOS 16 or newer. Accessory
///    families are the Lock Screen sizes.
/// 3. Add this file to the `ArchiveMeWidgets` target, and remove it from the
///    Runner target if Xcode added it there.
/// 4. Add the App Group `group.com.voicememory.mobile` to both Runner and the
///    extension.
/// 5. Replace the extension's generated `@main` bundle with:
///
/// ```swift
/// @main
/// struct ArchiveMeWidgets: WidgetBundle {
///   var body: some Widget {
///     RecordLockScreenWidget()
///   }
/// }
/// ```
///
/// The URL includes `homeWidget` so `home_widget` reports the tap in Dart.
/// `archiveme://record` is the same recording route as a voice shortcut.
@available(iOS 16.0, *)
struct RecordLockScreenWidget: Widget {
  static let kind = "com.voicememory.mobile.record_lock_screen"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: Self.kind, provider: RecordLockScreenTimeline()) { _ in
      RecordLockScreenView()
    }
    .configurationDisplayName("Record")
    .description("Open recording.")
    .supportedFamilies([
      .accessoryCircular,
      .accessoryRectangular,
    ])
  }
}

@available(iOS 16.0, *)
private struct RecordLockScreenEntry: TimelineEntry {
  let date: Date
}

@available(iOS 16.0, *)
private struct RecordLockScreenTimeline: TimelineProvider {
  func placeholder(in context: Context) -> RecordLockScreenEntry {
    RecordLockScreenEntry(date: Date())
  }

  func getSnapshot(
    in context: Context,
    completion: @escaping (RecordLockScreenEntry) -> Void
  ) {
    completion(RecordLockScreenEntry(date: Date()))
  }

  func getTimeline(
    in context: Context,
    completion: @escaping (Timeline<RecordLockScreenEntry>) -> Void
  ) {
    completion(
      Timeline(
        entries: [RecordLockScreenEntry(date: Date())],
        policy: .never
      )
    )
  }
}

@available(iOS 16.0, *)
private struct RecordLockScreenView: View {
  @Environment(\.widgetFamily) private var family

  private let launch = URL(string: "archiveme://record?homeWidget&autostart=1")!

  var body: some View {
    Group {
      if family == .accessoryCircular {
        Image(systemName: "mic.fill")
          .font(.system(size: 20, weight: .semibold))
      } else {
        HStack(spacing: 8) {
          Image(systemName: "mic.fill")
          Text("Record")
            .font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .widgetURL(launch)
  }
}
