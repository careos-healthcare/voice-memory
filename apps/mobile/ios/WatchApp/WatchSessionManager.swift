import Foundation
import WatchConnectivity

/// Queues a finished watch recording for background delivery to the iPhone.
final class WatchSessionManager: NSObject, ObservableObject {
  static let shared = WatchSessionManager()

  @Published private(set) var lastSyncMessage: String?

  private override init() {
    super.init()
  }

  func activate() {
    guard WCSession.isSupported() else {
      lastSyncMessage = "Watch connection is unavailable."
      return
    }
    let session = WCSession.default
    session.delegate = self
    session.activate()
  }

  func transferRecording(at url: URL, durationSeconds: Int) {
    guard WCSession.default.activationState == .activated else {
      lastSyncMessage = "Phone not reachable."
      return
    }
    let metadata: [String: Any] = [
      "type": "watch_audio_capture",
      "capturedAt": ISO8601DateFormatter().string(from: Date()),
      "filename": url.lastPathComponent,
      "durationSeconds": durationSeconds,
    ]
    WCSession.default.transferFile(url, metadata: metadata)
    lastSyncMessage = "Sent to iPhone."
  }
}

extension WatchSessionManager: WCSessionDelegate {
  func session(
    _ session: WCSession,
    activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {
    DispatchQueue.main.async {
      if let error {
        self.lastSyncMessage = error.localizedDescription
      }
    }
  }

  func sessionReachabilityDidChange(_ session: WCSession) {
    DispatchQueue.main.async {
      self.lastSyncMessage = session.isReachable ? "Phone connected." : "Phone offline."
    }
  }
}
