import AVFoundation
import Flutter
import Foundation

enum CaptureAudioCompressorChannel {
  static let name = "com.archiveme/audio_compression"

  static func register(
    messenger: FlutterBinaryMessenger,
    handler: IosCaptureAudioCompressorHandler
  ) {
    let channel = FlutterMethodChannel(name: name, binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      handler.handle(call, result: result)
    }
  }
}

/// Turns a raw capture into an AAC `.m4a` after transcription.
enum CaptureAudioCompressor {
  static func exportAac(inputPath: String, outputPath: String) throws -> [String: Any] {
    let prepared = try prepareExportSource(inputPath)
    defer {
      if prepared.temporary {
        try? FileManager.default.removeItem(at: prepared.url)
      }
    }
    let inputURL = prepared.url
    let requested = URL(fileURLWithPath: outputPath)
    let outputURL = requested.pathExtension.lowercased() == "m4a"
      ? requested
      : requested.deletingPathExtension().appendingPathExtension("m4a")
    if FileManager.default.fileExists(atPath: outputURL.path) {
      try FileManager.default.removeItem(at: outputURL)
    }
    let directory = outputURL.deletingLastPathComponent()
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    let asset = AVURLAsset(url: inputURL)
    guard let session = AVAssetExportSession(
      asset: asset,
      presetName: AVAssetExportPresetAppleM4A
    ) else {
      throw CaptureAudioExportError(message: "AAC export session is unavailable")
    }
    session.outputURL = outputURL
    session.outputFileType = .m4a
    session.shouldOptimizeForNetworkUse = true

    let group = DispatchGroup()
    group.enter()
    session.exportAsynchronously {
      group.leave()
    }
    group.wait()

    if session.status != .completed {
      throw CaptureAudioExportError(
        message: session.error?.localizedDescription ?? "AAC export did not finish"
      )
    }
    try requireM4a(outputURL)

    let bytes = (try? FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? NSNumber)?
      .intValue ?? 0
    return [
      "path": outputURL.path,
      "compressed": true,
      "bytes": bytes,
      "codec": "aac",
    ]
  }

  private static func prepareExportSource(_ inputPath: String) throws -> (url: URL, temporary: Bool) {
    let input = URL(fileURLWithPath: inputPath)
    guard input.pathExtension.lowercased() == "pcm" else {
      return (input, false)
    }
    let pcm = try Data(contentsOf: input)
    var wav = wavHeader(dataSize: pcm.count, sampleRate: 16000, channels: 1, bitsPerSample: 16)
    wav.append(pcm)
    let temporary = FileManager.default.temporaryDirectory
      .appendingPathComponent("archiveme-\(UUID().uuidString).wav")
    try wav.write(to: temporary, options: .atomic)
    return (temporary, true)
  }

  private static func wavHeader(
    dataSize: Int,
    sampleRate: Int,
    channels: Int,
    bitsPerSample: Int
  ) -> Data {
    let blockAlign = channels * bitsPerSample / 8
    let byteRate = sampleRate * blockAlign
    var data = Data()
    data.append(contentsOf: [0x52, 0x49, 0x46, 0x46])
    data.append(uint32(36 + dataSize))
    data.append(contentsOf: [0x57, 0x41, 0x56, 0x45, 0x66, 0x6D, 0x74, 0x20])
    data.append(uint32(16))
    data.append(uint16(1))
    data.append(uint16(channels))
    data.append(uint32(sampleRate))
    data.append(uint32(byteRate))
    data.append(uint16(blockAlign))
    data.append(uint16(bitsPerSample))
    data.append(contentsOf: [0x64, 0x61, 0x74, 0x61])
    data.append(uint32(dataSize))
    return data
  }

  private static func uint16(_ value: Int) -> Data {
    var little = UInt16(value).littleEndian
    return Data(bytes: &little, count: 2)
  }

  private static func uint32(_ value: Int) -> Data {
    var little = UInt32(value).littleEndian
    return Data(bytes: &little, count: 4)
  }

  private static func requireM4a(_ url: URL) throws {
    let handle = try FileHandle(forReadingFrom: url)
    defer { try? handle.close() }
    let head = try handle.read(upToCount: 12) ?? Data()
    guard head.count >= 12 else {
      throw CaptureAudioExportError(message: "AAC export was empty")
    }
    let brand = String(data: head.subdata(in: 4..<8), encoding: .ascii)
    guard brand == "ftyp" else {
      throw CaptureAudioExportError(message: "AAC export was not an m4a")
    }
  }
}

struct CaptureAudioExportError: LocalizedError {
  let message: String
  var errorDescription: String? { message }
}
