import AVFoundation
import UIKit
import UniformTypeIdentifiers

/// Accepts audio from the Voice Memos share sheet and leaves it in the
/// app group for the main app to transcribe on the next launch or resume.
final class ShareViewController: UIViewController {
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    storeSharedAudio()
  }

  private func storeSharedAudio() {
    guard
      let item = extensionContext?.inputItems.first as? NSExtensionItem,
      let providers = item.attachments
    else {
      finish()
      return
    }
    let audio = providers.filter(Self.isAudio)
    if audio.isEmpty {
      finish()
      return
    }
    let group = DispatchGroup()
    let lock = NSLock()
    var saved: [[String: String]] = []
    for provider in audio {
      group.enter()
      let type = provider.hasItemConformingToTypeIdentifier(UTType.mpeg4Audio.identifier)
        ? UTType.mpeg4Audio.identifier
        : UTType.audio.identifier
      provider.loadFileRepresentation(forTypeIdentifier: type) { url, _ in
        if let url, let row = VoiceMemoShareStore.save(url) {
          lock.lock()
          saved.append(row)
          lock.unlock()
        }
        group.leave()
      }
    }
    group.notify(queue: .main) {
      VoiceMemoShareStore.writeQueue(saved)
      self.openMainApp()
    }
  }

  private static func isAudio(_ provider: NSItemProvider) -> Bool {
    provider.hasItemConformingToTypeIdentifier(UTType.mpeg4Audio.identifier)
      || provider.hasItemConformingToTypeIdentifier("com.apple.m4a-audio")
      || provider.hasItemConformingToTypeIdentifier(UTType.mp3.identifier)
      || provider.hasItemConformingToTypeIdentifier(UTType.wav.identifier)
      || provider.hasItemConformingToTypeIdentifier(UTType.audio.identifier)
  }

  private func openMainApp() {
    guard let url = URL(string: "voicememory://voice-memo-import") else {
      finish()
      return
    }
    extensionContext?.open(url) { _ in
      self.finish()
    }
  }

  private func finish() {
    extensionContext?.completeRequest(returningItems: nil)
  }
}

enum VoiceMemoShareStore {
  static let groupId = "group.com.voicememory.mobile"
  static let folderName = "voice-memo-inbox"
  static let pendingName = "pending.json"
  static let queueName = "queue.json"

  static func save(_ url: URL) -> [String: String]? {
    guard let root = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: groupId
    ) else { return nil }
    let folder = root.appendingPathComponent(folderName, isDirectory: true)
    let ext = url.pathExtension.lowercased()
    guard ["m4a", "mp3", "wav", "ogg"].contains(ext) else { return nil }
    do {
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
      let dest = folder.appendingPathComponent("\(UUID().uuidString).\(ext)")
      if FileManager.default.fileExists(atPath: dest.path) {
        try FileManager.default.removeItem(at: dest)
      }
      try FileManager.default.copyItem(at: url, to: dest)
      let recorded = recordingDate(of: url) ?? recordingDate(of: dest)
      if let recorded {
        var stamped = dest
        var values = URLResourceValues()
        values.creationDate = recorded
        values.contentModificationDate = recorded
        try? stamped.setResourceValues(values)
      }
      var row = [
        "path": dest.path,
        "name": url.deletingPathExtension().lastPathComponent,
      ]
      if let recorded {
        row["createdAt"] = ISO8601DateFormatter().string(from: recorded)
      }
      return row
    } catch {
      return nil
    }
  }

  static func writeQueue(_ items: [[String: String]]) {
    guard !items.isEmpty,
          let root = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: groupId
          ) else { return }
    let folder = root.appendingPathComponent(folderName, isDirectory: true)
    let payload: [String: Any] = ["items": items]
    guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return }
    try? data.write(to: folder.appendingPathComponent(queueName), options: .atomic)
    if let first = try? JSONSerialization.data(withJSONObject: items[0]) {
      try? first.write(to: folder.appendingPathComponent(pendingName), options: .atomic)
    }
  }

  /// AVAsset commonMetadata creationDate, then the asset creation date,
  /// then the file modification date.
  static func recordingDate(of url: URL) -> Date? {
    let asset = AVURLAsset(url: url)
    for item in asset.commonMetadata {
      if item.commonKey == .commonKeyCreationDate {
        if let date = item.dateValue { return date }
        if let text = item.stringValue,
           let date = ISO8601DateFormatter().date(from: text) {
          return date
        }
      }
    }
    if let created = asset.creationDate?.dateValue { return created }
    return (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
      .contentModificationDate
  }
}
