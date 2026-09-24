import AppIntents
import Foundation
import WidgetKit

private enum NativeCaptureRoute {
  static let record = "/record?autostart=1"
  static let text = "/record?autostart=1&input=text"

  static func remember(_ route: String) {
    UserDefaults(suiteName: QuickCaptureWidgetStorage.appGroupId)?
      .set(route, forKey: QuickCaptureWidgetStorage.pendingRouteKey)
  }
}

struct StartRecordingIntent: AppIntent {
  static var title: LocalizedStringResource = "Start recording"
  static var description = IntentDescription("Open Thoughtprint and start a recording.")
  static var openAppWhenRun = true

  func perform() async throws -> some IntentResult {
    NativeCaptureRoute.remember(NativeCaptureRoute.record)
    return .result()
  }
}

struct QuickTextEntryIntent: AppIntent {
  static var title: LocalizedStringResource = "Quick text entry"
  static var description = IntentDescription("Open Thoughtprint ready to type an entry.")
  static var openAppWhenRun = true

  func perform() async throws -> some IntentResult {
    NativeCaptureRoute.remember(NativeCaptureRoute.text)
    return .result()
  }
}

#if !WIDGET_EXTENSION
struct ThoughtprintShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: StartRecordingIntent(),
      phrases: ["Start recording in \(.applicationName)", "Record in \(.applicationName)"],
      shortTitle: "Record",
      systemImageName: "mic"
    )
    AppShortcut(
      intent: QuickTextEntryIntent(),
      phrases: ["Type an entry in \(.applicationName)"],
      shortTitle: "Text entry",
      systemImageName: "keyboard"
    )
  }
}
#endif

#if WIDGET_EXTENSION
@available(iOS 18.0, *)
struct StartRecordingControl: ControlWidget {
  var body: some ControlWidgetConfiguration {
    StaticControlConfiguration(kind: "com.voicememory.mobile.startRecording") {
      ControlWidgetButton(action: StartRecordingIntent()) {
        Label("Record", systemImage: "mic.fill")
      }
    }
    .displayName("Record")
    .description("Start a Thoughtprint recording.")
  }
}
#endif
