import Flutter
import Foundation

/// Answers hardware and model questions for on-device Whisper.
///
/// Transcription itself stays on the Dart side when this build has no linked
/// WhisperKit engine: the method returns `whisper_engine_unavailable` and the
/// Dart router falls back to sherpa-onnx weights or the cloud endpoint.
enum WhisperKitChannelHandler {
  static let name = "com.archiveme/whisper_kit"

  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: name, binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "hardwareSupported":
        result(true)
      case "modelReady":
        result(modelDirectoryHasWeights())
      case "transcribeFile":
        transcribe(call: call, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func transcribe(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    let path = args?["audioPath"] as? String ?? ""
    if path.isEmpty || !FileManager.default.fileExists(atPath: path) {
      result(
        FlutterError(
          code: "audio_missing",
          message: "Recording file is missing",
          details: nil
        )
      )
      return
    }
    if !modelDirectoryHasWeights() {
      result(
        FlutterError(
          code: "model_missing",
          message: "Local Whisper model is not installed",
          details: nil
        )
      )
      return
    }
    result(
      FlutterError(
        code: "whisper_engine_unavailable",
        message: "On-device Whisper engine is not linked",
        details: nil
      )
    )
  }

  private static func modelDirectoryHasWeights() -> Bool {
    guard let documents = FileManager.default.urls(
      for: .documentDirectory,
      in: .userDomainMask
    ).first else {
      return false
    }
    let directory = documents.appendingPathComponent("whisper_kit", isDirectory: true)
    guard let names = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else {
      return false
    }
    return names.contains { name in
      let lower = name.lowercased()
      return lower.hasSuffix(".mlmodelc") || lower.hasSuffix(".bin") || lower == "encoder.onnx"
    }
  }
}
