import Foundation

/// One-time cleanup for archived Today Check widget App Group payload keys.
enum LegacyWidgetSharedDataCleanup {
  private static let legacyAppGroupId = "group.com.voicememory.mobile"
  private static let legacyKeys = [
    "title",
    "body",
    "checkQuestion",
    "primaryActionLabel",
    "route",
    "type",
    "updatedAt",
  ]

  static func clearIfPresent() {
    guard let defaults = UserDefaults(suiteName: legacyAppGroupId) else {
      return
    }
    for key in legacyKeys {
      defaults.removeObject(forKey: key)
    }
    QuickCaptureWidgetStorage.clearSharedQueueIfPresent()
    defaults.synchronize()
  }
}
