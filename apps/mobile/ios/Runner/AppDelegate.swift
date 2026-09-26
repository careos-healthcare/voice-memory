import AVFoundation
import Flutter
import HealthKit
import Security
import UIKit
import WatchConnectivity
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let legacyCleanupChannelName = "archive_me/excluded_capability_cleanup"
  private let watchChannelName = "archive_me/watch_session"
  private let captureAudioChannelName = "archive_me/ios_capture_audio"
  private let captureCompressorChannelName = "archive_me/capture_audio_compressor"
  private let nativeSpeechChannelName = "archive_me/native_speech_transcription"
  private let hardwareMonitorChannelName = "archive_me/hardware_monitor"
  private let captureAudioSessionHandler = IosCaptureAudioSessionHandler()
  private let captureAudioCompressorHandler = IosCaptureAudioCompressorHandler()
  private let nativeSpeechTranscriptionHandler = IosNativeSpeechTranscriptionHandler()
  private let hardwareMonitorChannelHandler = HardwareMonitorChannelHandler()
  private let liveAudioLifecycleBridge = LiveAudioLifecycleBridge()
  private let quickCaptureWidgetChannelHandler = QuickCaptureWidgetChannelHandler()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    WorkmanagerPlugin.registerLaunchHandlers()
    WorkmanagerPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    WorkmanagerPlugin.registerBGProcessingTask(
      withIdentifier: "com.voicememory.mobile.weeklyTopicSynthesis"
    )

    GeneratedPluginRegistrant.register(with: self)
    LegacyWidgetSharedDataCleanup.clearIfPresent()

    let didFinish = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    if let controller = window?.rootViewController as? FlutterViewController {
      setupLegacyCleanupChannel(controller: controller)
      setupWatchChannel(controller: controller)
      setupCaptureAudioChannel(controller: controller)
      setupCaptureCompressorChannel(controller: controller)
      setupNativeSpeechChannel(controller: controller)
      setupHardwareMonitorChannel(controller: controller)
      quickCaptureWidgetChannelHandler.attach(to: controller)
      setupNativeQuickCaptureChannel(controller: controller)
      setupHealthAndVoiceMemoChannels(controller: controller)
      setupFileProtectionChannel(controller: controller)
      liveAudioLifecycleBridge.attach(to: controller)
    }
    WatchSessionBridge.shared.activate()
    return didFinish
  }

  private func setupLegacyCleanupChannel(controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: legacyCleanupChannelName,
      binaryMessenger: controller.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "clearLegacyWidgetSharedData":
        LegacyWidgetSharedDataCleanup.clearIfPresent()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func setupCaptureCompressorChannel(controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: captureCompressorChannelName,
      binaryMessenger: controller.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      self?.captureAudioCompressorHandler.handle(call, result: result)
    }
  }

  private func setupNativeSpeechChannel(controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: nativeSpeechChannelName,
      binaryMessenger: controller.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      self?.nativeSpeechTranscriptionHandler.handle(call, result: result)
    }
    let draftEvents = FlutterEventChannel(
      name: "archive_me/native_speech_transcription_draft",
      binaryMessenger: controller.binaryMessenger
    )
    draftEvents.setStreamHandler(IosLiveDraftSpeech.shared)
  }

  private func setupHardwareMonitorChannel(controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: hardwareMonitorChannelName,
      binaryMessenger: controller.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      self?.hardwareMonitorChannelHandler.handle(call, result: result)
    }
  }

  private func setupCaptureAudioChannel(controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: captureAudioChannelName,
      binaryMessenger: controller.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      self?.captureAudioSessionHandler.handle(call, result: result)
    }
  }

  private func setupWatchChannel(controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: watchChannelName,
      binaryMessenger: controller.binaryMessenger
    )
    WatchSessionBridge.shared.setOnCaptureReceived { payload in
      channel.invokeMethod("watchAudioReceived", arguments: payload)
    }
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "consumePendingWatchAudio":
        result(WatchSessionBridge.shared.consumePendingWatchAudio())
      case "consumePendingWatchAudioPaths":
        let paths = WatchSessionBridge.shared.consumePendingWatchAudio().compactMap {
          $0["path"] as? String
        }
        result(paths)
      case "isWatchSessionSupported":
        result(WCSession.isSupported())
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func setupNativeQuickCaptureChannel(controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "archive_me/native_quick_capture",
      binaryMessenger: controller.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "liveActivityStart":
        RecordingLiveActivityController.start()
        result(nil)
      case "liveActivityStop":
        RecordingLiveActivityController.stop()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    let ext = url.pathExtension.lowercased()
    if url.isFileURL, ["m4a", "mp3", "wav", "ogg"].contains(ext) {
      VoiceMemoInbox.shared.remember(url)
    }
    return super.application(app, open: url, options: options)
  }

  private func setupFileProtectionChannel(controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "com.thoughtprint.app/file_protection",
      binaryMessenger: controller.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "setFileProtectionComplete" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let path = call.arguments as? String, !path.isEmpty else {
        result(
          FlutterError(
            code: "bad_path",
            message: "A file path is required.",
            details: nil
          )
        )
        return
      }
      do {
        try FileManager.default.setAttributes(
          [.protectionKey: FileProtectionType.complete],
          ofItemAtPath: path
        )
        result(nil)
      } catch {
        result(
          FlutterError(
            code: "file_protection",
            message: error.localizedDescription,
            details: nil
          )
        )
      }
    }
  }

  private func setupHealthAndVoiceMemoChannels(controller: FlutterViewController) {
    let health = FlutterMethodChannel(
      name: "archive_me/health_state_of_mind",
      binaryMessenger: controller.binaryMessenger
    )
    let healthHandler = HealthStateOfMindHandler()
    health.setMethodCallHandler { call, result in
      healthHandler.handle(call, result: result)
    }
    let imports = FlutterMethodChannel(
      name: "archive_me/voice_memo_import",
      binaryMessenger: controller.binaryMessenger
    )
    imports.setMethodCallHandler { call, result in
      switch call.method {
      case "takePending":
        result(VoiceMemoInbox.shared.take())
      case "takeQueue":
        result(VoiceMemoInbox.shared.takeQueue())
      case "creationDate":
        result(VoiceMemoInbox.creationDate(call.arguments))
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    let keychain = FlutterMethodChannel(
      name: "archive_me/account_keychain",
      binaryMessenger: controller.binaryMessenger
    )
    keychain.setMethodCallHandler { call, result in
      guard call.method == "save",
            let args = call.arguments as? [String: Any],
            let encoded = args["key"] as? String,
            let data = Data(base64Encoded: encoded) else {
        result(FlutterMethodNotImplemented)
        return
      }
      let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: "thoughtprint.account-key",
        kSecAttrService as String: "thoughtprint.sync",
        kSecAttrSynchronizable as String: kCFBooleanTrue as Any,
      ]
      SecItemDelete(query as CFDictionary)
      var add = query
      add[kSecValueData as String] = data
      add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
      let status = SecItemAdd(add as CFDictionary, nil)
      result(status == errSecSuccess)
    }
  }
}

