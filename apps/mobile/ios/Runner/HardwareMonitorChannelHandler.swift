import Flutter
import UIKit

final class HardwareMonitorChannelHandler {
  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getThermalStatus":
      result(Self.currentThermalStatus())
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private static func currentThermalStatus() -> String {
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
