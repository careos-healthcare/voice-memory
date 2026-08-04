import CryptoKit
import Darwin
import Foundation
import Security

enum SecureAppGroupStoreError: Error {
  case appGroupUnavailable
  case invalidKeychainAccessGroup
  case keychain(OSStatus)
  case invalidPayload
}

/// AES-GCM storage shared by the app, widgets, and share extension.
///
/// The app group contains ciphertext only. The 256-bit handoff key is held in
/// the shared Keychain access group declared by every participating target.
final class SecureAppGroupStore {
  struct Record {
    let identifier: String
    let object: [String: Any]
  }

  static let shared = SecureAppGroupStore()

  static let appGroupIdentifier = "group.com.voicememory.mobile"
  static let keychainAccessGroupInfoKey = "ArchiveMeSharedKeychainAccessGroup"

  private let keychainService = "com.voicememory.mobile.os-integration"
  private let keychainAccount = "app-group-handoff-aes-gcm-v1"
  private let fileManager = FileManager.default

  private struct Envelope: Codable {
    let version: Int
    let nonce: Data
    let ciphertext: Data
    let tag: Data
  }

  private init() {}

  var sharedContainerURL: URL? {
    fileManager.containerURL(
      forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier
    )
  }

  @discardableResult
  func writeJSONObject(
    _ object: [String: Any],
    category: String,
    identifier: String = UUID().uuidString
  ) throws -> String {
    guard JSONSerialization.isValidJSONObject(object) else {
      throw SecureAppGroupStoreError.invalidPayload
    }
    let plaintext = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    let key = try loadOrCreateKey()
    let sealed = try AES.GCM.seal(plaintext, using: key)
    let envelope = Envelope(
      version: 1,
      nonce: Data(sealed.nonce),
      ciphertext: sealed.ciphertext,
      tag: sealed.tag
    )
    let encryptedData = try JSONEncoder().encode(envelope)

    try withExclusiveLock {
      let destination = try payloadURL(category: category, identifier: identifier)
      try encryptedData.write(to: destination, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
    return identifier
  }

  func readJSONObject(
    category: String,
    identifier: String,
    consume: Bool = false
  ) throws -> [String: Any]? {
    try withExclusiveLock {
      let source = try payloadURL(category: category, identifier: identifier)
      guard fileManager.fileExists(atPath: source.path) else { return nil }
      let encryptedData = try Data(contentsOf: source)
      let object = try decryptJSONObject(encryptedData)
      if consume {
        try fileManager.removeItem(at: source)
      }
      return object
    }
  }

  /// Returns all decryptable records without deleting them.
  ///
  /// Callers must validate and convert each object before calling `remove`.
  /// Corrupt records remain encrypted on disk for diagnosis/recovery rather
  /// than causing valid inbox entries to be lost.
  func readAllJSONObjects(category: String) throws -> [Record] {
    try withExclusiveLock {
      let directory = try storageDirectory()
      let prefix = "\(safeComponent(category))-"
      let suffix = ".agcm"
      let urls = try fileManager.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: nil,
        options: [.skipsHiddenFiles]
      )
      return urls.compactMap { url in
        let name = url.lastPathComponent
        guard name.hasPrefix(prefix), name.hasSuffix(suffix) else { return nil }
        let start = name.index(name.startIndex, offsetBy: prefix.count)
        let end = name.index(name.endIndex, offsetBy: -suffix.count)
        let identifier = String(name[start..<end])
        guard !identifier.isEmpty else { return nil }
        do {
          let encryptedData = try Data(contentsOf: url)
          return Record(
            identifier: identifier,
            object: try decryptJSONObject(encryptedData)
          )
        } catch {
          return nil
        }
      }
      .sorted { $0.identifier < $1.identifier }
    }
  }

  func recordCount(category: String) throws -> Int {
    try withExclusiveLock {
      let directory = try storageDirectory()
      let prefix = "\(safeComponent(category))-"
      return try fileManager.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: nil,
        options: [.skipsHiddenFiles]
      ).count {
        $0.lastPathComponent.hasPrefix(prefix) && $0.pathExtension == "agcm"
      }
    }
  }

  func remove(category: String, identifier: String) throws {
    try withExclusiveLock {
      let url = try payloadURL(category: category, identifier: identifier)
      if fileManager.fileExists(atPath: url.path) {
        try fileManager.removeItem(at: url)
      }
    }
  }

