import ActivityKit
import Foundation

/// Shows elapsed recording time and a Stop link while capture is running.
enum RecordingLiveActivityController {
  @available(iOS 16.1, *)
  private static var current: Activity<RecordingActivityAttributes>?

  static func start() {
    guard #available(iOS 16.1, *) else { return }
    guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
    let attributes = RecordingActivityAttributes(title: "Recording")
    let state = RecordingActivityAttributes.ContentState(startedAt: Date())
    do {
      current = try Activity.request(
        attributes: attributes,
        content: .init(state: state, staleDate: nil),
        pushType: nil
      )
    } catch {
      current = nil
    }
  }

  static func stop() {
    guard #available(iOS 16.1, *) else { return }
    let activity = current
    current = nil
    Task {
      await activity?.end(nil, dismissalPolicy: .immediate)
    }
  }
}
