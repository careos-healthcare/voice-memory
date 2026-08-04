import Flutter
import Foundation

final class ICloudGraphSyncHandler {
  private final class ResultCompletion {
    private let lock = NSLock()
    private var didComplete = false
    private let result: FlutterResult

    init(_ result: @escaping FlutterResult) {
      self.result = result
    }

    func finish(_ value: Any?) {
      lock.lock()
      guard !didComplete else {
        lock.unlock()
        return
      }
      didComplete = true
      lock.unlock()

      let callback = result
      if Thread.isMainThread {
        callback(value)
      } else {
        DispatchQueue.main.async {
          callback(value)
        }
      }
    }
  }

  private enum BridgeError: Error {
    case invalidArguments
    case unavailable
    case notFound
    case downloadTimeout
    case ioFailure

    var code: String {
      switch self {
      case .invalidArguments: return "invalid_args"
      case .unavailable: return "unavailable"
      case .notFound: return "not_found"
      case .downloadTimeout: return "download_timeout"
      case .ioFailure: return "io_error"
      }
    }

    var message: String {
      switch self {
      case .invalidArguments: return "Invalid iCloud graph sync request."
      case .unavailable: return "iCloud Drive is unavailable."
      case .notFound: return "Encrypted graph file was not found."
      case .downloadTimeout:
        return "Encrypted graph download did not become available."
      case .ioFailure: return "iCloud graph sync operation failed."
      }
    }
  }

  private static let containerIdentifier = "iCloud.com.voicememory.mobile"
  private static let pathPrefix = "Documents/ArchiveMe_Sync/"
  private static let downloadTimeout: TimeInterval = 10
  private static let downloadPollInterval: TimeInterval = 0.1

  private let fileManager: FileManager
  private let workQueue = DispatchQueue(
    label: "com.voicememory.mobile.icloud-graph-sync",
    qos: .utility
  )

  init(fileManager: FileManager = .default) {
    self.fileManager = fileManager
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let completion = ResultCompletion(result)
    switch call.method {
    case "isAvailable":
      workQueue.async { [weak self] in
        let available = self?.containerURL() != nil
        completion.finish(available)
      }
    case "upload":
      perform(completion: completion) { [weak self] in
        guard let self else { throw BridgeError.unavailable }
        let arguments = try self.arguments(from: call)
        guard let envelope = arguments["envelope"] as? String, !envelope.isEmpty else {
          throw BridgeError.invalidArguments
        }
        let fileURL = try self.fileURL(for: arguments)
        try self.write(envelope, to: fileURL)
        return nil
      }
    case "download":
      perform(completion: completion) { [weak self] in
        guard let self else { throw BridgeError.unavailable }
        let fileURL = try self.fileURL(for: self.arguments(from: call))
        return try self.read(from: fileURL)
      }
    default:
      completion.finish(FlutterMethodNotImplemented)
    }
  }

  private func perform(
    completion: ResultCompletion,
    operation: @escaping () throws -> Any?
  ) {
    workQueue.async {
      do {
        let value = try operation()
        completion.finish(value)
      } catch let error as BridgeError {
        completion.finish(
          FlutterError(code: error.code, message: error.message, details: nil)
        )
      } catch {
        completion.finish(
          FlutterError(
            code: BridgeError.ioFailure.code,
            message: BridgeError.ioFailure.message,
            details: nil
          )
        )
      }
    }
  }

  private func arguments(from call: FlutterMethodCall) throws -> [String: Any] {
    guard let arguments = call.arguments as? [String: Any] else {
      throw BridgeError.invalidArguments
    }
    return arguments
  }

  private func containerURL() -> URL? {
    guard fileManager.ubiquityIdentityToken != nil else {
      return nil
    }
    return fileManager.url(
      forUbiquityContainerIdentifier: Self.containerIdentifier
    )
  }

  private func fileURL(for arguments: [String: Any]) throws -> URL {
    guard let path = arguments["path"] as? String,
          let filename = validatedFilename(from: path) else {
      throw BridgeError.invalidArguments
    }
    guard let containerURL = containerURL() else {
      throw BridgeError.unavailable
    }

    let directoryURL = containerURL
      .appendingPathComponent("Documents", isDirectory: true)
      .appendingPathComponent("ArchiveMe_Sync", isDirectory: true)
    do {
      try fileManager.createDirectory(
        at: directoryURL,
        withIntermediateDirectories: true
      )
    } catch {
      throw BridgeError.ioFailure
    }
    return directoryURL.appendingPathComponent(filename, isDirectory: false)
  }

  private func validatedFilename(from path: String) -> String? {
    guard path.hasPrefix(Self.pathPrefix) else { return nil }
    let filename = String(path.dropFirst(Self.pathPrefix.count))
    let fullRange = filename.startIndex..<filename.endIndex
    guard !filename.isEmpty, filename.count <= 128,
          filename.range(
            of: #"^[A-Za-z0-9][A-Za-z0-9._-]*$"#,
            options: .regularExpression
          ) == fullRange else {
      return nil
    }
    return filename
  }

  private func write(_ envelope: String, to fileURL: URL) throws {
    guard let data = envelope.data(using: .utf8) else {
      throw BridgeError.invalidArguments
    }
    let coordinator = NSFileCoordinator(filePresenter: nil)
    var coordinationError: NSError?
    var operationError: Error?
    coordinator.coordinate(
      writingItemAt: fileURL,
      options: .forReplacing,
      error: &coordinationError
    ) { coordinatedURL in
      do {
        try data.write(to: coordinatedURL, options: .atomic)
      } catch {
        operationError = error
      }
    }
    if coordinationError != nil || operationError != nil {
      throw BridgeError.ioFailure
    }
  }

  private func read(from fileURL: URL) throws -> String {
    guard fileManager.fileExists(atPath: fileURL.path) else {
      throw BridgeError.notFound
    }
    try ensureDownloaded(fileURL)

    let coordinator = NSFileCoordinator(filePresenter: nil)
    var coordinationError: NSError?
    var operationError: Error?
    var data: Data?
    coordinator.coordinate(
      readingItemAt: fileURL,
      options: [],
      error: &coordinationError
    ) { coordinatedURL in
      do {
        data = try Data(contentsOf: coordinatedURL)
      } catch {
        operationError = error
      }
    }
    guard coordinationError == nil, operationError == nil,
          let data, !data.isEmpty,
          let envelope = String(data: data, encoding: .utf8) else {
      throw BridgeError.ioFailure
    }
    return envelope
  }

  private func ensureDownloaded(_ fileURL: URL) throws {
    let initialValues: URLResourceValues
    do {
      initialValues = try fileURL.resourceValues(
        forKeys: [.isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey]
      )
    } catch {
      throw BridgeError.ioFailure
    }
    guard initialValues.isUbiquitousItem == true,
          initialValues.ubiquitousItemDownloadingStatus != .current else {
      return
    }

    do {
      try fileManager.startDownloadingUbiquitousItem(at: fileURL)
    } catch {
      throw BridgeError.unavailable
    }

    let deadline = ProcessInfo.processInfo.systemUptime + Self.downloadTimeout
    while ProcessInfo.processInfo.systemUptime < deadline {
      do {
        let values = try fileURL.resourceValues(
          forKeys: [.ubiquitousItemDownloadingStatusKey]
        )
        if values.ubiquitousItemDownloadingStatus == .current {
          return
        }
      } catch {
        throw BridgeError.ioFailure
      }
      Thread.sleep(forTimeInterval: Self.downloadPollInterval)
    }
    throw BridgeError.downloadTimeout
  }
}
