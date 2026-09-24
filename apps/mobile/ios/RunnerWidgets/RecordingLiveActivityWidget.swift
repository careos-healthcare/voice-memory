import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// Lock Screen and Dynamic Island presentation for an active recording.
///
/// Live Activity layouts are shown only from a Widget Extension target.
/// Add this file, `RecordingActivityAttributes.swift`, and
/// `LiveActivityIntents.swift` to that extension, then register the widget:
///
/// ```swift
/// import WidgetKit
/// import SwiftUI
///
/// @main
/// struct ArchiveMeWidgets: WidgetBundle {
///   var body: some Widget {
///     if #available(iOS 16.1, *) {
///       RecordingLiveActivityWidget()
///     }
///   }
/// }
/// ```
@available(iOS 16.1, *)
struct RecordingLiveActivityWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: RecordingActivityAttributes.self) { context in
      RecordingLockScreenView(context: context)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          RecordingActivityHeader(context: context, showsTimer: false)
        }
        DynamicIslandExpandedRegion(.trailing) {
          Text(context.attributes.startDate, style: .timer)
            .font(.headline.monospacedDigit())
            .foregroundStyle(.primary)
        }
        DynamicIslandExpandedRegion(.center) {
          RecordingWaveformBars(levels: context.state.decibelLevels)
        }
        DynamicIslandExpandedRegion(.bottom) {
          RecordingActivityControls(isPaused: context.state.isPaused)
        }
      } compactLeading: {
        Image(systemName: "mic.fill")
          .foregroundStyle(context.state.isPaused ? Color.recordingAmber : Color.red)
      } compactTrailing: {
        Text(context.attributes.startDate, style: .timer)
          .font(.caption.monospacedDigit())
          .foregroundStyle(.primary)
          .frame(maxWidth: 56)
      } minimal: {
        PulsingMicIcon(isPaused: context.state.isPaused)
      }
    }
  }
}

@available(iOS 16.1, *)
private struct RecordingLockScreenView: View {
  let context: ActivityViewContext<RecordingActivityAttributes>

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 10) {
        PulsingRecordDot(isPaused: context.state.isPaused)
        RecordingActivityHeader(context: context, showsTimer: true)
        Spacer(minLength: 8)
        RecordingWaveformBars(levels: context.state.decibelLevels)
      }
      RecordingActivityControls(isPaused: context.state.isPaused)
    }
    .padding(.horizontal, 4)
  }
}

@available(iOS 16.1, *)
private struct RecordingActivityHeader: View {
  let context: ActivityViewContext<RecordingActivityAttributes>
  let showsTimer: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(context.state.isPaused ? "Paused" : "Recording")
        .font(.headline)
      if showsTimer {
        Text(context.attributes.startDate, style: .timer)
          .font(.title3.monospacedDigit())
          .foregroundStyle(.secondary)
      }
    }
  }
}

@available(iOS 16.1, *)
private struct RecordingActivityControls: View {
  let isPaused: Bool

  var body: some View {
    if #available(iOS 17.0, *) {
      HStack(spacing: 12) {
        Button(intent: PauseRecordingIntent()) {
          Label(
            isPaused ? "Resume" : "Pause",
            systemImage: isPaused ? "play.fill" : "pause.fill"
          )
        }
        .buttonStyle(.bordered)
        Button(intent: StopRecordingIntent()) {
          Label("Stop", systemImage: "stop.fill")
        }
        .buttonStyle(.borderedProminent)
        .tint(.red)
      }
    }
  }
}

@available(iOS 16.1, *)
private struct RecordingWaveformBars: View {
  let levels: [Float]

  var body: some View {
    HStack(alignment: .center, spacing: 3) {
      ForEach(0..<8, id: \.self) { index in
        let level = index < levels.count ? levels[index] : 0
        RoundedRectangle(cornerRadius: 1.5)
          .fill(Color.red.opacity(0.9))
          .frame(width: 4, height: max(4, CGFloat(min(max(level, 0), 1)) * 28))
      }
    }
    .frame(height: 28)
  }
}

@available(iOS 16.1, *)
private struct PulsingRecordDot: View {
  let isPaused: Bool

  var body: some View {
    TimelineView(.periodic(from: .now, by: 0.8)) { timeline in
      let dimmed = timeline.date.timeIntervalSinceReferenceDate
        .truncatingRemainder(dividingBy: 1.6) >= 0.8
      Circle()
        .fill(isPaused ? Color.recordingAmber : Color.red)
        .frame(width: 10, height: 10)
        .opacity(dimmed ? 0.35 : 1)
    }
  }
}

private extension Color {
  static let recordingAmber = Color(red: 1, green: 0.62, blue: 0.04)
}

@available(iOS 16.1, *)
private struct PulsingMicIcon: View {
  let isPaused: Bool

  var body: some View {
    TimelineView(.periodic(from: .now, by: 0.8)) { timeline in
      let dimmed = timeline.date.timeIntervalSinceReferenceDate
        .truncatingRemainder(dividingBy: 1.6) >= 0.8
      Image(systemName: "mic.fill")
        .foregroundStyle(isPaused ? Color.recordingAmber : Color.red)
        .opacity(isPaused || !dimmed ? 1 : 0.4)
    }
  }
}
