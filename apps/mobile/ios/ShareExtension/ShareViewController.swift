import UIKit
import UniformTypeIdentifiers

/// Share Extension entry. Copies shared audio or video into the app group,
/// then opens the host with `archiveme://import`.
@objc(ShareViewController)
class ShareViewController: UIViewController {
  private let appGroup = "group.com.voicememory.mobile"
  private let pendingKey = "archiveme.pendingImports"

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    let providers = (extensionContext?.inputItems as? [NSExtensionItem])?
      .flatMap { $0.attachments ?? [] } ?? []
    guard !providers.isEmpty else {
      finish()
      return
    }

    let group = DispatchGroup()
    let lock = NSLock()
    var paths: [String] = []
    for provider in providers {
      guard let type = matchingType(provider) else { continue }
      group.enter()
      provider.loadFileRepresentation(forTypeIdentifier: type) { [weak self] url, _ in
        if let url, let copied = self?.copyIntoAppGroup(url) {
          lock.lock()
          paths.append(copied)
          lock.unlock()
          group.leave()
          return
        }
        provider.loadDataRepresentation(forTypeIdentifier: type) { data, _ in
          if let data, let copied = self?.writeData(data, suggested: provider.suggestedName) {
            lock.lock()
            paths.append(copied)
            lock.unlock()
          }
          group.leave()
        }
      }
    }

    group.notify(queue: .main) { [weak self] in
      guard let self else { return }
      guard let first = paths.first else {
        self.finish()
        return
      }
      UserDefaults(suiteName: self.appGroup)?.set(paths, forKey: self.pendingKey)
      self.openHost(first) {
        self.finish()
      }
    }
  }

  private func matchingType(_ provider: NSItemProvider) -> String? {
    let types = [
      UTType.audio.identifier,
      UTType.movie.identifier,
      UTType.mpeg4Audio.identifier,
      UTType.wav.identifier,
      UTType.data.identifier,
      "public.file-url",
    ]
    return types.first { provider.hasItemConformingToTypeIdentifier($0) }
  }

  private func copyIntoAppGroup(_ source: URL) -> String? {
    let accessing = source.startAccessingSecurityScopedResource()
    defer {
      if accessing { source.stopAccessingSecurityScopedResource() }
    }
    guard let container = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: appGroup
    ) else { return nil }
    let directory = container.appendingPathComponent("imports", isDirectory: true)
    do {
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      let dest = uniqueDestination(in: directory, name: source.lastPathComponent)
      try FileManager.default.copyItem(at: source, to: dest)
      return dest.path
    } catch {
      return nil
    }
  }

  private func writeData(_ data: Data, suggested: String?) -> String? {
    guard !data.isEmpty,
          let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroup
          ) else { return nil }
    let directory = container.appendingPathComponent("imports", isDirectory: true)
    do {
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      let name = (suggested?.isEmpty == false) ? suggested! : "import-\(UUID().uuidString).m4a"
      let dest = uniqueDestination(in: directory, name: name)
      try data.write(to: dest, options: .atomic)
      return dest.path
    } catch {
      return nil
    }
  }

  private func uniqueDestination(in directory: URL, name: String) -> URL {
    let cleaned = (name as NSString).lastPathComponent
    let safe = cleaned.isEmpty ? "import-\(UUID().uuidString)" : cleaned
    var dest = directory.appendingPathComponent(safe)
    if FileManager.default.fileExists(atPath: dest.path) {
      let base = (safe as NSString).deletingPathExtension
      let ext = (safe as NSString).pathExtension
      let stamped = ext.isEmpty
        ? "\(base)-\(UUID().uuidString)"
        : "\(base)-\(UUID().uuidString).\(ext)"
      dest = directory.appendingPathComponent(stamped)
    }
    return dest
  }

  private func openHost(_ path: String, completion: @escaping () -> Void) {
    guard let encoded = path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
          let url = URL(string: "archiveme://import?path=\(encoded)") else {
      completion()
      return
    }
    extensionContext?.open(url) { _ in
      completion()
    }
  }

  private func finish() {
    extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
  }
}
