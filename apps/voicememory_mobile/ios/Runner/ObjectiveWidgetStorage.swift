import Foundation
import WidgetKit

/// Encrypted App Group payload for the legacy current-objective widget.
enum ObjectiveWidgetStorage {
  static let appGroupId = "group.com.voicememory.mobile"
  private static let category = "objective-widget"
  private static let identifier = "current"

  static func save(payload: [String: Any]) {
    do {
      try SecureAppGroupStore.shared.writeJSONObject(
        payload,
        category: category,
        identifier: identifier
      )
      reloadWidgets()
    } catch {
      // Widget state is optional; never fall back to plaintext shared defaults.
    }
  }

  static func clear() {
    do {
      try SecureAppGroupStore.shared.remove(category: category, identifier: identifier)
      reloadWidgets()
    } catch {
      // Nothing actionable for an optional OS surface.
    }
  }

  static func isAppGroupAvailable() -> Bool {
    FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: appGroupId
    ) != nil
  }

  static func route(from url: URL) -> String? {
    guard url.scheme == "archiveme" || url.scheme == "voicememory" else {
      return nil
    }
    var path = url.host ?? ""
    if path.isEmpty {
      path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
    if path.isEmpty {
      return "/record"
    }
    return path.hasPrefix("/") ? path : "/\(path)"
  }

  static func launchURL(for route: String) -> URL {
    let trimmed = route.trimmingCharacters(in: .whitespacesAndNewlines)
    let path = trimmed.hasPrefix("/") ? String(trimmed.dropFirst()) : trimmed
    let safePath = path.isEmpty ? "record" : path
    return URL(string: "archiveme://\(safePath)")
      ?? URL(string: "archiveme://record")!
  }

  private static func reloadWidgets() {
    if #available(iOS 14.0, *) {
      WidgetCenter.shared.reloadAllTimelines()
    }
  }
}
