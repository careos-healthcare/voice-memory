import ActivityKit
import AVFoundation
import Flutter

/// Forwards AVAudioSession interruption and route changes to Flutter live voice,
/// and owns the recording Live Activity.
final class LiveAudioLifecycleBridge: NSObject {
  static let shared = LiveAudioLifecycleBridge()
  static let channelName = "com.archiveme.live/audio_lifecycle"
  static let liveActivityChannelName = "com.archiveme/live_activity"

  private weak var methodChannel: FlutterMethodChannel?
  private var liveActivityChannel: FlutterMethodChannel?
  private var recordingSession: AnyObject?

  func attach(to controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: Self.channelName,
      binaryMessenger: controller.binaryMessenger
    )
    methodChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "startRecordingSequence" else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.activateRecordSession()
      result(nil)
    }
    attachLiveActivityChannel(to: controller)
    setupAudioSessionObservers()
  }

  /// Prepares the shared audio session so a Control Center or Quick Settings
  /// launch can begin capture as soon as Flutter asks.
  func activateRecordSession() {
    let session = AVAudioSession.sharedInstance()
    do {
      try session.setCategory(
        .playAndRecord,
        mode: .default,
        options: [.defaultToSpeaker, .allowBluetooth]
      )
      try session.setActive(true)
    } catch {
      // Capture still proceeds; Flutter logs the session failure.
    }
  }

  /// Dynamic Island pause button. Flutter toggles the recorder and sends the
  /// new pause flag back through `updateLiveActivity`.
  func togglePauseFromIsland() {
    liveActivityChannel?.invokeMethod("togglePause", arguments: nil)
  }

  /// Dynamic Island stop button. Ends the activity immediately, then asks
  /// Flutter to finish capture. The intent also opens the transcript route.
  func stopFromIsland() {
    endLiveActivity()
    liveActivityChannel?.invokeMethod("stopRecording", arguments: nil)
  }

  func startLiveActivity(recordingId: String, startDate: Date) {
    guard #available(iOS 16.2, *) else { return }
    beginRecordingActivity(recordingId: recordingId, startDate: startDate)
  }

  func updateLiveActivity(isPaused: Bool, decibels: [Float]) {
    guard #available(iOS 16.2, *) else { return }
    scheduleRecordingActivityUpdate(isPaused: isPaused, decibels: decibels)
  }

  func endLiveActivity() {
    guard #available(iOS 16.2, *) else { return }
    finishRecordingActivity()
  }

  private func attachLiveActivityChannel(to controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: Self.liveActivityChannelName,
      binaryMessenger: controller.binaryMessenger
    )
    liveActivityChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handleLiveActivityCall(call, result: result)
    }
  }

  private func handleLiveActivityCall(
    _ call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    let args = call.arguments as? [String: Any]
    switch call.method {
    case "startLiveActivity":
      let recordingId = args?["recordingId"] as? String ?? UUID().uuidString
      let startDate = Self.date(from: args?["startDate"]) ?? Date()
      startLiveActivity(recordingId: recordingId, startDate: startDate)
      result(nil)
    case "updateLiveActivity":
      let isPaused = args?["isPaused"] as? Bool ?? false
      let decibels = (args?["decibels"] as? [NSNumber])?.map(\.floatValue) ?? []
      updateLiveActivity(isPaused: isPaused, decibels: decibels)
      result(nil)
    case "endLiveActivity":
      endLiveActivity()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  @available(iOS 16.2, *)
  private final class RecordingActivitySession {
    var activity: Activity<RecordingActivityAttributes>?
    var pendingPaused = false
    var pendingLevels: [Float] = Array(repeating: 0, count: 8)
    var lastFlush = Date.distantPast
    var pendingFlush: DispatchWorkItem?
  }

  @available(iOS 16.2, *)
  private func session() -> RecordingActivitySession {
    if let existing = recordingSession as? RecordingActivitySession {
      return existing
    }
    let created = RecordingActivitySession()
    recordingSession = created
    return created
  }

  @available(iOS 16.2, *)
  private func beginRecordingActivity(recordingId: String, startDate: Date) {
    let current = session()
    current.pendingFlush?.cancel()
    current.pendingFlush = nil
    let previousActivity = current.activity
    current.activity = nil
    if let ending = previousActivity {
      Task {
        await ending.end(nil, dismissalPolicy: .immediate)
      }
    }
    guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

    let attributes = RecordingActivityAttributes(
      recordingId: recordingId,
      startDate: startDate
    )
    let state = RecordingActivityAttributes.ContentState(
      isPaused: false,
      decibelLevels: Array(repeating: 0, count: 8)
    )
    do {
      current.activity = try Activity.request(
        attributes: attributes,
        content: ActivityContent(state: state, staleDate: nil),
        pushType: nil
      )
      current.lastFlush = Date()
      current.pendingPaused = false
      current.pendingLevels = Array(repeating: 0, count: 8)
    } catch {
      // The system can refuse a Live Activity. Capture continues.
    }
  }

  @available(iOS 16.2, *)
  private func scheduleRecordingActivityUpdate(isPaused: Bool, decibels: [Float]) {
    let current = session()
    current.pendingPaused = isPaused
    current.pendingLevels = Self.normalizedLevels(decibels)
    let elapsed = Date().timeIntervalSince(current.lastFlush)
    if elapsed >= 0.5 {
      flushRecordingActivityUpdate()
      return
    }
    guard current.pendingFlush == nil else { return }
    let work = DispatchWorkItem { [weak self] in
      guard #available(iOS 16.2, *) else { return }
      self?.flushRecordingActivityUpdate()
    }
    current.pendingFlush = work
    DispatchQueue.main.asyncAfter(deadline: .now() + (0.5 - elapsed), execute: work)
  }

  @available(iOS 16.2, *)
  private func flushRecordingActivityUpdate() {
    let current = session()
    current.pendingFlush?.cancel()
    current.pendingFlush = nil
    current.lastFlush = Date()
    guard let activity = current.activity else { return }
    let state = RecordingActivityAttributes.ContentState(
      isPaused: current.pendingPaused,
      decibelLevels: current.pendingLevels
    )
    Task {
      await activity.update(ActivityContent(state: state, staleDate: nil))
    }
  }

  @available(iOS 16.2, *)
  private func finishRecordingActivity() {
    let current = session()
    current.pendingFlush?.cancel()
    current.pendingFlush = nil
    let activity = current.activity
    current.activity = nil
    guard let activity else { return }
    Task {
      await activity.end(nil, dismissalPolicy: .immediate)
    }
  }

  private static func date(from raw: Any?) -> Date? {
    if let millis = raw as? NSNumber {
      return Date(timeIntervalSince1970: millis.doubleValue / 1000)
    }
    if let millis = raw as? Double {
      return Date(timeIntervalSince1970: millis / 1000)
    }
    return nil
  }

  private static func normalizedLevels(_ values: [Float]) -> [Float] {
    var levels = [Float](repeating: 0, count: 8)
    for index in 0..<min(8, values.count) {
      let value = values[index]
      if value < 0 {
        levels[index] = 0
      } else if value > 1 {
        levels[index] = 1
      } else {
        levels[index] = value
      }
    }
    return levels
  }

  private func setupAudioSessionObservers() {
    let center = NotificationCenter.default
    let session = AVAudioSession.sharedInstance()

    center.addObserver(
      self,
      selector: #selector(handleAudioInterruption),
      name: AVAudioSession.interruptionNotification,
      object: session
    )
    center.addObserver(
      self,
      selector: #selector(handleAudioRouteChange),
      name: AVAudioSession.routeChangeNotification,
      object: session
    )
  }

  @objc private func handleAudioInterruption(notification: Notification) {
    guard let info = notification.userInfo,
          let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
          let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
      return
    }

    if type == .began {
      methodChannel?.invokeMethod("onAudioInterruptionBegan", arguments: nil)
      return
    }

    guard type == .ended else { return }
    guard let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt else {
      return
    }
    let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
    if options.contains(.shouldResume) {
      methodChannel?.invokeMethod("onAudioInterruptionEnded", arguments: nil)
    }
  }

  @objc private func handleAudioRouteChange(notification: Notification) {
    guard let info = notification.userInfo,
          let reasonValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
          let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
      return
    }

    let session = AVAudioSession.sharedInstance()
    let inputs = session.currentRoute.inputs
      .map { "\($0.portName):\($0.portType.rawValue)" }
      .joined(separator: "|")
    let outputs = session.currentRoute.outputs
      .map { "\($0.portName):\($0.portType.rawValue)" }
      .joined(separator: "|")

    methodChannel?.invokeMethod(
      "onAudioRouteChanged",
      arguments: [
        "reason": routeChangeReasonName(reason),
        "inputs": inputs.isEmpty ? "none" : inputs,
        "outputs": outputs.isEmpty ? "none" : outputs,
      ]
    )
  }

  private func routeChangeReasonName(_ reason: AVAudioSession.RouteChangeReason) -> String {
    switch reason {
    case .unknown:
      return "unknown"
    case .newDeviceAvailable:
      return "newDeviceAvailable"
    case .oldDeviceUnavailable:
      return "oldDeviceUnavailable"
    case .categoryChange:
      return "categoryChange"
    case .override:
      return "override"
    case .wakeFromSleep:
      return "wakeFromSleep"
    case .noSuitableRouteForCategory:
      return "noSuitableRouteForCategory"
    case .routeConfigurationChange:
      return "routeConfigurationChange"
    @unknown default:
      return "unknown"
    }
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }
}