final class VoiceMemoInbox {
  static let shared = VoiceMemoInbox()
  private var queued: [[String: String]] = []

  func remember(_ url: URL) {
    let accessed = url.startAccessingSecurityScopedResource()
    defer {
      if accessed { url.stopAccessingSecurityScopedResource() }
    }
    guard let row = Self.store(url) else { return }
    queued.append(row)
  }

  func take() -> [String: String]? {
    if queued.isEmpty { queued = Self.readQueue() }
    guard !queued.isEmpty else { return nil }
    return queued.removeFirst()
  }

  func takeQueue() -> [[String: String]] {
    let rows = queued + Self.readQueue()
    queued = []
    return rows
  }

  /// Recording date inside the m4a (AVAsset commonMetadata, then creationDate),
  /// otherwise the file modification date.
  static func creationDate(_ arguments: Any?) -> String? {
    guard let args = arguments as? [String: Any],
          let path = args["path"] as? String else { return nil }
    let url = URL(fileURLWithPath: path)
    guard let date = recordingDate(of: url) else { return nil }
    return ISO8601DateFormatter().string(from: date)
  }

  static func recordingDate(of url: URL) -> Date? {
    let asset = AVURLAsset(url: url)
    for item in asset.commonMetadata {
      if item.commonKey == .commonKeyCreationDate {
        if let date = item.dateValue { return date }
        if let text = item.stringValue,
           let date = ISO8601DateFormatter().date(from: text) {
          return date
        }
      }
    }
    if let created = asset.creationDate?.dateValue { return created }
    return (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
      .contentModificationDate
  }

  private static func store(_ url: URL) -> [String: String]? {
    guard let base = FileManager.default.urls(
      for: .applicationSupportDirectory,
      in: .userDomainMask
    ).first else { return nil }
    let folder = base.appendingPathComponent("voice-memos", isDirectory: true)
    let ext = url.pathExtension.lowercased()
    guard ["m4a", "mp3", "wav", "ogg"].contains(ext) else { return nil }
    do {
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
      let dest = folder.appendingPathComponent("\(UUID().uuidString).\(ext)")
      if FileManager.default.fileExists(atPath: dest.path) {
        try FileManager.default.removeItem(at: dest)
      }
      try FileManager.default.copyItem(at: url, to: dest)
      let recorded = recordingDate(of: url) ?? recordingDate(of: dest)
      if let recorded {
        var stamped = dest
        var values = URLResourceValues()
        values.creationDate = recorded
        values.contentModificationDate = recorded
        try? stamped.setResourceValues(values)
      }
      var row = ["path": dest.path, "name": url.deletingPathExtension().lastPathComponent]
      if let recorded {
        row["createdAt"] = ISO8601DateFormatter().string(from: recorded)
      }
      return row
    } catch {
      return nil
    }
  }

  private static func readQueue() -> [[String: String]] {
    guard let root = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: "group.com.voicememory.mobile"
    ) else { return [] }
    let folder = root.appendingPathComponent("voice-memo-inbox", isDirectory: true)
    let queueFile = folder.appendingPathComponent("queue.json")
    let pendingFile = folder.appendingPathComponent("pending.json")
    if let data = try? Data(contentsOf: queueFile),
       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
       let items = json["items"] as? [[String: Any]] {
      try? FileManager.default.removeItem(at: queueFile)
      try? FileManager.default.removeItem(at: pendingFile)
      return items.compactMap(row(from:))
    }
    guard let data = try? Data(contentsOf: pendingFile),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let row = row(from: json) else { return [] }
    try? FileManager.default.removeItem(at: pendingFile)
    return [row]
  }

