import AVFoundation
import Flutter

/// Hardened AVAudioSession setup for voice capture on physical iOS devices.
enum IosCaptureAudioSession {
  private static let logPrefix = "ARCHIVEME_IOS"

  static func configure(mode: String) throws -> [String: Any] {
    let session = AVAudioSession.sharedInstance()
    let avMode: AVAudioSession.Mode = mode == "measurement" ? .measurement : .spokenAudio

    var options: AVAudioSession.CategoryOptions = [
      .defaultToSpeaker,
      .allowBluetooth,
    ]
    if #available(iOS 10.0, *) {
      options.insert(.allowBluetoothA2DP)
    }

    try session.setCategory(.playAndRecord, mode: avMode, options: options)
    try session.setPreferredSampleRate(44100)
    try session.setPreferredInputNumberOfChannels(1)
    try session.setPreferredIOBufferDuration(0.02)
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
    case "configureCaptureSession":
      guard let args = call.arguments as? [String: Any],
            let mode = args["mode"] as? String else {
        result(
          FlutterError(
            code: "invalid_args",
            message: "Expected mode string",
            details: nil
          )
        )
        return
      }
      do {
        let snapshot = try IosCaptureAudioSession.configure(mode: mode)
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
