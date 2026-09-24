import ActivityKit
import Foundation

/// Fixed fields for one recording Live Activity.
///
/// `recordingId` and `startDate` stay constant for the life of the activity.
/// `ContentState` is what Dynamic Island and the Lock Screen refresh.
struct RecordingActivityAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    var isPaused: Bool
    /// Eight levels in the range 0.0...1.0 for the mini waveform.
    var decibelLevels: [Float]
  }

  var recordingId: String
  var startDate: Date
}
