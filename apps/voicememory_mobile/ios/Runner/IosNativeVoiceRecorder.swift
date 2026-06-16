import AVFoundation
import Flutter

/// Native AVAudioRecorder capture for physical iOS when the Flutter record plugin
/// produces silent files despite a correct route/session.
final class IosNativeVoiceRecorder {
  static let shared = IosNativeVoiceRecorder()

  private enum RecordingFormat: String {
    case aac
    case wav
  }

  private var recorder: AVAudioRecorder?
  private var startedAt: Date?
  private var activePath: String?
  private var activeFormat: RecordingFormat?
  private var meterTimer: Timer?
  private var lastFailedStep: String?

  private var minDb: Float = -160
  private var maxDb: Float = -160
  private var sumDb: Double = 0
  private var sampleCount: Int = 0
  private var lastLevelLogAt: Date?

  private let silentThresholdDb: Float = -45
  private let logPrefix = "ARCHIVEME_NATIVE_RECORDER"

  private init() {}

  func isAvailable() -> Bool {
    true
  }

  var lastFailureStep: String? {
    lastFailedStep
  }

  func start(path: String) throws -> String {
    stopInternal(deleteFile: true)
    lastFailedStep = nil

    logStep("prepare_session_start")
    try configureSession()

    let aacURL = try resolveRecordingURL(preferredPath: path, fileExtension: "m4a")
    do {
      let resolvedPath = try startRecording(at: aacURL, format: .aac)
      logStartSuccess(path: resolvedPath, format: .aac)
      return resolvedPath
    } catch let aacError {
      print("\(logPrefix)_FALLBACK format=wav reason=\(aacError.localizedDescription)")
      cleanupPartialFile(at: aacURL)

      let wavURL = try resolveRecordingURL(
        preferredPath: swapPathExtension(path, to: "wav"),
        fileExtension: "wav"
      )
      do {
        let resolvedPath = try startRecording(at: wavURL, format: .wav)
        logStartSuccess(path: resolvedPath, format: .wav)
        return resolvedPath
      } catch let wavError {
        throw wrapFailure(
          wavError,
          step: lastFailedStep ?? "record_start",
          attemptedFormats: "aac,wav"
        )
      }
    }
  }

  func stop() throws -> [String: Any] {
    guard let recorder = recorder else {
      throw RecorderError(step: "stop", message: "No active native recording")
    }

    stopMeterTimer()
    recorder.stop()

    let path = activePath ?? recorder.url.path
    let startedAt = self.startedAt ?? Date()
    let durationMs = Int(Date().timeIntervalSince(startedAt) * 1000)

    let bytes: Int
    if FileManager.default.fileExists(atPath: path),
       let attrs = try? FileManager.default.attributesOfItem(atPath: path),
       let size = attrs[.size] as? NSNumber {
      bytes = size.intValue
    } else {
      bytes = 0
    }

    let avgDb = sampleCount > 0 ? Float(sumDb / Double(sampleCount)) : -160
    let resolvedMaxDb = maxDb
    let likelySilent = sampleCount == 0 || resolvedMaxDb < silentThresholdDb
    let format = activeFormat?.rawValue ?? "unknown"

    print(
      "\(logPrefix)_STOP path=\(path) bytes=\(bytes) durationMs=\(durationMs) " +
        "format=\(format) maxDb=\(resolvedMaxDb) avgDb=\(avgDb) likelySilent=\(likelySilent)"
    )

    self.recorder = nil
    self.activePath = nil
    self.activeFormat = nil
    self.startedAt = nil

    return [
      "path": path,
      "bytes": bytes,
      "durationMs": durationMs,
      "minDb": Double(minDb.isFinite ? minDb : -160),
      "maxDb": Double(resolvedMaxDb),
      "avgDb": Double(avgDb),
      "likelySilent": likelySilent,
      "format": format,
    ]
  }

