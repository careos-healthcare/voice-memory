import AVFoundation
import Foundation
import WatchConnectivity

// DELIBERATE SCAFFOLDING — not V1-shipped (see docs/WATCHOS_SETUP.md).
// Watch records locally; iPhone Runner receives files via WatchSessionBridge
// → Flutter WatchConnectivityService on `archive_me/watch_session`.
// Resume: add ArchiveMeWatch Xcode target, then enable
// VOICEMEMORY_ENABLE_WATCH_COMPANION on the Flutter side.

/// Sends watch-recorded audio back to the paired iPhone host app via WCSession.
final class WatchConnectivityManager: NSObject, ObservableObject {
  static let shared = WatchConnectivityManager()

  @Published private(set) var isRecording = false
  @Published private(set) var lastSyncMessage: String?

  private var recorder: AVAudioRecorder?
  private var recordingURL: URL?
  private var recordingStartedAt: Date?

  private override init() {
    super.init()
    activateSession()
  }

  func activateSession() {
    guard WCSession.isSupported() else { return }
    let session = WCSession.default
    session.delegate = self
    session.activate()
  }

  func toggleRecording() {
    isRecording ? stopRecording() : startRecording()
  }

  func startRecording() {
    guard !isRecording else { return }
    let session = AVAudioSession.sharedInstance()
    do {
      try session.setCategory(.playAndRecord, mode: .default, options: [.duckOthers])
      try session.setActive(true)

      let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("watch_capture_\(Int(Date().timeIntervalSince1970)).m4a")
      let settings: [String: Any] = [
        AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
        AVSampleRateKey: 44_100,
        AVNumberOfChannelsKey: 1,
        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
      ]
      recorder = try AVAudioRecorder(url: url, settings: settings)
      recorder?.record()
      recordingURL = url
      recordingStartedAt = Date()
      isRecording = true
      lastSyncMessage = "Recording…"
    } catch {
      lastSyncMessage = "Could not start recording."
    }
  }

  func stopRecording() {
    guard isRecording else { return }
    recorder?.stop()
    recorder = nil
    isRecording = false
    recordingStartedAt = nil

    guard let url = recordingURL else {
      lastSyncMessage = "Nothing to send."
      return
    }

    sendRecording(at: url, durationSeconds: resolvedDurationSeconds())
  }

  private func resolvedDurationSeconds() -> Int {
    guard let started = recordingStartedAt else { return 1 }
    return max(1, Int(Date().timeIntervalSince(started)))
  }

  private func sendRecording(at url: URL, durationSeconds: Int) {
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

extension WatchConnectivityManager: WCSessionDelegate {
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
