import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let captureAudioChannelName = "archive_me/ios_capture_audio"
  private let nativeRecorderChannelName = "archive_me/native_audio_recorder"
  private let sensitiveTemporaryAudioChannelName =
    "archive_me/sensitive_temporary_audio_store"
  private let captureAudioSessionHandler = IosCaptureAudioSessionHandler()
  private let nativeVoiceRecorderHandler = IosNativeVoiceRecorderHandler()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    let didFinish = super.application(
      application,
      didFinishLaunchingWithOptions: launchOptions
    )
    if let controller = window?.rootViewController as? FlutterViewController {
      setupCaptureAudioChannel(controller: controller)
      setupNativeRecorderChannel(controller: controller)
      setupSensitiveTemporaryAudioChannel(controller: controller)
    }
    return didFinish
  }

  override func applicationDidEnterBackground(_ application: UIApplication) {
    nativeVoiceRecorderHandler.dispose()
    super.applicationDidEnterBackground(application)
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

  private func setupNativeRecorderChannel(controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: nativeRecorderChannelName,
      binaryMessenger: controller.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      self?.nativeVoiceRecorderHandler.handle(call, result: result)
    }
  }

  private func setupSensitiveTemporaryAudioChannel(
    controller: FlutterViewController
  ) {
    let channel = FlutterMethodChannel(
      name: sensitiveTemporaryAudioChannelName,
      binaryMessenger: controller.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "protectedDirectory" else {
        result(FlutterMethodNotImplemented)
        return
      }
      do {
        let support = try FileManager.default.url(
          for: .applicationSupportDirectory,
          in: .userDomainMask,
          appropriateFor: nil,
          create: true
        )
        var directory = support.appendingPathComponent(
          "SensitiveTemporaryAudio",
          isDirectory: true
        )
        try FileManager.default.createDirectory(
          at: directory,
          withIntermediateDirectories: true,
          attributes: [.protectionKey: FileProtectionType.completeUnlessOpen]
        )
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try directory.setResourceValues(values)
        try FileManager.default.setAttributes(
          [.protectionKey: FileProtectionType.completeUnlessOpen],
          ofItemAtPath: directory.path
        )
        result(directory.path)
      } catch {
        result(
          FlutterError(
            code: "storage_unavailable",
            message: "Protected audio storage unavailable.",
            details: nil
          )
        )
      }
    }
  }
}