  func currentLevel() -> [String: Any] {
    guard let recorder = recorder else {
      return [
        "currentDb": -160.0,
        "peakDb": -160.0,
        "maxDb": Double(maxDb),
        "avgDb": sampleCount > 0 ? sumDb / Double(sampleCount) : -160.0,
      ]
    }

    recorder.updateMeters()
    let currentDb = recorder.averagePower(forChannel: 0)
    let peakDb = recorder.peakPower(forChannel: 0)
    recordMeterSample(currentDb: currentDb, peakDb: peakDb)

    return [
      "currentDb": Double(currentDb),
      "peakDb": Double(peakDb),
      "maxDb": Double(maxDb),
      "avgDb": sampleCount > 0 ? sumDb / Double(sampleCount) : Double(currentDb),
    ]
  }

  private func configureSession() throws {
    let session = AVAudioSession.sharedInstance()

    do {
      try session.setCategory(.playAndRecord, options: [.defaultToSpeaker])
      logStep("set_category_ok")
    } catch {
      lastFailedStep = "set_category_failed"
      logStep("set_category_failed error=\(error.localizedDescription)")
      throw error
    }

    do {
      try session.setMode(.default)
      logStep("set_mode_ok")
    } catch {
      lastFailedStep = "set_mode_failed"
      logStep("set_mode_failed error=\(error.localizedDescription)")
      throw error
    }

    if let inputs = session.availableInputs,
       let builtInMic = inputs.first(where: { $0.portType == .builtInMic }) {
      do {
        try session.setPreferredInput(builtInMic)
        logStep("set_preferred_input_ok input=\(builtInMic.portName)")
      } catch {
        logStep("set_preferred_input_failed error=\(error.localizedDescription)")
      }
    } else {
      logStep("set_preferred_input_skipped reason=no_built_in_mic")
    }

    do {
      try session.setActive(true)
      logStep("set_active_ok")
    } catch {
      lastFailedStep = "set_active_failed"
      logStep("set_active_failed error=\(error.localizedDescription)")
      throw error
    }
  }

  private func startRecording(at url: URL, format: RecordingFormat) throws -> String {
    let path = url.path
    logStep("create_file_url path=\(path) url=\(url.absoluteString)")

    let settings = settingsForFormat(format)
    logStep("settings=\(settingsDescription(settings)) format=\(format.rawValue)")

    let newRecorder: AVAudioRecorder
    do {
      newRecorder = try AVAudioRecorder(url: url, settings: settings)
      logStep("recorder_init_ok format=\(format.rawValue)")
    } catch {
      lastFailedStep = "recorder_init_failed"
      logStep("recorder_init_failed error=\(error.localizedDescription) format=\(format.rawValue)")
      throw error
    }

    newRecorder.isMeteringEnabled = true

    let prepared = newRecorder.prepareToRecord()
    if prepared {
      logStep("prepare_to_record_ok format=\(format.rawValue)")
    } else {
      lastFailedStep = "prepare_to_record_failed"
      logStep("prepare_to_record_failed error=prepareToRecord returned false format=\(format.rawValue)")
      throw RecorderError(
        step: "prepare_to_record_failed",
        message: "prepareToRecord returned false for \(format.rawValue)"
      )
    }

    let started = newRecorder.record()
    logStep("record_started \(started) format=\(format.rawValue)")
    guard started else {
      lastFailedStep = "record_start_failed"
      throw RecorderError(
        step: "record_start_failed",
        message: "AVAudioRecorder.record() returned false for \(format.rawValue)"
      )
    }

    recorder = newRecorder
    activePath = path
    activeFormat = format
    startedAt = Date()
    resetMeterStats()
    startMeterTimer()
    return path
  }

