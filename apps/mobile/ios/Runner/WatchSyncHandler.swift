import Flutter
import Foundation
import WatchConnectivity

/// Copies a finished watch recording into the shared app group and tells Flutter.
final class WatchSyncHandler: NSObject {
  static let shared = WatchSyncHandler()
  static let channelName = "com.archiveme/watch_sync"
  static let appGroupId = "group.com.voicememory.mobile"
  static let readyMethod = "watchRecordingReady"
  static let consumePendingMethod = "consumePendingWatchRecording"

  private var channel: FlutterMethodChannel?
  private var pending: [[String: Any]] = []
  private var flutterReady = false

  private override init() {
    super.init()
  }

  func attach(to controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: Self.channelName,
      binaryMessenger: controller.binaryMessenger
    )
    self.channel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == Self.consumePendingMethod else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.flutterReady = true
      result(self?.pending ?? [])
      self?.pending.removeAll()
    }
  }

  /// Moves `file` into the app group and notifies Flutter that it can be transcribed.
  func receive(file: WCSessionFile) {
    guard let destination = copyIntoAppGroup(file) else { return }
    var payload: [String: Any] = [
      "path": destination.path,
      "filename": destination.lastPathComponent,
      "type": file.metadata?["type"] as? String ?? "watch_audio_capture",
    ]
    if let capturedAt = file.metadata?["capturedAt"] as? String {
      payload["capturedAt"] = capturedAt
    }
    if let duration = file.metadata?["durationSeconds"] as? Int {
      payload["durationSeconds"] = duration
    } else if let duration = file.metadata?["durationSeconds"] as? NSNumber {
      payload["durationSeconds"] = duration.intValue
    }
    if flutterReady, let channel {
      channel.invokeMethod(Self.readyMethod, arguments: payload)
    } else {
      pending.append(payload)
    }
  }

  private func copyIntoAppGroup(_ file: WCSessionFile) -> URL? {
    guard let container = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: Self.appGroupId
    ) else {
      return nil
    }
    let folder = container.appendingPathComponent("watch_recordings", isDirectory: true)
    do {
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
      let destination = folder.appendingPathComponent(file.fileURL.lastPathComponent)
      if FileManager.default.fileExists(atPath: destination.path) {
        try FileManager.default.removeItem(at: destination)
      }
      try FileManager.default.copyItem(at: file.fileURL, to: destination)
      return destination
    } catch {
      return nil
    }
  }
}
