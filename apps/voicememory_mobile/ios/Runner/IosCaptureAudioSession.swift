import AVFoundation
import Flutter

/// Hardened AVAudioSession setup for voice capture on physical iOS devices.
enum IosCaptureAudioSession {
  private static let logPrefix = "ARCHIVEME_IOS"

  static func configureForPlayback() throws -> [String: Any] {
    let session = AVAudioSession.sharedInstance()

    do {
      try session.setActive(false, options: .notifyOthersOnDeactivation)
    } catch {
      print(
        "\(logPrefix)_AUDIO_SESSION playback_set_active_false_failed " +
          "error=\(error.localizedDescription)"
      )
    }

    try session.setCategory(
      .playAndRecord,
      mode: .default,
      options: [.defaultToSpeaker, .allowBluetooth]
    )
    try session.setActive(true)
    logRouteDiagnostics(session: session)

    let outputVolume = session.outputVolume
    print(
      "\(logPrefix)_AUDIO_SESSION category=playAndRecord mode=default playback=true " +
        "outputVolume=\(outputVolume)"
    )
    return [
      "category": "playAndRecord",
      "mode": "default",
      "outputVolume": Double(outputVolume),
      "configured": true,
    ]
  }

  static func configure(config: [String: Any]) throws -> [String: Any] {
    let session = AVAudioSession.sharedInstance()
    let mode = config["sessionMode"] as? String ?? config["mode"] as? String ?? "spokenAudio"
    let avMode: AVAudioSession.Mode =
      mode == "measurement" || mode == "raw" ? .measurement : .spokenAudio
    let sampleRate = (config["sampleRate"] as? NSNumber)?.doubleValue ?? 16000
    let channels = (config["channels"] as? NSNumber)?.intValue ?? 1
    let bufferMs = (config["bufferDurationMs"] as? NSNumber)?.doubleValue ?? 20

    var options: AVAudioSession.CategoryOptions = [
      .defaultToSpeaker,
      .allowBluetooth,
    ]
    if #available(iOS 10.0, *) {
      options.insert(.allowBluetoothA2DP)
    }

    try session.setCategory(.playAndRecord, mode: avMode, options: options)
    try session.setPreferredSampleRate(max(sampleRate, 8000))
    try session.setPreferredInputNumberOfChannels(max(channels, 1))
    try session.setPreferredIOBufferDuration(max(bufferMs, 1) / 1000)
    try session.setActive(true)

    preferBuiltInMic(session: session)
    logRouteDiagnostics(session: session)

    return snapshot(session: session, mode: mode)
  }

  private static func preferBuiltInMic(session: AVAudioSession) {
    guard let inputs = session.availableInputs else {
      return
    }
    guard let builtInMic = inputs.first(where: { $0.portType == .builtInMic }) else {
      return
    }
    do {
      try session.setPreferredInput(builtInMic)
      print(
        "\(logPrefix)_AUDIO_INPUT selected=\(builtInMic.portName) " +
          "type=\(builtInMic.portType.rawValue)"
      )
    } catch {
      print("\(logPrefix)_AUDIO_INPUT selected=failed error=\(error.localizedDescription)")
    }
  }

  private static func logRouteDiagnostics(session: AVAudioSession) {
    let inputs = formatPorts(session.currentRoute.inputs)
    let outputs = formatPorts(session.currentRoute.outputs)
    print("\(logPrefix)_AUDIO_ROUTE inputs=\(inputs) outputs=\(outputs)")

    let available = session.availableInputs ?? []
    let names = available.map { $0.portName }.joined(separator: ",")
    print(
      "\(logPrefix)_AUDIO_AVAILABLE_INPUTS count=\(available.count) names=\(names)"
    )

    if let selected = session.preferredInput ?? session.currentRoute.inputs.first {
      print(
        "\(logPrefix)_AUDIO_INPUT selected=\(selected.portName) " +
          "type=\(selected.portType.rawValue)"
      )
    }
  }

  private static func formatPorts(_ ports: [AVAudioSessionPortDescription]) -> String {
    if ports.isEmpty {
      return "none"
    }
    return ports
      .map { "\($0.portName):\($0.portType.rawValue)" }
      .joined(separator: "|")
  }

  private static func snapshot(session: AVAudioSession, mode: String) -> [String: Any] {
    let inputChannels = session.inputNumberOfChannels
    let sampleRate = session.sampleRate
    let outputVolume = session.outputVolume
    print(
      "\(logPrefix)_AUDIO_SESSION category=playAndRecord mode=\(mode) " +
        "sampleRate=\(sampleRate) inputChannels=\(inputChannels) " +
        "outputVolume=\(outputVolume)"
    )
    return [
      "category": "playAndRecord",
      "mode": mode,
      "sampleRate": sampleRate,
      "inputChannels": inputChannels,
      "outputVolume": Double(outputVolume),
      "configured": true,
    ]
  }
}

final class IosCaptureAudioSessionHandler {
  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "configurePlaybackSession":
      do {
        let snapshot = try IosCaptureAudioSession.configureForPlayback()
        result(snapshot)
      } catch {
        print(
          "ARCHIVEME_IOS_AUDIO_SESSION configured=false playback=true " +
            "detail=\(error.localizedDescription)"
        )
        result(
          FlutterError(
            code: "audio_session",
            message: error.localizedDescription,
            details: nil
          )
        )
      }

    case "configureCaptureSession":
      guard let args = call.arguments as? [String: Any] else {
        result(
          FlutterError(
            code: "invalid_args",
            message: "Expected capture configuration",
            details: nil
          )
        )
        return
      }
      let mode = args["sessionMode"] as? String ?? args["mode"] as? String ?? "spokenAudio"
      do {
        let snapshot = try IosCaptureAudioSession.configure(config: args)
        result(snapshot)
      } catch {
        print(
          "ARCHIVEME_IOS_AUDIO_SESSION configured=false mode=\(mode) " +
            "detail=\(error.localizedDescription)"
        )
        result(
          FlutterError(
            code: "audio_session",
            message: error.localizedDescription,
            details: nil
          )
        )
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
