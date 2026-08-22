import Foundation
import WatchConnectivity

/// Host-side WCSession bridge — receives watch audio files and exposes them to Flutter.
final class WatchSessionBridge: NSObject {
  static let shared = WatchSessionBridge()

  private var pendingCaptures: [[String: Any]] = []
  private var onCaptureReceived: (([String: Any]) -> Void)?

  private override init() {
    super.init()
  }

  func activate() {
    guard WCSession.isSupported() else { return }
    let session = WCSession.default
    session.delegate = self
    session.activate()
  }

  func setOnCaptureReceived(_ handler: @escaping ([String: Any]) -> Void) {
    onCaptureReceived = handler
    let queued = pendingCaptures
    pendingCaptures.removeAll()
    for payload in queued {
      handler(payload)
    }
  }

  func consumePendingWatchAudio() -> [[String: Any]] {
    let captures = pendingCaptures
    pendingCaptures.removeAll()
    return captures
  }

  private func handleIncomingFile(_ file: WCSessionFile) {
    let metadataType = file.metadata?["type"] as? String ?? ""
    guard metadataType == "watch_audio_capture" else { return }

    let inbox = FileManager.default.temporaryDirectory
      .appendingPathComponent("watch_inbox", isDirectory: true)
    try? FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)

    let destination = inbox.appendingPathComponent(file.fileURL.lastPathComponent)
    try? FileManager.default.removeItem(at: destination)
    do {
      try FileManager.default.copyItem(at: file.fileURL, to: destination)
      let payload = buildPayload(
        path: destination.path,
        metadata: file.metadata ?? [:]
      )
      if let onCaptureReceived {
        onCaptureReceived(payload)
      } else {
        pendingCaptures.append(payload)
      }
    } catch {
      // Best-effort inbox copy; Flutter can retry on next launch.
    }
  }

  private func buildPayload(path: String, metadata: [String: Any]) -> [String: Any] {
    var payload: [String: Any] = [
      "path": path,
      "type": metadata["type"] as? String ?? "watch_audio_capture",
    ]
    if let capturedAt = metadata["capturedAt"] as? String {
      payload["capturedAt"] = capturedAt
    }
    if let duration = metadata["durationSeconds"] as? Int {
      payload["durationSeconds"] = duration
    } else if let duration = metadata["durationSeconds"] as? NSNumber {
      payload["durationSeconds"] = duration.intValue
    }
    return payload
  }
}

extension WatchSessionBridge: WCSessionDelegate {
  func session(
    _ session: WCSession,
    activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {}

  func sessionDidBecomeInactive(_ session: WCSession) {}

  func sessionDidDeactivate(_ session: WCSession) {
    session.activate()
  }

  func session(_ session: WCSession, didReceive file: WCSessionFile) {
    handleIncomingFile(file)
  }
}