  private func resolveRecordingURL(preferredPath: String, fileExtension: String) throws -> URL {
    let trimmed = preferredPath.trimmingCharacters(in: .whitespacesAndNewlines)
    let url: URL

    if trimmed.isEmpty || !isUsablePreferredPath(trimmed) {
      guard let cacheDir = FileManager.default.urls(
        for: .cachesDirectory,
        in: .userDomainMask
      ).first else {
        lastFailedStep = "create_file_url_failed"
        throw RecorderError(step: "create_file_url_failed", message: "Caches directory unavailable")
      }
      let filename = "vm_native_\(Int(Date().timeIntervalSince1970 * 1000)).\(fileExtension)"
      url = cacheDir.appendingPathComponent(filename)
    } else {
      let normalized = swapPathExtension(trimmed, to: fileExtension)
      url = URL(fileURLWithPath: normalized)
    }

    let parent = url.deletingLastPathComponent()
    try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)

    if FileManager.default.fileExists(atPath: url.path) {
      try FileManager.default.removeItem(at: url)
    }

    logStep("create_file_url path=\(url.path) url=\(url.absoluteString)")
    return url
  }

  private func isUsablePreferredPath(_ path: String) -> Bool {
    if path.isEmpty { return false }
    if path.contains("..") { return false }
    if !path.hasPrefix("/") { return false }
    return true
  }

  private func swapPathExtension(_ path: String, to fileExtension: String) -> String {
    let url = URL(fileURLWithPath: path)
    if url.pathExtension.lowercased() == fileExtension.lowercased() {
      return path
    }
    return url.deletingPathExtension().appendingPathExtension(fileExtension).path
  }

  private func settingsForFormat(_ format: RecordingFormat) -> [String: Any] {
    switch format {
    case .aac:
      return [
        AVFormatIDKey: NSNumber(value: kAudioFormatMPEG4AAC),
        AVSampleRateKey: NSNumber(value: 44100.0),
        AVNumberOfChannelsKey: NSNumber(value: 1),
        AVEncoderAudioQualityKey: NSNumber(value: AVAudioQuality.high.rawValue),
        AVEncoderBitRateKey: NSNumber(value: 96000),
      ]
    case .wav:
      return [
        AVFormatIDKey: NSNumber(value: kAudioFormatLinearPCM),
        AVSampleRateKey: NSNumber(value: 44100.0),
        AVNumberOfChannelsKey: NSNumber(value: 1),
        AVLinearPCMBitDepthKey: NSNumber(value: 16),
        AVLinearPCMIsFloatKey: NSNumber(value: false),
        AVLinearPCMIsBigEndianKey: NSNumber(value: false),
      ]
    }
  }

  private func settingsDescription(_ settings: [String: Any]) -> String {
    settings
      .map { key, value in "\(key)=\(value)" }
      .sorted()
      .joined(separator: ",")
  }

  private func cleanupPartialFile(at url: URL) {
    if FileManager.default.fileExists(atPath: url.path) {
      try? FileManager.default.removeItem(at: url)
    }
  }

  private func logStartSuccess(path: String, format: RecordingFormat) {
    let inputName = currentInputLabel()
    print("\(logPrefix)_START path=\(path) format=\(format.rawValue)")
    print(
      "\(logPrefix)_SESSION category=playAndRecord mode=default input=\(inputName)"
    )
  }

  private func currentInputLabel() -> String {
    let session = AVAudioSession.sharedInstance()
    if let input = session.preferredInput ?? session.currentRoute.inputs.first {
      return "\(input.portName):\(input.portType.rawValue)"
    }
    return "unknown"
  }

  private func startMeterTimer() {
    stopMeterTimer()
    meterTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
      self?.sampleMeters()
    }
  }

  private func stopMeterTimer() {
    meterTimer?.invalidate()
    meterTimer = nil
  }

  private func sampleMeters() {
    guard let recorder = recorder else { return }
    recorder.updateMeters()
    let currentDb = recorder.averagePower(forChannel: 0)
    let peakDb = recorder.peakPower(forChannel: 0)
    recordMeterSample(currentDb: currentDb, peakDb: peakDb)

    let now = Date()
    if lastLevelLogAt == nil || now.timeIntervalSince(lastLevelLogAt!) >= 1.0 {
      lastLevelLogAt = now
      let avgDb = sampleCount > 0 ? Float(sumDb / Double(sampleCount)) : currentDb
      print(
        "\(logPrefix)_LEVEL currentDb=\(currentDb) peakDb=\(peakDb) " +
          "maxDb=\(maxDb) avgDb=\(avgDb)"
      )
    }
  }

  private func recordMeterSample(currentDb: Float, peakDb: Float) {
    sampleCount += 1
    if sampleCount == 1 {
      minDb = currentDb
      maxDb = peakDb
    } else {
      minDb = min(minDb, currentDb)
      maxDb = max(maxDb, peakDb)
      maxDb = max(maxDb, currentDb)
    }
    sumDb += Double(currentDb)
  }

  private func resetMeterStats() {
    minDb = -160
    maxDb = -160
    sumDb = 0
    sampleCount = 0
    lastLevelLogAt = nil
  }

  private func stopInternal(deleteFile: Bool) {
    stopMeterTimer()
    if let recorder = recorder {
      recorder.stop()
      if deleteFile {
        try? FileManager.default.removeItem(at: recorder.url)
      }
    }
    recorder = nil
    activePath = nil
    activeFormat = nil
    startedAt = nil
    resetMeterStats()
  }

  private func logStep(_ message: String) {
    print("\(logPrefix)_STEP \(message)")
  }

  private func wrapFailure(
    _ error: Error,
    step: String,
    attemptedFormats: String? = nil
  ) -> RecorderError {
    if let recorderError = error as? RecorderError {
      lastFailedStep = recorderError.step
      return recorderError
    }
    lastFailedStep = step
    var message = error.localizedDescription
    if let attemptedFormats = attemptedFormats {
      message = "\(message) attemptedFormats=\(attemptedFormats)"
    }
    return RecorderError(step: step, message: message)
  }

  struct RecorderError: LocalizedError {
    let step: String
    let message: String
    var errorDescription: String? { message }
  }
}

