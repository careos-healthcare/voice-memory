import Flutter
import Speech

final class IosNativeSpeechTranscription {
  static let shared = IosNativeSpeechTranscription()

  private init() {}

  func transcribe(
    audioPath: String,
    preferOnDevice: Bool,
    completion: @escaping (Result<[String: Any], Error>) -> Void
  ) {
    SFSpeechRecognizer.requestAuthorization { status in
      guard status == .authorized else {
        completion(
          .success([
            "transcript": "",
            "reason": "speech_permission_\(status.rawValue)",
          ])
        )
        return
      }

      let url = URL(fileURLWithPath: audioPath)
      let request = SFSpeechURLRecognitionRequest(url: url)
      request.shouldReportPartialResults = false
      if #available(iOS 13.0, *) {
        request.requiresOnDeviceRecognition = preferOnDevice
      }

      guard let recognizer = SFSpeechRecognizer(), recognizer.isAvailable else {
        completion(
          .success([
            "transcript": "",
            "reason": "recognizer_unavailable",
          ])
        )
        return
      }

      recognizer.recognitionTask(with: request) { result, error in
        if let error {
          completion(
            .success([
              "transcript": "",
              "reason": error.localizedDescription,
            ])
          )
          return
        }
        guard let result, result.isFinal else {
          return
        }
        let transcript = result.bestTranscription.formattedString.trimmingCharacters(
          in: .whitespacesAndNewlines
        )
        completion(
          .success([
            "transcript": transcript,
            "reason": transcript.isEmpty ? "empty_native_transcript" : "",
          ])
        )
      }
    }
  }
}

final class IosNativeSpeechTranscriptionHandler {
  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "transcribeFile":
      guard let args = call.arguments as? [String: Any],
            let audioPath = args["audioPath"] as? String else {
        result(
          FlutterError(code: "invalid_args", message: "Expected audioPath", details: nil)
        )
        return
      }
      let preferOnDevice = args["preferOnDevice"] as? Bool ?? true
      IosNativeSpeechTranscription.shared.transcribe(
        audioPath: audioPath,
        preferOnDevice: preferOnDevice
      ) { outcome in
        switch outcome {
        case .success(let payload):
          result(payload)
        case .failure(let error):
          result(
            FlutterError(
              code: "native_stt_failed",
              message: error.localizedDescription,
              details: nil
            )
          )
        }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
