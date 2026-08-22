import Foundation
import WidgetKit

/// App Group queue for home-screen quick capture widgets and shortcuts.
enum QuickCaptureWidgetStorage {
  static let appGroupId = "group.com.voicememory.mobile"

  static let sharedQueueKey = "quick_capture_shared_queue_v1"
  static let pendingRouteKey = "quick_capture_widget_pending_route"

  static let snapshotTitleKey = "quick_capture_widget_title"
  static let snapshotCtaKey = "quick_capture_widget_cta"
  static let snapshotRouteKey = "quick_capture_widget_route"
  static let snapshotPendingCountKey = "quick_capture_widget_pending_count"

  static func isAppGroupAvailable() -> Bool {
    sharedDefaults() != nil
  }

  static func readPendingCaptures() -> [[String: Any]] {
    guard let defaults = sharedDefaults() else { return [] }
    guard let raw = defaults.array(forKey: sharedQueueKey) else { return [] }
    return raw.compactMap { item in
      guard let map = item as? [String: Any] else { return nil }
      return map
    }
  }

  static func acknowledgeCaptureIds(_ captureIds: [String]) {
    guard !captureIds.isEmpty, let defaults = sharedDefaults() else { return }
    let ids = Set(captureIds)
    let remaining = readPendingCaptures().filter { capture in
      let captureId = String(describing: capture["captureId"] ?? capture["id"] ?? "")
      return !ids.contains(captureId)
    }
    defaults.set(remaining, forKey: sharedQueueKey)
    defaults.synchronize()
  }

  static func updateWidgetSnapshot(_ payload: [String: Any]) {
    guard let defaults = sharedDefaults() else { return }
    defaults.set(String(describing: payload["title"] ?? ""), forKey: snapshotTitleKey)
    defaults.set(String(describing: payload["cta"] ?? ""), forKey: snapshotCtaKey)
    defaults.set(String(describing: payload["route"] ?? "/quick-capture"), forKey: snapshotRouteKey)
    defaults.set(String(describing: payload["pendingCount"] ?? "0"), forKey: snapshotPendingCountKey)
    defaults.synchronize()
    reloadWidgets()
  }

  static func clearWidgetSnapshot() {
    guard let defaults = sharedDefaults() else { return }
    for key in [
      snapshotTitleKey,
      snapshotCtaKey,
      snapshotRouteKey,
      snapshotPendingCountKey,
    ] {
      defaults.removeObject(forKey: key)
    }
    defaults.synchronize()
    reloadWidgets()
  }

  static func consumePendingLaunchRoute() -> String {
    guard let defaults = sharedDefaults() else { return "" }
    let route = defaults.string(forKey: pendingRouteKey)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if !route.isEmpty {
      defaults.removeObject(forKey: pendingRouteKey)
      defaults.synchronize()
    }
    return route
  }

  static func clearSharedQueueIfPresent() {
    guard let defaults = sharedDefaults() else { return }
    defaults.removeObject(forKey: sharedQueueKey)
    defaults.removeObject(forKey: pendingRouteKey)
    for key in [
      snapshotTitleKey,
      snapshotCtaKey,
      snapshotRouteKey,
      snapshotPendingCountKey,
    ] {
      defaults.removeObject(forKey: key)
    }
    defaults.synchronize()
  }

  private static func sharedDefaults() -> UserDefaults? {
    UserDefaults(suiteName: appGroupId)
  }

  private static func reloadWidgets() {
    if #available(iOS 14.0, macOS 11.0, *) {
      WidgetCenter.shared.reloadAllTimelines()
    }
  }
}
