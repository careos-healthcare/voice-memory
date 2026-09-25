import Flutter
import HealthKit
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
    if url.isFileURL, url.pathExtension.lowercased() == "m4a" {
      VoiceMemoInbox.shared.remember(url)
    }
    return super.application(app, open: url, options: options)
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
      guard call.method == "takePending" else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(VoiceMemoInbox.shared.take())
    }
  }
}

final class VoiceMemoInbox {
  static let shared = VoiceMemoInbox()
  private var pending: [String: String]?

  func remember(_ url: URL) {
    let accessed = url.startAccessingSecurityScopedResource()
    defer {
      if accessed { url.stopAccessingSecurityScopedResource() }
    }
    let created = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date()
    let stored = Self.copyIntoAppSupport(url) ?? url
    pending = [
      "path": stored.path,
      "createdAt": ISO8601DateFormatter().string(from: created),
    ]
  }

  private static func copyIntoAppSupport(_ url: URL) -> URL? {
    guard let base = FileManager.default.urls(
      for: .applicationSupportDirectory,
      in: .userDomainMask
    ).first else { return nil }
    let folder = base.appendingPathComponent("voice-memos", isDirectory: true)
    do {
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
      let dest = folder.appendingPathComponent("\(UUID().uuidString).m4a")
      if FileManager.default.fileExists(atPath: dest.path) {
        try FileManager.default.removeItem(at: dest)
      }
      try FileManager.default.copyItem(at: url, to: dest)
      return dest
    } catch {
      return nil
    }
  }

  func take() -> [String: String]? {
    let value = pending
    pending = nil
    return value
  }
}

final class HealthStateOfMindHandler {
  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "stateOfMind" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard #available(iOS 18.0, *) else {
      result(nil)
      return
    }
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
  }

  @available(iOS 18.0, *)
  private static func label(arguments: Any?) async throws -> String? {
    let store = HKHealthStore()
    guard HKHealthStore.isHealthDataAvailable() else { return nil }
    let type = HKObjectType.stateOfMindType()
    try await store.requestAuthorization(toShare: [], read: [type])
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
