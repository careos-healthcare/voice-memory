import AVFoundation
import Foundation
import WatchKit

/// Records watch audio and keeps the process alive with an extended runtime session.
final class AudioRecorder: NSObject, ObservableObject {
  @Published private(set) var isRecording = false
  @Published private(set) var startedAt: Date?
  @Published private(set) var statusMessage: String?

  private var recorder: AVAudioRecorder?
  private var recordingURL: URL?
  private var runtimeSession: WKExtendedRuntimeSession?

  func start() {
    guard !isRecording else { return }
    let session = AVAudioSession.sharedInstance()
    do {
      try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [])
      try session.setActive(true)
    } catch {
      statusMessage = "Microphone is unavailable."
      return
    }

    let runtime = WKExtendedRuntimeSession()
    runtime.delegate = self
    runtimeSession = runtime
    runtime.start()

    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("watch_capture_\(Int(Date().timeIntervalSince1970)).m4a")
    let settings: [String: Any] = [
      AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
      AVSampleRateKey: 44_100,
      AVNumberOfChannelsKey: 1,
      AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
    ]
    do {
      let audioRecorder = try AVAudioRecorder(url: url, settings: settings)
      audioRecorder.record()
      recorder = audioRecorder
      recordingURL = url
      startedAt = Date()
      isRecording = true
      statusMessage = "Recording…"
    } catch {
      runtime.invalidate()
      runtimeSession = nil
      statusMessage = "Could not start recording."
    }
  }

  @discardableResult
  func stop() -> URL? {
    guard isRecording else { return nil }
    let duration = durationSeconds()
    recorder?.stop()
    recorder = nil
    isRecording = false
    let url = recordingURL
    recordingURL = nil
    startedAt = nil
    runtimeSession?.invalidate()
    runtimeSession = nil
    guard let url else {
      statusMessage = "Nothing to send."
      return nil
    }
    WatchSessionManager.shared.transferRecording(
      at: url,
      durationSeconds: duration
    )
    return url
  }

  private func durationSeconds() -> Int {
    guard let startedAt else { return 1 }
    return max(1, Int(Date().timeIntervalSince(startedAt)))
  }
}

extension AudioRecorder: WKExtendedRuntimeSessionDelegate {
  func extendedRuntimeSessionDidStart(
    _ extendedRuntimeSession: WKExtendedRuntimeSession
  ) {}

  func extendedRuntimeSessionWillExpire(
    _ extendedRuntimeSession: WKExtendedRuntimeSession
  ) {
    _ = stop()
  }

  func extendedRuntimeSession(
    _ extendedRuntimeSession: WKExtendedRuntimeSession,
    didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
    error: Error?
  ) {
    if isRecording {
      _ = stop()
    }
  }
}
