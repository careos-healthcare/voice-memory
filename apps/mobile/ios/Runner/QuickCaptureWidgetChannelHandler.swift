import Flutter

/// Method channel bridge for `archive_me/quick_capture_widget`.
final class QuickCaptureWidgetChannelHandler {
  static let channelName = "archive_me/quick_capture_widget"

  func attach(to controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: Self.channelName,
      binaryMessenger: controller.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isQuickCaptureWidgetAvailable":
      result(QuickCaptureWidgetStorage.isAppGroupAvailable())
    case "readPendingQuickCaptures":
      result(QuickCaptureWidgetStorage.readPendingCaptures())
    case "acknowledgeQuickCaptures":
      guard let args = call.arguments as? [String: Any],
            let captureIds = args["captureIds"] as? [String] else {
        result(FlutterError(code: "invalid_args", message: "captureIds required", details: nil))
        return
      }
      QuickCaptureWidgetStorage.acknowledgeCaptureIds(captureIds)
      result(nil)
    case "updateQuickCaptureWidget":
      guard let payload = call.arguments as? [String: Any] else {
        result(FlutterError(code: "invalid_args", message: "payload required", details: nil))
        return
      }
      QuickCaptureWidgetStorage.updateWidgetSnapshot(payload)
      result(nil)
    case "clearQuickCaptureWidget":
      QuickCaptureWidgetStorage.clearWidgetSnapshot()
      result(nil)
    case "consumePendingQuickCaptureRoute":
      result(QuickCaptureWidgetStorage.consumePendingLaunchRoute())
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
