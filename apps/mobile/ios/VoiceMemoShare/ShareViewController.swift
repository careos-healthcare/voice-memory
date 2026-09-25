import UIKit
import UniformTypeIdentifiers

/// Accepts an `.m4a` from the Voice Memos share sheet and leaves it in the
/// app group for the main app to transcribe on the next launch.
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
    let provider = providers.first { candidate in
      candidate.hasItemConformingToTypeIdentifier(UTType.mpeg4Audio.identifier)
        || candidate.hasItemConformingToTypeIdentifier("com.apple.m4a-audio")
        || candidate.hasItemConformingToTypeIdentifier(UTType.audio.identifier)
    }
    guard let provider else {
      finish()
      return
    }
    let type = provider.hasItemConformingToTypeIdentifier(UTType.mpeg4Audio.identifier)
      ? UTType.mpeg4Audio.identifier
      : UTType.audio.identifier
    provider.loadFileRepresentation(forTypeIdentifier: type) { url, _ in
      if let url {
        VoiceMemoShareStore.save(url)
      }
      DispatchQueue.main.async { self.finish() }
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

  static func save(_ url: URL) {
    guard let root = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: groupId
    ) else { return }
    let folder = root.appendingPathComponent(folderName, isDirectory: true)
    do {
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
      let dest = folder.appendingPathComponent("\(UUID().uuidString).m4a")
      if FileManager.default.fileExists(atPath: dest.path) {
        try FileManager.default.removeItem(at: dest)
      }
      try FileManager.default.copyItem(at: url, to: dest)
      let created = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date()
      let payload: [String: String] = [
        "path": dest.path,
        "createdAt": ISO8601DateFormatter().string(from: created),
      ]
      let data = try JSONSerialization.data(withJSONObject: payload)
      try data.write(to: folder.appendingPathComponent(pendingName), options: .atomic)
    } catch {
      return
    }
  }
}
