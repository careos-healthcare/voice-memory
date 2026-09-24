import ActivityKit
import SwiftUI
import WidgetKit

@available(iOS 16.1, *)
struct RecordingLiveActivityWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: RecordingActivityAttributes.self) { context in
      HStack {
        Image(systemName: "mic.fill")
        Text(context.attributes.title)
        Text(context.state.startedAt, style: .timer)
        Link(destination: URL(string: "voicememory://record?stop=1")!) {
          Text("Stop")
        }
      }
      .padding()
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Image(systemName: "mic.fill")
        }
        DynamicIslandExpandedRegion(.center) {
          Text(context.state.startedAt, style: .timer)
        }
        DynamicIslandExpandedRegion(.trailing) {
          Link(destination: URL(string: "voicememory://record?stop=1")!) {
            Text("Stop")
          }
        }
      } compactLeading: {
        Image(systemName: "mic.fill")
      } compactTrailing: {
        Text(context.state.startedAt, style: .timer)
      } minimal: {
        Image(systemName: "mic.fill")
      }
    }
  }
}
