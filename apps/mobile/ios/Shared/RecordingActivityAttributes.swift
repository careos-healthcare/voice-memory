import ActivityKit
import Foundation

struct RecordingActivityAttributes: ActivityAttributes {
  public struct ContentState: Codable, Hashable {
    var startedAt: Date
  }

  var title: String
}
