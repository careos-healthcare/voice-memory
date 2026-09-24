import Flutter
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
  private let hardwareSnapshotChannelName = "com.archiveme/hardware_monitor"
  private let shareImportChannelName = "com.archiveme/share_import"
  private let quickActionsChannelName = "com.archiveme/quick_actions"
  private let captureAudioSessionHandler = IosCaptureAudioSessionHandler()
  private let captureAudioCompressorHandler = IosCaptureAudioCompressorHandler()
  private let nativeSpeechTranscriptionHandler = IosNativeSpeechTranscriptionHandler()
  private let hardwareMonitorChannelHandler = HardwareMonitorChannelHandler()
  private let quickCaptureWidgetChannelHandler = QuickCaptureWidgetChannelHandler()
  private var quickActionsChannel: FlutterMethodChannel?
  private var pendingQuickAction: String?
  private var shareImportChannel: FlutterMethodChannel?
  private var pendingImportPath: String?
  private var shareImportReady = false

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
    noteShortcutLaunch(launchOptions)

    let didFinish = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    if let controller = window?.rootViewController as? FlutterViewController {
      setupLegacyCleanupChannel(controller: controller)
      setupWatchChannel(controller: controller)
      WatchSyncHandler.shared.attach(to: controller)
      setupCaptureAudioChannel(controller: controller)
      setupCaptureCompressorChannel(controller: controller)
      setupPostTranscriptionCompressorChannel(controller: controller)
      setupShareImportChannel(controller: controller)
      setupNativeSpeechChannel(controller: controller)
      setupHardwareMonitorChannel(controller: controller)
      quickCaptureWidgetChannelHandler.attach(to: controller)
      LiveAudioLifecycleBridge.shared.attach(to: controller)
      ZeroStateRecorderChannel.register(messenger: controller.binaryMessenger)
      WhisperKitChannelHandler.register(messenger: controller.binaryMessenger)
      setupQuickActionsChannel(controller: controller)
    }
    if let url = launchOptions?[.url] as? URL {
      rememberRecordLink(url)
      rememberSharedFile(url)
    }
    WatchSessionBridge.shared.activate()
    return didFinish
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    let handledRecordLink = rememberRecordLink(url)
    let handledImport = rememberSharedFile(url)
    let handledBySuper = super.application(app, open: url, options: options)
    return handledRecordLink || handledImport || handledBySuper
  }

  override func application(
    _ application: UIApplication,
    performActionFor shortcutItem: UIApplicationShortcutItem,
    completionHandler: @escaping (Bool) -> Void
  ) {
    let handled = handleShortcut(shortcutItem)
    completionHandler(handled)
  }

  /// A home-screen shortcut or record URL starts the microphone before Flutter
  /// finishes building the shell.
  private func noteShortcutLaunch(_ launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
    if let item = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem {
      handleShortcut(item)
    }
    if let url = launchOptions?[.url] as? URL, isRecordURL(url) {
      ShortcutAudioBuffer.noteLaunch()
      ShortcutAudioBuffer.begin()
    }
  }

  @discardableResult
  private func handleShortcut(_ item: UIApplicationShortcutItem) -> Bool {
    guard item.type == "new_voice_entry" else { return false }
    ShortcutAudioBuffer.noteLaunch()
    ShortcutAudioBuffer.begin()
    pendingQuickAction = "start_recording"
    quickActionsChannel?.invokeMethod("onQuickAction", arguments: "start_recording")
    return true
  }

  private func isRecordURL(_ url: URL) -> Bool {
    guard url.scheme?.lowercased() == "archiveme" else { return false }
    if url.host?.lowercased() == "record" { return true }
    return url.host?.lowercased() == "action" && url.path.lowercased() == "/record"
  }

  /// `archiveme://` is declared in Info.plist (`CFBundleURLSchemes`).
  /// `archiveme://action/record` becomes the `start_recording` quick action.
  /// `archiveme://action/transcript` opens the recording transcript.
  @discardableResult
  private func rememberRecordLink(_ url: URL) -> Bool {
    guard url.scheme?.lowercased() == "archiveme" else { return false }
    if url.host?.lowercased() == "record" {
      ShortcutAudioBuffer.noteLaunch()
      ShortcutAudioBuffer.begin()
      pendingQuickAction = "start_recording"
      quickActionsChannel?.invokeMethod("onQuickAction", arguments: "start_recording")
      return true
    }
    guard url.host?.lowercased() == "action" else { return false }
    let action: String
    switch url.path.lowercased() {
    case "/record":
      action = "start_recording"
      ShortcutAudioBuffer.noteLaunch()
      ShortcutAudioBuffer.begin()
    case "/transcript":
      action = "open_transcript"
    default:
      return false
    }
    pendingQuickAction = action
    quickActionsChannel?.invokeMethod("onQuickAction", arguments: action)
    return true
  }

  private func setupQuickActionsChannel(controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: quickActionsChannelName,
      binaryMessenger: controller.binaryMessenger
    )
    quickActionsChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "consumePendingQuickAction" else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(self?.pendingQuickAction)
      self?.pendingQuickAction = nil
    }
    if pendingQuickAction != nil {
      channel.invokeMethod("onQuickAction", arguments: pendingQuickAction)
    }
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

  private func setupPostTranscriptionCompressorChannel(controller: FlutterViewController) {
    CaptureAudioCompressorChannel.register(
      messenger: controller.binaryMessenger,
      handler: captureAudioCompressorHandler
    )
  }

  private func setupShareImportChannel(controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: shareImportChannelName,
      binaryMessenger: controller.binaryMessenger
    )
    shareImportChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "consumePendingImport" else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.shareImportReady = true
      let first = self?.pendingImportPath
      self?.pendingImportPath = nil
      result(first)
      let rest = UserDefaults.standard.stringArray(forKey: "archiveme.pendingImports.local") ?? []
      UserDefaults.standard.removeObject(forKey: "archiveme.pendingImports.local")
      rest.forEach { path in
        self?.shareImportChannel?.invokeMethod("shareImportReady", arguments: path)
      }
    }
  }

  @discardableResult
  private func rememberSharedFile(_ url: URL) -> Bool {
    let path: String?
    if url.isFileURL {
      path = copyImportedFile(url)
    } else if url.scheme?.lowercased() == "archiveme", url.host?.lowercased() == "import" {
      path = URLComponents(url: url, resolvingAgainstBaseURL: false)?
        .queryItems?
        .first(where: { $0.name == "path" })?
        .value
    } else {
      return false
    }
    guard let stored = path, !stored.isEmpty else { return false }
    var paths = queuedGroupImports()
    if !paths.contains(stored) {
      paths.insert(stored, at: 0)
    }
    deliverImportPaths(paths)
    return true
  }

  private func queuedGroupImports() -> [String] {
    let defaults = UserDefaults(suiteName: "group.com.voicememory.mobile")
    let paths = defaults?.stringArray(forKey: "archiveme.pendingImports") ?? []
    defaults?.removeObject(forKey: "archiveme.pendingImports")
    return paths.filter { FileManager.default.fileExists(atPath: $0) }
  }

  private func deliverImportPaths(_ paths: [String]) {
    guard let first = paths.first else { return }
    if shareImportReady {
      paths.forEach { shareImportChannel?.invokeMethod("shareImportReady", arguments: $0) }
      return
    }
    pendingImportPath = first
    let rest = Array(paths.dropFirst())
    if rest.isEmpty {
      UserDefaults.standard.removeObject(forKey: "archiveme.pendingImports.local")
    } else {
      UserDefaults.standard.set(rest, forKey: "archiveme.pendingImports.local")
    }
  }

  private func copyImportedFile(_ url: URL) -> String? {
    let accessing = url.startAccessingSecurityScopedResource()
    defer {
      if accessing { url.stopAccessingSecurityScopedResource() }
    }
    let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    guard let documents else { return nil }
    let directory = documents.appendingPathComponent("imports", isDirectory: true)
    do {
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      let dest = directory.appendingPathComponent(url.lastPathComponent)
      if FileManager.default.fileExists(atPath: dest.path) {
        try FileManager.default.removeItem(at: dest)
      }
      try FileManager.default.copyItem(at: url, to: dest)
      return dest.path
    } catch {
      return nil
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
  }

  private func setupHardwareMonitorChannel(controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: hardwareMonitorChannelName,
      binaryMessenger: controller.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      self?.hardwareMonitorChannelHandler.handle(call, result: result)
    }
    let snapshotChannel = FlutterMethodChannel(
      name: hardwareSnapshotChannelName,
      binaryMessenger: controller.binaryMessenger
    )
    snapshotChannel.setMethodCallHandler { [weak self] call, result in
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
}
