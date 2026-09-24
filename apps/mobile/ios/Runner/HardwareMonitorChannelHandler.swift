import Flutter
import UIKit

final class HardwareMonitorChannelHandler {
  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    HardwareMonitorHandler.handle(call, result: result)
  }
}
