import AVFoundation
import Flutter

/// Primes the shared record session as soon as Flutter reports the app is active.
enum ZeroStateRecorderChannel {
  static let name = "com.archiveme/zero_state_recorder"

  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: name, binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "primeMicrophone":
        ShortcutAudioBuffer.activateSession()
        result(true)
      case ShortcutAudioBuffer.consumeMethod:
        result(ShortcutAudioBuffer.consumeLaunch())
      case ShortcutAudioBuffer.beginMethod:
        ShortcutAudioBuffer.begin()
        result(true)
      case ShortcutAudioBuffer.releaseMethod:
        result(ShortcutAudioBuffer.release())
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}

/// Keeps a microphone file open for a shortcut or lock-screen launch.
enum ShortcutAudioBuffer {
  static let consumeMethod = "consumeRecordLaunch"
  static let beginMethod = "beginAudioBuffer"
  static let releaseMethod = "releaseAudioBuffer"

  private static var recorder: AVAudioRecorder?
  private static var pendingLaunch = false
  private static var outputURL: URL?

  static func noteLaunch() {
    pendingLaunch = true
  }

  static func consumeLaunch() -> Bool {
    let pending = pendingLaunch
    pendingLaunch = false
    return pending
  }

  static func activateSession() {
    let session = AVAudioSession.sharedInstance()
    try? session.setCategory(
      .playAndRecord,
      mode: .default,
      options: [.defaultToSpeaker]
    )
    try? session.setActive(true)
  }

  static func begin() {
    if recorder != nil { return }
    activateSession()
    let session = AVAudioSession.sharedInstance()
    guard session.recordPermission == .granted else { return }
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("shortcut-buffer-\(UUID().uuidString).m4a")
    let settings: [String: Any] = [
      AVFormatIDKey: kAudioFormatMPEG4AAC,
      AVSampleRateKey: 44_100,
      AVNumberOfChannelsKey: 1,
    ]
    guard let audio = try? AVAudioRecorder(url: url, settings: settings) else { return }
    audio.record()
    recorder = audio
    outputURL = url
  }

  static func release() -> String? {
    recorder?.stop()
    recorder = nil
    let path = outputURL?.path
    outputURL = nil
    return path
  }
}
