import AVFoundation
import Flutter

final class IosCaptureAudioCompressor {
  static let shared = IosCaptureAudioCompressor()

  private init() {}

  func compress(
    inputPath: String,
    outputPath: String,
    sampleRateHz: Int,
    bitRateBps: Int,
    channelCount: Int
  ) throws -> [String: Any] {
    let inputURL = URL(fileURLWithPath: inputPath)
    let outputURL = URL(fileURLWithPath: outputPath)

    if FileManager.default.fileExists(atPath: outputURL.path) {
      try FileManager.default.removeItem(at: outputURL)
    }

    let asset = AVURLAsset(url: inputURL)
    guard let reader = try? AVAssetReader(asset: asset) else {
      throw CompressError(step: "reader", message: "Could not open audio reader")
    }

    guard let track = asset.tracks(withMediaType: .audio).first else {
      throw CompressError(step: "track", message: "No audio track found")
    }

    let readerOutput = AVAssetReaderTrackOutput(
      track: track,
      outputSettings: [
        AVFormatIDKey: kAudioFormatLinearPCM,
        AVLinearPCMBitDepthKey: 16,
        AVLinearPCMIsFloatKey: false,
        AVLinearPCMIsBigEndianKey: false,
        AVLinearPCMIsNonInterleaved: false,
        AVSampleRateKey: NSNumber(value: sampleRateHz),
        AVNumberOfChannelsKey: NSNumber(value: channelCount),
      ]
    )

    reader.add(readerOutput)

    let writer = try AVAssetWriter(outputURL: outputURL, fileType: .m4a)
    let writerInput = AVAssetWriterInput(
      mediaType: .audio,
      outputSettings: [
        AVFormatIDKey: kAudioFormatMPEG4AAC,
        AVSampleRateKey: NSNumber(value: sampleRateHz),
        AVNumberOfChannelsKey: NSNumber(value: channelCount),
        AVEncoderBitRateKey: NSNumber(value: bitRateBps),
      ]
    )
    writerInput.expectsMediaDataInRealTime = false
    guard writer.canAdd(writerInput) else {
      throw CompressError(step: "writer", message: "Cannot add AAC writer input")
    }
    writer.add(writerInput)

    guard reader.startReading() else {
      throw CompressError(step: "reader_start", message: reader.error?.localizedDescription ?? "reader failed")
    }
    guard writer.startWriting() else {
      throw CompressError(step: "writer_start", message: writer.error?.localizedDescription ?? "writer failed")
    }
    writer.startSession(atSourceTime: .zero)

    while reader.status == .reading {
      guard writerInput.isReadyForMoreMediaData else { continue }
      if let sampleBuffer = readerOutput.copyNextSampleBuffer() {
        if !writerInput.append(sampleBuffer) {
          throw CompressError(step: "append", message: writer.error?.localizedDescription ?? "append failed")
        }
      } else {
        writerInput.markAsFinished()
        break
      }
    }

    let group = DispatchGroup()
    group.enter()
    writer.finishWriting {
      group.leave()
    }
    group.wait()

    if writer.status != .completed {
      throw CompressError(
        step: "finish",
        message: writer.error?.localizedDescription ?? "writer did not complete"
      )
    }

    let bytes = (try? FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? NSNumber)?
      .intValue ?? 0

    return [
      "path": outputURL.path,
      "compressed": true,
      "bytes": bytes,
    ]
  }

  struct CompressError: LocalizedError {
    let step: String
    let message: String
    var errorDescription: String? { message }
  }
}

final class IosCaptureAudioCompressorHandler {
  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "compressForUpload":
      guard let args = call.arguments as? [String: Any],
            let inputPath = args["inputPath"] as? String,
            let outputPath = args["outputPath"] as? String else {
        result(
          FlutterError(code: "invalid_args", message: "Expected input/output paths", details: nil)
        )
        return
      }
      let sampleRateHz = args["sampleRateHz"] as? Int ?? 16000
      let bitRateBps = args["bitRateBps"] as? Int ?? 32000
      let channelCount = args["channelCount"] as? Int ?? 1
      do {
        let payload = try IosCaptureAudioCompressor.shared.compress(
          inputPath: inputPath,
          outputPath: outputPath,
          sampleRateHz: sampleRateHz,
          bitRateBps: bitRateBps,
          channelCount: channelCount
        )
        result(payload)
      } catch {
        result(
          FlutterError(
            code: "compress_failed",
            message: error.localizedDescription,
            details: ["step": (error as? IosCaptureAudioCompressor.CompressError)?.step ?? "unknown"]
          )
        )
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
