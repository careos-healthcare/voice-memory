import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let widgetChannelName = "archive_me/current_objective_widget"
  private let captureAudioChannelName = "archive_me/ios_capture_audio"
  private let nativeRecorderChannelName = "archive_me/ios_native_recorder"
  private var pendingWidgetRoute: String?
  private let captureAudioSessionHandler = IosCaptureAudioSessionHandler()
  private let nativeVoiceRecorderHandler = IosNativeVoiceRecorderHandler()
  private let liveAudioLifecycleBridge = LiveAudioLifecycleBridge()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    // Required by flutter_local_notifications to present/handle alerts on iOS 10+.
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }

    if let url = launchOptions?[.url] as? URL {
      captureWidgetRoute(from: url)
    }

    let didFinish = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    if let controller = window?.rootViewController as? FlutterViewController {
      setupWidgetChannel(controller: controller)
      setupCaptureAudioChannel(controller: controller)
      setupNativeRecorderChannel(controller: controller)
      liveAudioLifecycleBridge.attach(to: controller)
    }
    return didFinish
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if captureWidgetRoute(from: url) {
      return true
    }
    return super.application(app, open: url, options: options)
  }

  @discardableResult
  private func captureWidgetRoute(from url: URL) -> Bool {
    guard let route = ObjectiveWidgetStorage.route(from: url) else {
      return false
    }
    pendingWidgetRoute = route
    return true
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

  private func setupCaptureAudioChannel(controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: captureAudioChannelName,
      binaryMessenger: controller.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      self?.captureAudioSessionHandler.handle(call, result: result)
    }
  }

  private func setupWidgetChannel(controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: widgetChannelName,
      binaryMessenger: controller.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handleWidgetMethod(call: call, result: result)
    }
  }

  private func handleWidgetMethod(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isCurrentObjectiveWidgetAvailable":
      result(true)
    case "updateCurrentObjectiveWidget":
      guard let payload = call.arguments as? [String: Any] else {
        result(
          FlutterError(
            code: "invalid_args",
            message: "Expected payload map",
            details: nil
          )
        )
        return
      }
      ObjectiveWidgetStorage.save(payload: payload)
      result(nil)
    case "clearCurrentObjectiveWidget":
      ObjectiveWidgetStorage.clear()
      result(nil)
    case "consumePendingWidgetRoute":
      let route = pendingWidgetRoute?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      pendingWidgetRoute = nil
      result(route)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
