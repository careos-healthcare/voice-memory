import SwiftUI

@main
struct ArchiveMeWatchApp: App {
  var body: some Scene {
    WindowGroup {
      WatchRecordingView()
    }
  }
}

/// Central record control with a running elapsed timer.
struct WatchRecordingView: View {
  @StateObject private var recorder = AudioRecorder()
  @ObservedObject private var session = WatchSessionManager.shared

  var body: some View {
    VStack(spacing: 12) {
      if recorder.isRecording, let startedAt = recorder.startedAt {
        Text(startedAt, style: .timer)
          .font(.title2.monospacedDigit())
          .foregroundStyle(.white)
      } else {
        Text("0:00")
          .font(.title2.monospacedDigit())
          .foregroundStyle(.white.opacity(0.7))
      }

      Button(action: toggleRecording) {
        ZStack {
          Circle()
            .fill(recorder.isRecording ? Color.red : Color(red: 0.45, green: 0.22, blue: 0.92))
            .frame(width: 92, height: 92)
          Image(systemName: recorder.isRecording ? "stop.fill" : "mic.fill")
            .font(.title)
            .foregroundStyle(.white)
        }
      }
      .buttonStyle(.plain)
      .accessibilityLabel(recorder.isRecording ? "Stop recording" : "Start recording")

      if let message = session.lastSyncMessage ?? recorder.statusMessage {
        Text(message)
          .font(.caption2)
          .multilineTextAlignment(.center)
          .foregroundStyle(.white.opacity(0.75))
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.black)
    .onAppear {
      session.activate()
    }
  }

  private func toggleRecording() {
    if recorder.isRecording {
      recorder.stop()
      return
    }
    recorder.start()
  }
}
