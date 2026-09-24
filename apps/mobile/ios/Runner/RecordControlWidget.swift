import AppIntents
import SwiftUI
import WidgetKit

/// iOS 18 Control Center button that opens ArchiveMe straight into recording.
///
/// Register this control in the widget extension bundle. Control Center only
/// offers controls that live in an extension target:
///
/// ```swift
/// import WidgetKit
/// import SwiftUI
///
/// @main
/// struct ArchiveMeWidgets: WidgetBundle {
///   var body: some Widget {
///     RecordControlWidget()
///   }
/// }
/// ```
///
/// Add this file to that extension target and keep the deployment target at
/// iOS 18 or wrap the bundle in `if #available(iOS 18, *)`.
@available(iOS 18.0, *)
struct StartRecordingIntent: AppIntent {
  static var title: LocalizedStringResource = "Record"
  static var openAppWhenRun = true

  func perform() async throws -> some IntentResult & OpensIntent {
    let target = URL(string: "archiveme://action/record")!
    return .result(opensIntent: OpenURLIntent(target))
  }
}

@available(iOS 18.0, *)
struct RecordControlWidget: ControlWidget {
  static let kind = "com.voicememory.mobile.record"

  var body: some ControlWidgetConfiguration {
    StaticControlConfiguration(kind: Self.kind) {
      ControlWidgetButton(action: StartRecordingIntent()) {
        Label("Record", systemImage: "mic.fill")
      }
    }
  }
}
