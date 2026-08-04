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

  private enum ProcessingControl: String {
    case platformDefault = "default"
    case enabled
    case disabled

    static func from(_ value: Any?) -> ProcessingControl {
      guard let value = value as? String else { return .platformDefault }
      return ProcessingControl(rawValue: value) ?? .platformDefault
    }
  }

  private struct CaptureConfig {
    let format: RecordingFormat
    let sampleRate: Double
    let channels: Int
    let bitDepth: Int
    let bufferDuration: TimeInterval
    let sessionMode: String
    let acousticEchoCancellation: ProcessingControl
    let noiseSuppression: ProcessingControl
    let automaticGainControl: ProcessingControl

    var requestsVoiceProcessing: Bool {
      sessionMode == "spokenAudio" && [
        acousticEchoCancellation,
        noiseSuppression,
        automaticGainControl,
      ].contains(.enabled)
    }

    static func from(arguments: [String: Any]?) -> CaptureConfig {
      let values = arguments?["config"] as? [String: Any] ?? [:]
      let formatValue = (values["format"] as? String)?.lowercased() ?? "wav"
      let requestedRate = (values["sampleRate"] as? NSNumber)?.doubleValue ?? 16000
      let requestedChannels = (values["channels"] as? NSNumber)?.intValue ?? 1
      let requestedBitDepth = (values["bitDepth"] as? NSNumber)?.intValue ?? 16
      let requestedBufferMs = (values["bufferDurationMs"] as? NSNumber)?.doubleValue ?? 20
      let requestedMode = values["sessionMode"] as? String ?? "spokenAudio"
      return CaptureConfig(
        format: formatValue == "aac" || formatValue == "m4a" ? .aac : .wav,
        sampleRate: min(max(requestedRate.isFinite ? requestedRate : 16000, 8000), 192000),
        channels: min(max(requestedChannels, 1), 2),
        bitDepth: min(max(requestedBitDepth, 8), 32),
        bufferDuration: min(
          max(requestedBufferMs.isFinite ? requestedBufferMs : 20, 1),
          500
        ) / 1000,
        sessionMode: ["measurement", "raw"].contains(requestedMode)
          ? requestedMode
          : "spokenAudio",
        acousticEchoCancellation: ProcessingControl.from(
          values["acousticEchoCancellation"]
        ),
        noiseSuppression: ProcessingControl.from(values["noiseSuppression"]),
        automaticGainControl: ProcessingControl.from(values["automaticGainControl"])
      )
    }

    var requestedProcessingPayload: [String: String] {
      [
        "acousticEchoCancellation": acousticEchoCancellation.rawValue,
        "noiseSuppression": noiseSuppression.rawValue,
        "automaticGainControl": automaticGainControl.rawValue,
      ]
    }

    func appliedProcessingPayload(voiceProcessingMode: Bool) -> [String: String] {
      if sessionMode == "measurement" || sessionMode == "raw" {
        return [
          "acousticEchoCancellation": ProcessingControl.disabled.rawValue,
          "noiseSuppression": ProcessingControl.disabled.rawValue,
          "automaticGainControl": ProcessingControl.disabled.rawValue,
        ]
      }
      if requestsVoiceProcessing && !voiceProcessingMode {
        return [
          "acousticEchoCancellation":
            acousticEchoCancellation == .enabled
              ? ProcessingControl.platformDefault.rawValue
              : acousticEchoCancellation.rawValue,
          "noiseSuppression":
            noiseSuppression == .enabled
              ? ProcessingControl.platformDefault.rawValue
              : noiseSuppression.rawValue,
          "automaticGainControl":
            automaticGainControl == .enabled
              ? ProcessingControl.platformDefault.rawValue
              : automaticGainControl.rawValue,
        ]
      }
      return requestedProcessingPayload
    }
  }

  private enum NativeRecordPermission: String {
    case granted
    case denied
    case undetermined
    case unknown
  }

  private var recorder: AVAudioRecorder?
  private var startedAt: Date?
  private var activePath: String?
  private var activeFormat: RecordingFormat?
  private var activeConfig: CaptureConfig?
  private var activeMetadata: [String: Any]?
  private var lastResult: [String: Any]?
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

  func microphonePermissionStatus() -> [String: Any] {
    let status = currentRecordPermissionStatus()
    logMicPermission(status)
    return [
      "status": status.rawValue,
      "granted": status == .granted,
      "canRequest": status == .undetermined,
    ]
  }

  func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
    if #available(iOS 17.0, *) {
      AVAudioApplication.requestRecordPermission { granted in
        DispatchQueue.main.async {
          completion(granted)
        }
      }
      return
    }

    AVAudioSession.sharedInstance().requestRecordPermission { granted in
      DispatchQueue.main.async {
        completion(granted)
      }
    }
  }

  func start(path: String, arguments: [String: Any]?) throws -> [String: Any] {
    let config = CaptureConfig.from(arguments: arguments)
    stopInternal(deleteFile: true)
    lastResult = nil
    lastFailedStep = nil

    logStep("prepare_session_start format=\(config.format.rawValue)")
    try ensureMicrophonePermissionGranted()

    let session = AVAudioSession.sharedInstance()
    logAudioRoute(session, label: "ARCHIVEME_NATIVE_AUDIO_ROUTE_BEFORE")

    try configureCaptureOnlySession(config: config)

    logAudioRoute(session, label: "ARCHIVEME_NATIVE_AUDIO_ROUTE_AFTER")
    logSelectedInput(session)

    let targetFormat = config.format

    if targetFormat == .wav {
      let wavURL = try resolveRecordingURL(
        preferredPath: swapPathExtension(path, to: "wav"),
        fileExtension: "wav"
      )
      let resolvedPath = try startRecording(at: wavURL, format: .wav, config: config)
      logStartSuccess(path: resolvedPath, format: .wav)
      return startPayload(path: resolvedPath, format: .wav, config: config)
    }

    let aacURL = try resolveRecordingURL(preferredPath: path, fileExtension: "m4a")
    do {
      let resolvedPath = try startRecording(at: aacURL, format: .aac, config: config)
      logStartSuccess(path: resolvedPath, format: .aac)
      return startPayload(path: resolvedPath, format: .aac, config: config)
    } catch let aacError {
      print("\(logPrefix)_FALLBACK format=wav reason=\(aacError.localizedDescription)")
      cleanupPartialFile(at: aacURL)

      let wavURL = try resolveRecordingURL(
        preferredPath: swapPathExtension(path, to: "wav"),
        fileExtension: "wav"
      )
      do {
        let resolvedPath = try startRecording(at: wavURL, format: .wav, config: config)
        logStartSuccess(path: resolvedPath, format: .wav)
        return startPayload(path: resolvedPath, format: .wav, config: config)
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
      if let lastResult {
        return lastResult
      }
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
    let metadata = activeMetadata ?? [:]

    let session = AVAudioSession.sharedInstance()
    logAudioRoute(session, label: "ARCHIVEME_NATIVE_AUDIO_ROUTE_AFTER")
    let selectedInput = resolvedSelectedInput(session)
    logSelectedInput(session)

    try? session.setActive(false, options: .notifyOthersOnDeactivation)

    print(
      "\(logPrefix)_STOP path=\(path) bytes=\(bytes) durationMs=\(durationMs) " +
        "format=\(format) maxDb=\(resolvedMaxDb) avgDb=\(avgDb) likelySilent=\(likelySilent)"
    )

    self.recorder = nil
    self.activePath = nil
    self.activeFormat = nil
    self.startedAt = nil
    self.activeConfig = nil
    self.activeMetadata = nil

    let result = metadata.merging([
      "path": path,
      "bytes": bytes,
      "durationMs": durationMs,
      "minDb": Double(minDb.isFinite ? minDb : -160),
      "maxDb": Double(resolvedMaxDb),
      "avgDb": Double(avgDb),
      "likelySilent": likelySilent,
      "format": format,
      "inputPortName": selectedInput.name,
      "inputPortType": selectedInput.type,
    ]) { _, stopValue in stopValue }
    lastResult = result
    return result
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

  func dispose() {
    if recorder != nil {
      _ = try? stop()
    } else {
      stopInternal(deleteFile: false)
    }
  }

  private func currentRecordPermissionStatus() -> NativeRecordPermission {
    if #available(iOS 17.0, *) {
      switch AVAudioApplication.shared.recordPermission {
      case .granted:
        return .granted
      case .denied:
        return .denied
      case .undetermined:
        return .undetermined
      @unknown default:
        return .unknown
      }
    }

    switch AVAudioSession.sharedInstance().recordPermission {
    case .granted:
      return .granted
    case .denied:
      return .denied
    case .undetermined:
      return .undetermined
    @unknown default:
      return .unknown
    }
  }

  private func ensureMicrophonePermissionGranted() throws {
    let status = currentRecordPermissionStatus()
    logMicPermission(status)
    guard status == .granted else {
      lastFailedStep = "microphone_permission_denied"
      throw RecorderError(
        step: "microphone_permission_denied",
        message: "Native microphone permission is \(status.rawValue)"
      )
    }
  }

  private func configureCaptureOnlySession(config: CaptureConfig) throws {
    let session = AVAudioSession.sharedInstance()
    let bluetoothOptions: AVAudioSession.CategoryOptions = [.allowBluetooth]

    do {
      try session.setActive(false, options: .notifyOthersOnDeactivation)
      logStep("set_active_false_ok")
    } catch {
      logStep("set_active_false_failed error=\(error.localizedDescription)")
    }

    let requestedMode: AVAudioSession.Mode
    if config.requestsVoiceProcessing {
      requestedMode = .voiceChat
    } else {
      requestedMode = config.sessionMode == "spokenAudio" ? .spokenAudio : .measurement
    }
    let requestedCategory: AVAudioSession.Category =
      config.sessionMode == "spokenAudio" ? .playAndRecord : .record
    var categoryConfigured = false
    do {
      try session.setCategory(requestedCategory, mode: requestedMode, options: bluetoothOptions)
      logStep(
        "set_category_ok category=\(requestedCategory.rawValue) " +
          "mode=\(requestedMode.rawValue) options=allowBluetooth"
      )
      categoryConfigured = true
    } catch {
      logStep("set_category_measurement_failed error=\(error.localizedDescription)")
    }

    if !categoryConfigured {
      do {
        try session.setCategory(.record, mode: .default, options: bluetoothOptions)
        logStep("set_category_ok category=record mode=default options=allowBluetooth")
        categoryConfigured = true
      } catch {
        logStep("set_category_record_default_failed error=\(error.localizedDescription)")
      }
    }

    if !categoryConfigured {
      do {
        try session.setCategory(
          .playAndRecord,
          mode: .measurement,
          options: bluetoothOptions
        )
        logStep(
          "set_category_ok category=playAndRecord mode=measurement options=allowBluetooth"
        )
        categoryConfigured = true
      } catch {
        lastFailedStep = "set_category_failed"
        logStep("set_category_playAndRecord_failed error=\(error.localizedDescription)")
        throw error
      }
    }

    do {
      try session.setPreferredSampleRate(config.sampleRate)
      logStep("set_preferred_sample_rate_ok sampleRate=\(config.sampleRate)")
    } catch {
      logStep("set_preferred_sample_rate_failed error=\(error.localizedDescription)")
    }

    do {
      try session.setPreferredInputNumberOfChannels(config.channels)
      logStep("set_preferred_input_channels_ok channels=\(config.channels)")
    } catch {
      logStep("set_preferred_input_channels_failed error=\(error.localizedDescription)")
    }

    do {
      try session.setPreferredIOBufferDuration(config.bufferDuration)
      logStep("set_preferred_io_buffer_ok seconds=\(config.bufferDuration)")
    } catch {
      logStep("set_preferred_io_buffer_failed error=\(error.localizedDescription)")
    }

    do {
      try session.setActive(true)
      logStep("set_active_ok")
    } catch {
      lastFailedStep = "set_active_failed"
      logStep("set_active_failed error=\(error.localizedDescription)")
      throw error
    }

    selectPreferredRecordingInput(session)
  }

  private func selectPreferredRecordingInput(_ session: AVAudioSession) {
    logAvailableInputs(session)

    guard let inputs = session.availableInputs, !inputs.isEmpty else {
      print("ARCHIVEME_NATIVE_INPUT_SELECTION preferred=default name=none type=none")
      return
    }

    let headsetTypes: Set<AVAudioSession.Port> = [
      .bluetoothHFP,
      .bluetoothLE,
      .headsetMic,
    ]

    if let headsetInput = inputs.first(where: { headsetTypes.contains($0.portType) }) {
      applyPreferredInput(
        session,
        input: headsetInput,
        preference: "bluetooth"
      )
      return
    }

    if let builtInMic = inputs.first(where: { $0.portType == .builtInMic }) {
      applyPreferredInput(
        session,
        input: builtInMic,
        preference: "builtin"
      )
      return
    }

    let fallback = inputs[0]
    applyPreferredInput(
      session,
      input: fallback,
      preference: "default"
    )
  }

  private func applyPreferredInput(
    _ session: AVAudioSession,
    input: AVAudioSessionPortDescription,
    preference: String
  ) {
    do {
      try session.setPreferredInput(input)
      print(
        "ARCHIVEME_NATIVE_INPUT_SELECTION preferred=\(preference) " +
          "name=\(input.portName) type=\(input.portType.rawValue)"
      )
    } catch {
      print(
        "ARCHIVEME_NATIVE_INPUT_SELECTION preferred=\(preference) " +
          "name=\(input.portName) type=\(input.portType.rawValue) " +
          "error=\(error.localizedDescription)"
      )
    }
  }

  private func logAvailableInputs(_ session: AVAudioSession) {
    let available = session.availableInputs ?? []
    let description = available
      .map { "\($0.portName):\($0.portType.rawValue)" }
      .joined(separator: ",")
    print(
      "ARCHIVEME_NATIVE_AVAILABLE_INPUTS inputs=\(description.isEmpty ? "none" : description)"
    )
  }

  private func startRecording(
    at url: URL,
    format: RecordingFormat,
    config: CaptureConfig
  ) throws -> String {
    let path = url.path
    logStep("create_file_url path=\(path) url=\(url.absoluteString)")

    let settings = settingsForFormat(format, config: config)
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
    activeConfig = config
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

  private func settingsForFormat(
    _ format: RecordingFormat,
    config: CaptureConfig
  ) -> [String: Any] {
    switch format {
    case .aac:
      return [
        AVFormatIDKey: NSNumber(value: kAudioFormatMPEG4AAC),
        AVSampleRateKey: NSNumber(value: config.sampleRate),
        AVNumberOfChannelsKey: NSNumber(value: config.channels),
        AVEncoderAudioQualityKey: NSNumber(value: AVAudioQuality.high.rawValue),
        AVEncoderBitRateKey: NSNumber(value: 96000),
      ]
    case .wav:
      return [
        AVFormatIDKey: NSNumber(value: kAudioFormatLinearPCM),
        AVSampleRateKey: NSNumber(value: config.sampleRate),
        AVNumberOfChannelsKey: NSNumber(value: config.channels),
        AVLinearPCMBitDepthKey: NSNumber(value: config.bitDepth),
        AVLinearPCMIsFloatKey: NSNumber(value: false),
        AVLinearPCMIsBigEndianKey: NSNumber(value: false),
        AVLinearPCMIsNonInterleaved: NSNumber(value: false),
      ]
    }
  }

  private func settingsDescription(_ settings: [String: Any]) -> String {
    settings
      .map { key, value in "\(key)=\(value)" }
      .sorted()
      .joined(separator: ",")
  }

  private func startPayload(
    path: String,
    format: RecordingFormat,
    config: CaptureConfig
  ) -> [String: Any] {
    let session = AVAudioSession.sharedInstance()
    let recorderSettings = recorder?.settings ?? [:]
    let appliedSampleRate =
      (recorderSettings[AVSampleRateKey] as? NSNumber)?.doubleValue ?? session.sampleRate
    let appliedChannels =
      (recorderSettings[AVNumberOfChannelsKey] as? NSNumber)?.intValue
        ?? max(session.inputNumberOfChannels, 1)
    let appliedBitDepth =
      (recorderSettings[AVLinearPCMBitDepthKey] as? NSNumber)?.intValue ?? config.bitDepth
    let selectedInput = resolvedSelectedInput(session)
    let voiceProcessingMode = config.requestsVoiceProcessing && session.mode == .voiceChat
    let payload: [String: Any] = [
      "path": path,
      "format": format.rawValue,
      "sampleRate": appliedSampleRate,
      "channels": appliedChannels,
      "bitDepth": appliedBitDepth,
      "bufferDurationMs": session.ioBufferDuration * 1000,
      "sessionMode": session.mode.rawValue,
      "audioSource": selectedInput.type,
      "inputPortName": selectedInput.name,
      "inputPortType": selectedInput.type,
      "processing": [
        "requested": config.requestedProcessingPayload,
        "applied": config.appliedProcessingPayload(
          voiceProcessingMode: voiceProcessingMode
        ),
        // AVAudioRecorder does not expose independent AEC/NS/AGC capability
        // or state. Do not infer individual effect state from the session mode.
        "supported": [
          "acousticEchoCancellation": false,
          "noiseSuppression": false,
          "automaticGainControl": false,
        ],
        "enabled": [
          "acousticEchoCancellation": NSNull(),
          "noiseSuppression": NSNull(),
          "automaticGainControl": NSNull(),
        ],
        "voiceProcessingMode": voiceProcessingMode,
        "platformManaged": voiceProcessingMode,
      ] as [String: Any],
    ]
    activeMetadata = payload
    return payload
  }

  private func cleanupPartialFile(at url: URL) {
    if FileManager.default.fileExists(atPath: url.path) {
      try? FileManager.default.removeItem(at: url)
    }
  }

  private func logStartSuccess(path: String, format: RecordingFormat) {
    print("\(logPrefix)_START path=\(path) format=\(format.rawValue)")
    print("\(logPrefix)_SESSION category=record mode=capture_only format=\(format.rawValue)")
  }

  private func logMicPermission(_ status: NativeRecordPermission) {
    print(
      "ARCHIVEME_NATIVE_MIC_PERMISSION status=\(status.rawValue) " +
        "granted=\(status == .granted)"
    )
  }

  private func logAudioRoute(_ session: AVAudioSession, label: String) {
    let route = session.currentRoute
    let inputs = route.inputs
      .map { "\($0.portName):\($0.portType.rawValue)" }
      .joined(separator: ",")
    let outputs = route.outputs
      .map { "\($0.portName):\($0.portType.rawValue)" }
      .joined(separator: ",")
    print("\(label) inputs=\(inputs.isEmpty ? "none" : inputs) outputs=\(outputs.isEmpty ? "none" : outputs)")
  }

  private func logSelectedInput(_ session: AVAudioSession) {
    let input = resolvedSelectedInput(session)
    if input.name.isEmpty && input.type.isEmpty {
      print("ARCHIVEME_NATIVE_SELECTED_INPUT name=none type=unknown")
      return
    }
    print(
      "ARCHIVEME_NATIVE_SELECTED_INPUT name=\(input.name) type=\(input.type)"
    )
  }

  private func resolvedSelectedInput(_ session: AVAudioSession) -> (name: String, type: String) {
    if let input = session.preferredInput ?? session.currentRoute.inputs.first {
      return (input.portName, input.portType.rawValue)
    }
    return ("", "")
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
    activeConfig = nil
    activeMetadata = nil
    startedAt = nil
    resetMeterStats()
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
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

    case "nativeMicrophonePermission":
      result(recorder.microphonePermissionStatus())

    case "requestNativeMicrophonePermission":
      recorder.requestMicrophonePermission { _ in
        result(recorder.microphonePermissionStatus())
      }

    case "startNativeRecording":
      let args = call.arguments as? [String: Any]
      let path = args?["path"] as? String ?? ""
      do {
        result(try recorder.start(path: path, arguments: args))
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

    case "disposeNativeRecorder":
      recorder.dispose()
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func dispose() {
    IosNativeVoiceRecorder.shared.dispose()
  }
}