final class IosNativeVoiceRecorderHandler {
  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let recorder = IosNativeVoiceRecorder.shared
    switch call.method {
    case "isNativeRecorderAvailable":
      result(recorder.isAvailable())

    case "startNativeRecording":
      let path = (call.arguments as? [String: Any])?["path"] as? String ?? ""
      do {
        let resolvedPath = try recorder.start(path: path)
        result(["path": resolvedPath])
      } catch let error as IosNativeVoiceRecorder.RecorderError {
        print(
          "ARCHIVEME_NATIVE_RECORDER_FAILED step=\(error.step) reason=\(error.message)"
        )
        result(
          FlutterError(
            code: "native_recorder_start",
            message: error.message,
            details: [
              "step": error.step,
              "reason": error.message,
            ]
          )
        )
      } catch {
        let step = recorder.lastFailureStep ?? "unknown"
        print("ARCHIVEME_NATIVE_RECORDER_FAILED step=\(step) reason=\(error.localizedDescription)")
        result(
          FlutterError(
            code: "native_recorder_start",
            message: error.localizedDescription,
            details: [
              "step": step,
              "reason": error.localizedDescription,
            ]
          )
        )
      }

    case "stopNativeRecording":
      do {
        let payload = try recorder.stop()
        result(payload)
      } catch let error as IosNativeVoiceRecorder.RecorderError {
        print(
          "ARCHIVEME_NATIVE_RECORDER_FAILED step=\(error.step) reason=\(error.message)"
        )
        result(
          FlutterError(
            code: "native_recorder_stop",
            message: error.message,
            details: [
              "step": error.step,
              "reason": error.message,
            ]
          )
        )
      } catch {
        print("ARCHIVEME_NATIVE_RECORDER_FAILED reason=\(error.localizedDescription)")
        result(
          FlutterError(
            code: "native_recorder_stop",
            message: error.localizedDescription,
            details: [
              "step": "stop",
              "reason": error.localizedDescription,
            ]
          )
        )
      }

    case "currentNativeLevel":
      result(recorder.currentLevel())

    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
