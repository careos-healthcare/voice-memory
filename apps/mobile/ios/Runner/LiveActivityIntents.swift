import ActivityKit
import AppIntents
import Foundation

/// Pause or resume the recording that owns the Live Activity.
@available(iOS 17.0, *)
struct PauseRecordingIntent: LiveActivityIntent {
  static var title: LocalizedStringResource = "Pause Recording"
  static var description = IntentDescription("Pause or resume the recording.")

  func perform() async throws -> some IntentResult {
    LiveAudioLifecycleBridge.shared.togglePauseFromIsland()
    return .result()
  }
}

/// Stops capture and brings ArchiveMe forward.
@available(iOS 17.0, *)
struct StopRecordingIntent: LiveActivityIntent {
  static var title: LocalizedStringResource = "Stop Recording"
  static var description = IntentDescription("Stop the recording.")
  static var openAppWhenRun = true

  func perform() async throws -> some IntentResult {
    LiveAudioLifecycleBridge.shared.stopFromIsland()
    return .result()
  }
}
