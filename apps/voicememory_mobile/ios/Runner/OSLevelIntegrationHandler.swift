import Flutter
import Foundation
import WidgetKit

final class OSLevelIntegrationHandler {
  static let channelName = "archive_me/os_level_integration"

  private let store = SecureAppGroupStore.shared
  private let iso8601 = ISO8601DateFormatter()
  private let allowedShareKinds = Set(["text", "url", "image", "file"])
  private let maxPayloadBytes = 20 * 1024 * 1024
  private let maxBase64Characters = 28 * 1024 * 1024

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    do {
      switch call.method {
      case "sharedContainerPath":
        result(store.sharedContainerURL?.path)
      case "drainShareInbox":
        result(try drainShareInbox())
      case "acknowledgeShareInbox":
        guard
          let arguments = call.arguments as? [String: Any],
          let identifiers = arguments["ids"] as? [String]
        else {
          throw BridgeError.invalidArguments
        }
        try acknowledgeShareInbox(identifiers)
        result(nil)
      case "drainWidgetActions":
        result(try drainWidgetActions())
      case "extensionStatus":
        result(try extensionStatus())
      case "publishWidgetSnapshot":
        guard let snapshot = call.arguments as? [String: Any] else {
          throw BridgeError.invalidArguments
        }
        try publishWidgetSnapshot(snapshot)
        result(nil)
      case "reloadWidgets":
        WidgetCenter.shared.reloadAllTimelines()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    } catch {
      result(
        FlutterError(
          code: "os_integration_error",
          message: "The iOS OS integration request could not be completed.",
          details: String(describing: error)
        )
      )
    }
  }

  private func drainShareInbox() throws -> [[String: Any]] {
    let records = try store.readAllJSONObjects(category: "share-inbox")
    var converted: [[String: Any]] = []
    for record in records {
      guard let payload = strictSharePayload(record) else { continue }
      converted.append(payload)
    }
    return converted
  }

  private func acknowledgeShareInbox(_ identifiers: [String]) throws {
    guard identifiers.count <= 128 else { throw BridgeError.payloadTooLarge }
    let uniqueIdentifiers = Array(Set(identifiers))
    guard uniqueIdentifiers.allSatisfy({ UUID(uuidString: $0) != nil }) else {
      throw BridgeError.invalidArguments
    }
    try store.removeAll(category: "share-inbox", identifiers: uniqueIdentifiers)
  }

  private func drainWidgetActions() throws -> [[String: Any]] {
    let records = try store.readAllJSONObjects(category: "widget-action")
    var converted: [[String: Any]] = []
    for record in records {
      guard let action = strictWidgetAction(record.object) else { continue }
      do {
        try store.remove(category: "widget-action", identifier: record.identifier)
        converted.append(action)
      } catch {
        // Preserve for retry.
      }
    }
    return converted
  }

  private func extensionStatus() throws -> [String: Any] {
    let containerAvailable = store.sharedContainerURL != nil
    return [
      "shareExtensionAvailable": embeddedExtensionExists(named: "ShareExtension.appex"),
      "widgetExtensionAvailable": embeddedExtensionExists(named: "ArchiveMeWidgets.appex"),
      "sharedContainerAvailable": containerAvailable,
      "lockScreenWidgetsSupported": {
        if #available(iOS 16.0, *) { return true }
        return false
      }(),
      "pendingShareCount": containerAvailable
        ? (try store.recordCount(category: "share-inbox"))
        : 0,
    ]
  }

  private func publishWidgetSnapshot(_ snapshot: [String: Any]) throws {
    guard JSONSerialization.isValidJSONObject(snapshot) else {
      throw BridgeError.invalidArguments
    }
    let encoded = try JSONSerialization.data(withJSONObject: snapshot)
    guard encoded.count <= 1_048_576 else {
      throw BridgeError.payloadTooLarge
    }
    try store.writeJSONObject(snapshot, category: "widget", identifier: "current")
    WidgetCenter.shared.reloadAllTimelines()
  }

  private func strictSharePayload(
    _ record: SecureAppGroupStore.Record
  ) -> [String: Any]? {
    let object = record.object
    guard
      let id = boundedString(object["id"], maximum: 128),
      id == record.identifier,
      UUID(uuidString: id) != nil,
      let kind = boundedString(object["kind"], maximum: 16),
      allowedShareKinds.contains(kind),
      let createdAt = boundedString(object["createdAt"], maximum: 64),
      iso8601.date(from: createdAt) != nil
    else {
      return nil
    }

    let text = boundedString(object["text"], maximum: 100_000)
    let mimeType = boundedString(object["mimeType"], maximum: 128)
    let displayName = boundedString(object["displayName"], maximum: 256)
    var bytesBase64: String?
    if let encoded = object["bytesBase64"] as? String {
      guard
        encoded.count <= maxBase64Characters,
        let data = Data(base64Encoded: encoded),
        data.count <= maxPayloadBytes
      else {
        return nil
      }
      bytesBase64 = data.base64EncodedString()
    }

    guard text != nil || bytesBase64 != nil else { return nil }
    if (kind == "text" || kind == "url"), text == nil { return nil }
    if (kind == "image" || kind == "file"), bytesBase64 == nil { return nil }

    var payload: [String: Any] = [
      "id": id,
      "kind": kind,
      "createdAt": createdAt,
      "metadata": [String: String](),
    ]
    if let text { payload["text"] = text }
    if let mimeType { payload["mimeType"] = mimeType }
    if let displayName { payload["displayName"] = displayName }
    if let bytesBase64 { payload["bytesBase64"] = bytesBase64 }
    return payload
  }

  private func strictWidgetAction(_ object: [String: Any]) -> [String: Any]? {
    guard
      object["type"] as? String == "completeHabit",
      let stepId = boundedString(object["stepId"], maximum: 128),
      let localDay = boundedString(object["localDay"], maximum: 10),
      localDay.range(
        of: #"^\d{4}-\d{2}-\d{2}$"#,
        options: .regularExpression
      ) != nil
    else {
      return nil
    }
    return [
      "type": "completeHabit",
      "stepId": stepId,
      "localDay": localDay,
    ]
  }

  private func boundedString(_ value: Any?, maximum: Int) -> String? {
    guard let value = value as? String else { return nil }
    let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalized.isEmpty, normalized.count <= maximum else { return nil }
    return normalized
  }

  private func embeddedExtensionExists(named name: String) -> Bool {
    guard let plugIns = Bundle.main.builtInPlugInsURL else { return false }
    return FileManager.default.fileExists(
      atPath: plugIns.appendingPathComponent(name).path
    )
  }

  private enum BridgeError: Error {
    case invalidArguments
    case payloadTooLarge
  }
}