  private static func row(from json: [String: Any]) -> [String: String]? {
    guard let path = json["path"] as? String else { return nil }
    var row = ["path": path]
    if let createdAt = json["createdAt"] as? String, !createdAt.isEmpty {
      row["createdAt"] = createdAt
    }
    if let name = json["name"] as? String, !name.isEmpty {
      row["name"] = name
    }
    return row
  }
}

final class HealthStateOfMindHandler {
  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard #available(iOS 18.0, *) else {
      result(nil)
      return
    }
    switch call.method {
    case "requestAuthorization":
      let args = call.arguments as? [String: Any]
      let share = args?["share"] as? Bool ?? true
      let update = args?["update"] as? Bool ?? false
      Task {
        do {
          try await Self.authorize(share: share, update: update)
          result(true)
        } catch {
          result(false)
        }
      }
    case "stateOfMind":
      Task {
        do {
          result(try await Self.label(arguments: call.arguments))
        } catch {
          result(FlutterError(
            code: "health_unavailable",
            message: "state_of_mind_unavailable",
            details: nil
          ))
        }
      }
    case "writeStateOfMind":
      let mood = (call.arguments as? [String: Any])?["mood"] as? String ?? ""
      Task {
        do {
          let uuid = try await Self.write(mood: mood)
          result(uuid)
        } catch {
          result(nil)
        }
      }
    case "deleteStateOfMind":
      let uuid = (call.arguments as? [String: Any])?["uuid"] as? String ?? ""
      Task {
        do {
          try await Self.delete(uuid: uuid)
          result(true)
        } catch {
          result(false)
        }
      }
    case "authorizationStatus":
      Task {
        result(Self.authorization())
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  @available(iOS 18.0, *)
  private static func authorize(share: Bool, update: Bool) async throws {
    let store = HKHealthStore()
    guard HKHealthStore.isHealthDataAvailable() else { return }
    let type = HKObjectType.stateOfMindType()
    var reading = Set<HKObjectType>()
    var writing = Set<HKSampleType>()
    if share { reading.insert(type) }
    if update { writing.insert(type) }
    try await store.requestAuthorization(toShare: writing, read: reading)
  }

  @available(iOS 18.0, *)
  private static func authorization() -> String {
    guard HKHealthStore.isHealthDataAvailable() else { return "denied" }
    let status = HKHealthStore().authorizationStatus(for: HKObjectType.stateOfMindType())
    switch status {
    case .sharingAuthorized:
      return "authorized"
    case .sharingDenied:
      return "denied"
    default:
      return "notDetermined"
    }
  }

  @available(iOS 18.0, *)
  private static func write(mood: String) async throws -> String {
    let store = HKHealthStore()
    guard HKHealthStore.isHealthDataAvailable() else { return "" }
    let sample = Self.sample(mood: mood)
    try await store.save(sample)
    return sample.uuid.uuidString
  }

  @available(iOS 18.0, *)
  private static func delete(uuid: String) async throws {
    guard let id = UUID(uuidString: uuid) else { return }
    let store = HKHealthStore()
    let type = HKObjectType.stateOfMindType()
    let predicate = HKQuery.predicateForObject(with: id)
    let samples: [HKSample] = try await withCheckedThrowingContinuation { continuation in
      let query = HKSampleQuery(
        sampleType: type,
        predicate: predicate,
        limit: 1,
        sortDescriptors: nil
      ) { _, found, error in
        if let error {
          continuation.resume(throwing: error)
          return
        }
        continuation.resume(returning: (found as? [HKSample]) ?? [])
      }
      store.execute(query)
    }
    if samples.isEmpty { return }
    try await store.delete(samples)
  }

  @available(iOS 18.0, *)
  private static func sample(mood: String) -> HKStateOfMind {
    let key = mood.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let label: HKStateOfMind.Label
    let valence: Double
    switch key {
    case "calm", "grounded":
      label = .calm
      valence = 0.4
    case "anxious":
      label = .anxious
      valence = -0.5
    case "energetic":
      label = .excited
      valence = 0.7
    case "reflective":
      label = .peaceful
      valence = 0.3
    case "low":
      label = .sad
      valence = -0.6
    default:
      label = .content
      valence = 0
    }
    return HKStateOfMind(
      date: Date(),
      kind: .momentaryEmotion,
      valence: valence,
      labels: [label],
      associations: []
    )
  }

  @available(iOS 18.0, *)
  private static func label(arguments: Any?) async throws -> String? {
    let store = HKHealthStore()
    guard HKHealthStore.isHealthDataAvailable() else { return nil }
    let type = HKObjectType.stateOfMindType()
    let raw = (arguments as? [String: Any])?["date"] as? String
    let day = ISO8601DateFormatter().date(from: raw ?? "") ?? Date()
    let start = Calendar.current.startOfDay(for: day)
    let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? day
    let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
    let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
    return try await withCheckedThrowingContinuation { continuation in
      let query = HKSampleQuery(
        sampleType: type,
        predicate: predicate,
        limit: 1,
        sortDescriptors: [sort]
      ) { _, samples, error in
        if let error {
          continuation.resume(throwing: error)
          return
        }
        guard let mood = samples?.first as? HKStateOfMind else {
          continuation.resume(returning: nil)
          return
        }
        let described = mood.labels.first.map { String(describing: $0) } ?? ""
        let name = described.split(separator: ".").last.map(String.init) ?? ""
        if !name.isEmpty {
          continuation.resume(returning: name)
          return
        }
        if mood.valence > 0.2 {
          continuation.resume(returning: "pleasant")
        } else if mood.valence < -0.2 {
          continuation.resume(returning: "unpleasant")
        } else {
          continuation.resume(returning: "neutral")
        }
      }
      store.execute(query)
    }
  }
}
