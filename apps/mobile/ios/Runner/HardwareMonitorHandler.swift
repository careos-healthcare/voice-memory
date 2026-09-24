import Flutter
import UIKit

/// Battery and thermal snapshot for on-device transcription and summaries.
enum HardwareMonitorHandler {
  static func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getThermalStatus":
      result(thermalStatus())
    case "getHardwareSnapshot":
      result(snapshot())
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  static func snapshot() -> [String: Any] {
    let device = UIDevice.current
    device.isBatteryMonitoringEnabled = true
    let level = device.batteryLevel
    let percent = level < 0 ? -1 : Int((level * 100).rounded())
    let charging = device.batteryState == .charging || device.batteryState == .full
    return [
      "batteryPercent": percent,
      "isCharging": charging,
      "thermalStatus": thermalStatus(),
    ]
  }

  static func thermalStatus() -> String {
    switch ProcessInfo.processInfo.thermalState {
    case .nominal:
      return "nominal"
    case .fair:
      return "fair"
    case .serious:
      return "serious"
    case .critical:
      return "critical"
    @unknown default:
      return "unknown"
    }
  }
}
