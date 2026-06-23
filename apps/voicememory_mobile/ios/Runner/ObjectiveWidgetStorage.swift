import Foundation
import WidgetKit

/// Shared App Group payload for Today\u{2019}s Check home-screen widgets.
enum ObjectiveWidgetStorage {
  static let appGroupId = "group.com.voicememory.mobile"

  static let keyTitle = "title"
  static let keyBody = "body"
  static let keyCheckQuestion = "checkQuestion"
  static let keyPrimaryActionLabel = "primaryActionLabel"
  static let keyRoute = "route"
  static let keyType = "type"
  static let keyUpdatedAt = "updatedAt"

  static func save(payload: [String: Any]) {
    guard let defaults = sharedDefaults() else { return }
    defaults.set(String(describing: payload[keyTitle] ?? ""), forKey: keyTitle)
    defaults.set(String(describing: payload[keyBody] ?? ""), forKey: keyBody)
    defaults.set(String(describing: payload[keyCheckQuestion] ?? ""), forKey: keyCheckQuestion)
    defaults.set(
      String(describing: payload[keyPrimaryActionLabel] ?? ""),
      forKey: keyPrimaryActionLabel
    )
    defaults.set(String(describing: payload[keyRoute] ?? "/record"), forKey: keyRoute)
    defaults.set(String(describing: payload[keyType] ?? ""), forKey: keyType)
    defaults.set(String(describing: payload[keyUpdatedAt] ?? ""), forKey: keyUpdatedAt)
    defaults.synchronize()
    reloadWidgets()
  }

  static func clear() {
    guard let defaults = sharedDefaults() else { return }
    for key in [
      keyTitle,
      keyBody,
      keyCheckQuestion,
      keyPrimaryActionLabel,
      keyRoute,
      keyType,
      keyUpdatedAt,
    ] {
      defaults.removeObject(forKey: key)
    }
    defaults.synchronize()
    reloadWidgets()
  }

  static func isAppGroupAvailable() -> Bool {
    sharedDefaults() != nil
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

  private static func sharedDefaults() -> UserDefaults? {
    UserDefaults(suiteName: appGroupId)
  }

  private static func reloadWidgets() {
    if #available(iOS 14.0, *) {
      WidgetCenter.shared.reloadAllTimelines()
    }
  }
}
