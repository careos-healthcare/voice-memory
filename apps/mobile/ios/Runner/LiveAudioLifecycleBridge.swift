import AVFoundation
import Flutter

/// Forwards AVAudioSession interruption and route changes to Flutter live voice.
final class LiveAudioLifecycleBridge: NSObject {
  static let channelName = "com.archiveme.live/audio_lifecycle"

  private weak var methodChannel: FlutterMethodChannel?

  func attach(to controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: Self.channelName,
      binaryMessenger: controller.binaryMessenger
    )
    methodChannel = channel
    setupAudioSessionObservers()
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
