import SwiftUI

struct QuickRecordView: View {
  @ObservedObject private var connectivity = WatchConnectivityManager.shared

  var body: some View {
    VStack(spacing: 14) {
      Text("Quick record")
        .font(.headline)
        .foregroundStyle(.white)

      Button(action: connectivity.toggleRecording) {
        ZStack {
          Circle()
            .fill(connectivity.isRecording ? Color.red : Color(red: 0.45, green: 0.22, blue: 0.92))
            .frame(width: 92, height: 92)
          Image(systemName: connectivity.isRecording ? "stop.fill" : "mic.fill")
            .font(.title)
            .foregroundStyle(.white)
        }
      }
      .buttonStyle(.plain)
      .accessibilityLabel(connectivity.isRecording ? "Stop recording" : "Start recording")

      Text(connectivity.isRecording ? "Tap to stop and send" : "Tap to record")
        .font(.caption)
        .multilineTextAlignment(.center)
        .foregroundStyle(.white.opacity(0.85))

      if let message = connectivity.lastSyncMessage {
        Text(message)
          .font(.caption2)
          .multilineTextAlignment(.center)
          .foregroundStyle(.white.opacity(0.7))
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.black)
    .onAppear {
      connectivity.activateSession()
    }
  }
}

#Preview {
  QuickRecordView()
}
