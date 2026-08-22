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
}