  /// Removes a validated acknowledgement batch as one logical operation.
  ///
  /// Existing records are first moved to hidden encrypted staging files. If
  /// any move fails, prior moves are rolled back before the error is returned.
  /// Once every move succeeds the acknowledgement is committed and staging
  /// cleanup is best-effort; callers must not redeliver acknowledged records.
  func removeAll(category: String, identifiers: [String]) throws {
    try withExclusiveLock {
      let transaction = UUID().uuidString
      var staged: [(source: URL, destination: URL)] = []
      do {
        for (index, identifier) in identifiers.enumerated() {
          let source = try payloadURL(category: category, identifier: identifier)
          guard fileManager.fileExists(atPath: source.path) else { continue }
          let destination = try storageDirectory().appendingPathComponent(
            ".ack-\(transaction)-\(index).agcm"
          )
          try fileManager.moveItem(at: source, to: destination)
          staged.append((source, destination))
        }
      } catch {
        for item in staged.reversed() {
          try? fileManager.moveItem(at: item.destination, to: item.source)
        }
        throw error
      }
      for item in staged {
        try? fileManager.removeItem(at: item.destination)
      }
    }
  }

  private func loadOrCreateKey() throws -> SymmetricKey {
    let accessGroup = try sharedKeychainAccessGroup()
    let baseQuery: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: keychainService,
      kSecAttrAccount as String: keychainAccount,
      kSecAttrAccessGroup as String: accessGroup,
    ]
    var readQuery = baseQuery
    readQuery[kSecReturnData as String] = true
    readQuery[kSecMatchLimit as String] = kSecMatchLimitOne

    var item: CFTypeRef?
    let readStatus = SecItemCopyMatching(readQuery as CFDictionary, &item)
    if readStatus == errSecSuccess, let data = item as? Data, data.count == 32 {
      return SymmetricKey(data: data)
    }
    guard readStatus == errSecItemNotFound else {
      throw SecureAppGroupStoreError.keychain(readStatus)
    }

    var bytes = [UInt8](repeating: 0, count: 32)
    let randomStatus = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
    guard randomStatus == errSecSuccess else {
      throw SecureAppGroupStoreError.keychain(randomStatus)
    }
    let keyData = Data(bytes)
    var addQuery = baseQuery
    addQuery[kSecValueData as String] = keyData
    addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
    if addStatus == errSecSuccess {
      return SymmetricKey(data: keyData)
    }
    // Another process may have won the key-creation race.
    if addStatus == errSecDuplicateItem {
      var racedItem: CFTypeRef?
      let racedStatus = SecItemCopyMatching(readQuery as CFDictionary, &racedItem)
      if racedStatus == errSecSuccess, let data = racedItem as? Data, data.count == 32 {
        return SymmetricKey(data: data)
      }
      throw SecureAppGroupStoreError.keychain(racedStatus)
    }
    throw SecureAppGroupStoreError.keychain(addStatus)
  }

  private func decryptJSONObject(_ encryptedData: Data) throws -> [String: Any] {
    let envelope = try JSONDecoder().decode(Envelope.self, from: encryptedData)
    guard envelope.version == 1 else {
      throw SecureAppGroupStoreError.invalidPayload
    }
    let box = try AES.GCM.SealedBox(
      nonce: AES.GCM.Nonce(data: envelope.nonce),
      ciphertext: envelope.ciphertext,
      tag: envelope.tag
    )
    let plaintext = try AES.GCM.open(box, using: loadOrCreateKey())
    guard let object = try JSONSerialization.jsonObject(with: plaintext) as? [String: Any] else {
      throw SecureAppGroupStoreError.invalidPayload
    }
    return object
  }

  private func sharedKeychainAccessGroup() throws -> String {
    guard
      let value = Bundle.main.object(
        forInfoDictionaryKey: Self.keychainAccessGroupInfoKey
      ) as? String,
      !value.isEmpty,
      !value.contains("$(")
    else {
      throw SecureAppGroupStoreError.invalidKeychainAccessGroup
    }
    return value
  }

  private func payloadURL(category: String, identifier: String) throws -> URL {
    let directory = try storageDirectory()
    return directory.appendingPathComponent(
      "\(safeComponent(category))-\(safeComponent(identifier)).agcm",
      isDirectory: false
    )
  }

  private func storageDirectory() throws -> URL {
    guard let container = sharedContainerURL else {
      throw SecureAppGroupStoreError.appGroupUnavailable
    }
    let directory = container.appendingPathComponent("SecureOSIntegration", isDirectory: true)
    try fileManager.createDirectory(
      at: directory,
      withIntermediateDirectories: true,
      attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
    )
    return directory
  }

  private func withExclusiveLock<T>(_ operation: () throws -> T) throws -> T {
    let lockURL = try storageDirectory().appendingPathComponent(".handoff.lock")
    let descriptor = Darwin.open(lockURL.path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
    guard descriptor >= 0 else {
      throw CocoaError(.fileWriteUnknown)
    }
    defer { Darwin.close(descriptor) }
    guard flock(descriptor, LOCK_EX) == 0 else {
      throw CocoaError(.fileWriteUnknown)
    }
    defer { flock(descriptor, LOCK_UN) }
    return try operation()
  }

  private func safeComponent(_ value: String) -> String {
    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
    let scalars = value.unicodeScalars.map { allowed.contains($0) ? Character(String($0)) : "_" }
    return String(scalars).prefix(80).description
  }
}
