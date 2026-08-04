import UIKit
import UniformTypeIdentifiers

private final class SharePayloadAccumulator {
  static let maxItems = 12
  static let maxItemBytes = 20 * 1024 * 1024
  static let maxTotalBytes = 40 * 1024 * 1024
  static let maxTextCharacters = 100_000

  private let lock = NSLock()
  private var payloads: [[String: Any]] = []
  private var totalBytes = 0

  func appendText(_ value: String, kind: String, mimeType: String) {
    let text = String(value.trimmingCharacters(in: .whitespacesAndNewlines)
      .prefix(Self.maxTextCharacters))
    guard !text.isEmpty else { return }
    let size = text.lengthOfBytes(using: .utf8)
    append(size: size) { id, createdAt in
      [
        "id": id,
        "kind": kind,
        "createdAt": createdAt,
        "text": text,
        "mimeType": mimeType,
        "metadata": [String: String](),
      ]
    }
  }

  func appendFile(at url: URL, typeIdentifier: String, suggestedName: String?) {
    guard
      let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
      size > 0,
      size <= Self.maxItemBytes,
      let data = try? Data(contentsOf: url, options: [.mappedIfSafe]),
      data.count == size
    else {
      return
    }
    let type = UTType(typeIdentifier)
    let kind = type?.conforms(to: .image) == true ? "image" : "file"
    let mimeType = String((type?.preferredMIMEType ?? "application/octet-stream").prefix(128))
    let rawName = suggestedName ?? url.lastPathComponent
    let displayName = String(rawName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(256))
    append(size: data.count) { id, createdAt in
      [
        "id": id,
        "kind": kind,
        "createdAt": createdAt,
        "mimeType": mimeType,
        "displayName": displayName.isEmpty ? "Shared item" : displayName,
        "bytesBase64": data.base64EncodedString(),
        "metadata": [String: String](),
      ]
    }
  }

  func snapshot() -> [[String: Any]] {
    lock.lock()
    defer { lock.unlock() }
    return payloads
  }

  private func append(
    size: Int,
    makePayload: (_ id: String, _ createdAt: String) -> [String: Any]
  ) {
    guard size > 0, size <= Self.maxItemBytes else { return }
    lock.lock()
    defer { lock.unlock() }
    guard payloads.count < Self.maxItems, totalBytes + size <= Self.maxTotalBytes else { return }
    let id = UUID().uuidString
    payloads.append(makePayload(id, ISO8601DateFormatter().string(from: Date())))
    totalBytes += size
  }
}

final class ShareViewController: UIViewController {
  private let statusLabel = UILabel()
  private var didStart = false

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground
    statusLabel.text = "Saving securely…"
    statusLabel.textAlignment = .center
    statusLabel.numberOfLines = 0
    statusLabel.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(statusLabel)
    NSLayoutConstraint.activate([
      statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
      statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
      statusLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
    ])
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    guard !didStart else { return }
    didStart = true
    collectPayload()
  }

  private func collectPayload() {
    let providers = extensionContext?.inputItems
      .compactMap { $0 as? NSExtensionItem }
      .flatMap { $0.attachments ?? [] }
      .prefix(SharePayloadAccumulator.maxItems) ?? []
    let group = DispatchGroup()
    let accumulator = SharePayloadAccumulator()

    for provider in providers {
      if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
        group.enter()
        provider.loadItem(forTypeIdentifier: UTType.url.identifier) { item, _ in
          defer { group.leave() }
          if let url = item as? URL, url.isFileURL {
            let type = (try? url.resourceValues(forKeys: [.contentTypeKey]).contentType)
              ?? UTType.data
            accumulator.appendFile(
              at: url,
              typeIdentifier: type.identifier,
              suggestedName: provider.suggestedName
            )
          } else if let value = (item as? URL)?.absoluteString ?? (item as? String) {
            accumulator.appendText(value, kind: "url", mimeType: "text/uri-list")
          }
        }
      } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
        group.enter()
        provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) { item, _ in
          defer { group.leave() }
          guard let value = item as? String else { return }
          accumulator.appendText(value, kind: "text", mimeType: "text/plain")
        }
      } else if let typeIdentifier = supportedBinaryType(for: provider) {
        group.enter()
        provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { url, _ in
          defer { group.leave() }
          guard let url else { return }
          accumulator.appendFile(
            at: url,
            typeIdentifier: typeIdentifier,
            suggestedName: provider.suggestedName
          )
        }
      }
    }

    group.notify(queue: .main) { [weak self] in
      self?.persist(payloads: accumulator.snapshot())
    }
  }

  private func supportedBinaryType(for provider: NSItemProvider) -> String? {
    let specific = provider.registeredTypeIdentifiers.first { identifier in
      guard let type = UTType(identifier) else { return false }
      return type.conforms(to: .image) || type.conforms(to: .data)
    }
    if let specific { return specific }
    guard provider.hasItemConformingToTypeIdentifier(UTType.item.identifier) else {
      return nil
    }
    return provider.registeredTypeIdentifiers.first
  }

  private func persist(payloads: [[String: Any]]) {
    guard !payloads.isEmpty else {
      finish(message: "Nothing supported was shared.", identifier: nil)
      return
    }

    var saved = 0
    do {
      for payload in payloads {
        guard let identifier = payload["id"] as? String else { continue }
        try SecureAppGroupStore.shared.writeJSONObject(
          payload,
          category: "share-inbox",
          identifier: identifier
        )
        saved += 1
      }
      finish(
        message: saved == 1 ? "Saved securely." : "Saved \(saved) items securely.",
        identifier: saved > 0 ? "inbox" : nil
      )
    } catch {
      finish(message: "ArchiveMe could not save this item.", identifier: nil)
    }
  }

  private func finish(message: String, identifier: String?) {
    statusLabel.text = message
    guard
      identifier != nil,
      var components = URLComponents(string: "archiveme://record")
    else {
      complete(after: 0.8)
      return
    }
    components.queryItems = [URLQueryItem(name: "source", value: "share-extension")]
    guard let url = components.url else {
      complete(after: 0.8)
      return
    }
    extensionContext?.open(url) { [weak self] _ in
      self?.complete(after: 0.15)
    }
  }

  private func complete(after delay: TimeInterval) {
    DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
      self?.extensionContext?.completeRequest(returningItems: nil)
    }
  }
}
