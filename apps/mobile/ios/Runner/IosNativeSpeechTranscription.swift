import AVFoundation
import Flutter
import Speech

/// Reason codes sent to Dart on `archive_me/native_speech_transcription`.
///
/// Every value here means "there is no transcript". The channel never pairs a
/// non-empty transcript with a reason, because the Dart caller in
/// `native_speech_transcription.dart` only inspects `reason` when the
/// transcript is empty and otherwise hands the text to the capture pipeline,
/// which stamps it `TranscriptProvenance.speechToText` — quotable back to the
/// user as their own verbatim words. A transcript this file is not certain of
/// must therefore be withheld, not annotated.
///
/// Codes must match `^[a-z][a-z0-9_]{0,47}$`. Anything else is rewritten to
/// `operation_failed` by `ReleaseLogSanitizer.sanitizeReasonCode`, which
/// destroys the distinction these codes exist to carry.
enum NativeSpeechReason {
  /// The caller did not state which language the recording is in.
  static let localeNotSpecified = "locale_not_specified"
  /// `SFSpeechRecognizer` has no recognizer for the requested locale.
  static let localeUnsupported = "locale_unsupported"
  /// A recognizer was returned, but for a different language than requested.
  static let localeMismatch = "locale_mismatch"
  /// The locale is supported, but not for on-device recognition.
  static let onDeviceLocaleUnsupported = "on_device_locale_unsupported"
  /// The caller asked for recognition that may leave the device.
  static let remoteRecognitionRefused = "remote_recognition_refused"
  /// The recognizer exists but reports itself unavailable right now.
  static let recognizerUnavailable = "recognizer_unavailable"
  /// The audio file is missing, or cannot be decoded.
  static let audioUnreadable = "audio_unreadable"
  /// No terminal callback arrived before the deadline.
  static let timedOut = "native_stt_timeout"
  /// Recognition stopped while the recording was still audibly speech.
  static let truncated = "native_stt_truncated"
  /// Completeness could not be established, so the transcript is withheld.
  static let coverageUnverifiable = "native_stt_coverage_unknown"
  /// Recognition finished and produced nothing.
  ///
  /// A task that ends without ever producing a final result or an error has no
  /// code of its own; it is caught by the deadline and reported as a timeout.
  static let emptyTranscript = "empty_native_transcript"

  static func permission(_ status: SFSpeechRecognizerAuthorizationStatus) -> String {
    "speech_permission_\(status.rawValue)"
  }

  /// Turns an `NSError` into a stable machine token.
  ///
  /// The previous implementation sent `error.localizedDescription`, which is a
  /// human sentence in the device language. It changes with the user's locale,
  /// so it cannot be grouped in logs, and it is a free-text string flowing into
  /// the release log pipeline.
  static func recognitionError(_ error: Error) -> String {
    let nsError = error as NSError
    let domain = nsError.domain
      .lowercased()
      .replacingOccurrences(of: "[^a-z0-9]+", with: "_", options: .regularExpression)
      .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
    let shortDomain = String(domain.prefix(24))
    let code = abs(nsError.code)
    return "stt_error_\(shortDomain.isEmpty ? "unknown" : shortDomain)_\(code)"
  }
}

/// The only two things this channel is allowed to return.
///
/// Modelled as a sum type so that "empty transcript" and "failure reason"
/// cannot drift apart. `channelPayload` is the single place the wire format is
/// built, and on the failure arm it hard-codes an empty transcript.
enum NativeSpeechOutcome {
  case transcript(text: String, localeIdentifier: String)
  case failure(reason: String, localeIdentifier: String?)

  /// Builds a success outcome, downgrading blank text to a failure.
  static func forTranscript(_ raw: String, localeIdentifier: String) -> NativeSpeechOutcome {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      return .failure(
        reason: NativeSpeechReason.emptyTranscript,
        localeIdentifier: localeIdentifier
      )
    }
    return .transcript(text: trimmed, localeIdentifier: localeIdentifier)
  }

  var channelPayload: [String: Any] {
    switch self {
    case .transcript(let text, let localeIdentifier):
      return [
        "transcript": text,
        "reason": "",
        "localeIdentifier": localeIdentifier,
      ]
    case .failure(let reason, let localeIdentifier):
      return [
        "transcript": "",
        "reason": reason,
        "localeIdentifier": localeIdentifier ?? "",
      ]
    }
  }
}

/// Delivers exactly one terminal outcome, whichever racing caller gets there
/// first.
///
/// `SFSpeechRecognizer` may report a final result and then an error, and the
/// timeout runs concurrently with both. Passing more than one of those to a
/// `FlutterResult` raises in a debug build, so the guard is a correctness
/// requirement rather than tidiness.
final class NativeSpeechTerminalGate {
  private let lock = NSLock()
  private var sink: ((NativeSpeechOutcome) -> Void)?

  init(_ sink: @escaping (NativeSpeechOutcome) -> Void) {
    self.sink = sink
  }

  /// Returns true only for the call that actually delivered.
  @discardableResult
  func deliver(_ outcome: NativeSpeechOutcome) -> Bool {
    lock.lock()
    guard let sink else {
      lock.unlock()
      return false
    }
    self.sink = nil
    lock.unlock()
    sink(outcome)
    return true
  }

  var hasDelivered: Bool {
    lock.lock()
    defer { lock.unlock() }
    return sink == nil
  }
}

/// Decides whether a final transcript actually covers the recording.
///
/// `SFSpeechRecognizer` can stop early on a long file and still report
/// `isFinal`, which the caller has no way to distinguish from a complete
/// transcript. Persisting that is the failure this whole file is guarding
/// against: half a reflection, stored and quoted as the whole of it.
enum NativeSpeechCoverage {
  /// Below this the one-minute class of truncation cannot have happened, so
  /// the gate does not run and short recordings are unaffected by it.
  static let gateMinimumDurationSeconds: Double = 50
  /// Unrecognised tail short enough to be a natural trailing pause.
  static let suspectTailSeconds: Double = 15
  /// Speech in the tail below this is treated as noise, not lost words.
  static let speechInTailSeconds: Double = 5

  enum Verdict: Equatable {
    /// Recording is too short for the gate to apply.
    case notApplicable
    /// The transcript reaches the end of the speech in the recording.
    case complete
    /// The recording is still speech after the transcript stops.
    case truncated
    /// Completeness could not be established either way.
    case unverifiable
  }

  /// `lastSegmentEndSeconds` is nil when the result carried no segment timing.
  /// `tailSpeechSeconds` is evaluated lazily and only for a suspicious tail,
  /// so the audio scan is skipped for the common case.
  static func verdict(
    audioDurationSeconds: Double,
    lastSegmentEndSeconds: Double?,
    tailSpeechSeconds: (Double) -> Double?
  ) -> Verdict {
    guard audioDurationSeconds > gateMinimumDurationSeconds else {
      return .notApplicable
    }
    guard let lastSegmentEndSeconds, lastSegmentEndSeconds > 0 else {
      return .unverifiable
    }
    let tail = audioDurationSeconds - lastSegmentEndSeconds
    guard tail > suspectTailSeconds else { return .complete }
    guard let speech = tailSpeechSeconds(lastSegmentEndSeconds) else {
      return .unverifiable
    }
    return speech >= speechInTailSeconds ? .truncated : .complete
  }
}

/// Reads the recording to answer "is there still speech after this point?".
enum NativeSpeechAudioProbe {
  static let frameSeconds: Double = 0.1
  /// How far below the recognised region's own speech level a frame may sit
  /// and still count as speech.
  ///
  /// The reference is the recognised region rather than an estimated noise
  /// floor. A floor estimated from the whole file is useless for the case that
  /// matters most — 300 seconds of continuous talking truncated at 60 — where
  /// the quietest tenth of the file is still speech, so a floor-relative gate
  /// would place the threshold above the speech itself and see nothing.
  private static let tailGateDecibelsBelowReference: Double = -12
  /// Guards against a reference region that was itself near-silent.
  private static let absoluteSpeechFloor: Float = 0.001
  /// Robust stand-in for "how loud the speech is", ignoring the pauses.
  private static let referencePercentile = 0.75

  static func durationSeconds(of url: URL) -> Double? {
    guard let file = try? AVAudioFile(forReading: url) else { return nil }
    let sampleRate = file.processingFormat.sampleRate
    guard sampleRate > 0, file.length > 0 else { return nil }
    return Double(file.length) / sampleRate
  }

  /// Seconds after `start` that are as loud as the speech before `start`.
  ///
  /// Returns nil when the file cannot be analysed or there is nothing to
  /// compare against, which callers treat as "unverifiable" rather than
  /// "no speech".
  static func speechSeconds(after start: Double, in url: URL) -> Double? {
    guard let frames = frameEnergies(of: url), !frames.isEmpty else { return nil }
    let boundary = max(0, Int(start / frameSeconds))
    guard boundary > 0, boundary < frames.count else { return nil }

    let reference = frames[..<boundary].sorted()
    let referenceLevel = reference[Int(Double(reference.count - 1) * referencePercentile)]
    let threshold = max(
      referenceLevel * Float(pow(10.0, tailGateDecibelsBelowReference / 20.0)),
      absoluteSpeechFloor
    )

    let loud = frames[boundary...].reduce(into: 0) { count, energy in
      if energy >= threshold { count += 1 }
    }
    return Double(loud) * frameSeconds
  }

  /// RMS amplitude per 100 ms of the whole file, in order.
  private static func frameEnergies(of url: URL) -> [Float]? {
    guard let file = try? AVAudioFile(forReading: url) else { return nil }
    let format = file.processingFormat
    guard format.sampleRate > 0, format.channelCount > 0 else { return nil }

    let framesPerWindow = AVAudioFrameCount(format.sampleRate * frameSeconds)
    guard framesPerWindow > 0,
          let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: framesPerWindow)
    else { return nil }

    var energies: [Float] = []

    // `AVAudioFile.read` throws once the end of the file is reached rather
    // than returning an empty buffer, so the loop is bounded by the frame
    // position. Reading until a short read arrives would treat every complete
    // file as unreadable.
    while file.framePosition < file.length {
      let remaining = AVAudioFrameCount(
        min(Int64(framesPerWindow), file.length - file.framePosition)
      )
      do {
        try file.read(into: buffer, frameCount: remaining)
      } catch {
        return nil
      }
      let count = Int(buffer.frameLength)
      guard count > 0, let channels = buffer.floatChannelData else { return nil }

      var sumOfSquares: Float = 0
      for channel in 0..<Int(format.channelCount) {
        let samples = channels[channel]
        for index in 0..<count {
          let sample = samples[index]
          sumOfSquares += sample * sample
        }
      }
      let divisor = Float(count * Int(format.channelCount))
      energies.append((sumOfSquares / divisor).squareRoot())
    }
    return energies
  }
}

/// How long to wait for a terminal callback before giving up.
enum NativeSpeechDeadline {
  static let minimumSeconds: Double = 90
  static let maximumSeconds: Double = 600
  static let durationMultiplier: Double = 2
  static let fixedOverheadSeconds: Double = 30

  static func seconds(forAudioDuration audioDuration: Double) -> Double {
    let scaled = audioDuration * durationMultiplier + fixedOverheadSeconds
    return min(maximumSeconds, max(minimumSeconds, scaled))
  }
}

final class IosNativeSpeechTranscription {
  static let shared = IosNativeSpeechTranscription()

  private init() {}

  /// `localeIdentifier` is required and names the language the recording is
  /// expected to be in.
  ///
  /// It is not defaulted to the device locale on purpose. A recognizer running
  /// in the wrong language does not fail — it succeeds and returns fluent
  /// nonsense, and the caller stamps that nonsense as the user's own words.
  /// Nothing observable on this side of the channel can tell that apart from a
  /// good transcript, so the only place the language can be established is the
  /// caller, and the only safe response to its absence is to refuse.
  func transcribe(
    audioPath: String,
    preferOnDevice: Bool,
    localeIdentifier: String?,
    completion: @escaping (Result<[String: Any], Error>) -> Void
  ) {
    let gate = NativeSpeechTerminalGate { outcome in
      let payload = outcome.channelPayload
      DispatchQueue.main.async { completion(.success(payload)) }
    }

    guard let localeIdentifier, !localeIdentifier.trimmingCharacters(in: .whitespaces).isEmpty
    else {
      gate.deliver(.failure(reason: NativeSpeechReason.localeNotSpecified, localeIdentifier: nil))
      return
    }

    // The native path exists only as the offline fallback. Letting it fall
    // back to server recognition would ship a private mental-health recording
    // off the device on a code path whose entire justification is that the
    // network is unavailable.
    guard preferOnDevice else {
      gate.deliver(
        .failure(
          reason: NativeSpeechReason.remoteRecognitionRefused,
          localeIdentifier: localeIdentifier
        )
      )
      return
    }

    let url = URL(fileURLWithPath: audioPath)
    guard let audioDuration = NativeSpeechAudioProbe.durationSeconds(of: url) else {
      gate.deliver(
        .failure(reason: NativeSpeechReason.audioUnreadable, localeIdentifier: localeIdentifier)
      )
      return
    }

    SFSpeechRecognizer.requestAuthorization { status in
      guard status == .authorized else {
        gate.deliver(
          .failure(
            reason: NativeSpeechReason.permission(status),
            localeIdentifier: localeIdentifier
          )
        )
        return
      }
      self.startRecognition(
        url: url,
        audioDuration: audioDuration,
        localeIdentifier: localeIdentifier,
        gate: gate
      )
    }
  }

  private func startRecognition(
    url: URL,
    audioDuration: Double,
    localeIdentifier: String,
    gate: NativeSpeechTerminalGate
  ) {
    let requestedLocale = Locale(identifier: localeIdentifier)

    guard let recognizer = SFSpeechRecognizer(locale: requestedLocale) else {
      gate.deliver(
        .failure(reason: NativeSpeechReason.localeUnsupported, localeIdentifier: localeIdentifier)
      )
      return
    }

    // `SFSpeechRecognizer(locale:)` is documented to return nil for an
    // unsupported locale, but the returned recognizer's own locale is the only
    // authority on what language it will actually decode.
    guard Self.languagesMatch(localeIdentifier, recognizer.locale.identifier) else {
      gate.deliver(
        .failure(
          reason: NativeSpeechReason.localeMismatch,
          localeIdentifier: recognizer.locale.identifier
        )
      )
      return
    }

    guard recognizer.supportsOnDeviceRecognition else {
      gate.deliver(
        .failure(
          reason: NativeSpeechReason.onDeviceLocaleUnsupported,
          localeIdentifier: localeIdentifier
        )
      )
      return
    }

    guard recognizer.isAvailable else {
      gate.deliver(
        .failure(
          reason: NativeSpeechReason.recognizerUnavailable,
          localeIdentifier: localeIdentifier
        )
      )
      return
    }

    let request = SFSpeechURLRecognitionRequest(url: url)
    request.shouldReportPartialResults = false
    request.requiresOnDeviceRecognition = true

    // Apple's guidance is to hold a strong reference to the recognizer for the
    // lifetime of the task. Whether ARC actually tears it down mid-task has
    // not been demonstrated, so this is insurance and not the explanation for
    // any observed failure.
    let session = RecognitionSession(recognizer: recognizer, request: request, gate: gate)

    session.startDeadline(after: NativeSpeechDeadline.seconds(forAudioDuration: audioDuration)) {
      .failure(reason: NativeSpeechReason.timedOut, localeIdentifier: localeIdentifier)
    }

    session.adopt(recognizer.recognitionTask(with: request) { result, error in
      if let error {
        session.finish(
          .failure(
            reason: NativeSpeechReason.recognitionError(error),
            localeIdentifier: localeIdentifier
          )
        )
        return
      }
      guard let result else { return }
      // Partial results are switched off, so a non-final result should not
      // arrive. If one does it is a fragment, and a fragment must never be
      // delivered as the finished transcript.
      guard result.isFinal else { return }

      let verdict = NativeSpeechCoverage.verdict(
        audioDurationSeconds: audioDuration,
        lastSegmentEndSeconds: Self.lastSegmentEnd(of: result),
        tailSpeechSeconds: { NativeSpeechAudioProbe.speechSeconds(after: $0, in: url) }
      )

      switch verdict {
      case .notApplicable, .complete:
        session.finish(
          .forTranscript(
            result.bestTranscription.formattedString,
            localeIdentifier: localeIdentifier
          )
        )
      case .truncated:
        session.finish(
          .failure(reason: NativeSpeechReason.truncated, localeIdentifier: localeIdentifier)
        )
      case .unverifiable:
        session.finish(
          .failure(
            reason: NativeSpeechReason.coverageUnverifiable,
            localeIdentifier: localeIdentifier
          )
        )
      }
    })
  }

  /// End timestamp of the last recognised word, or nil when the result carried
  /// no usable timing.
  private static func lastSegmentEnd(of result: SFSpeechRecognitionResult) -> Double? {
    guard let last = result.bestTranscription.segments.last else { return nil }
    let end = last.timestamp + last.duration
    return end > 0 ? end : nil
  }

  /// Compares the primary language subtag of two locale identifiers.
  ///
  /// Done on the identifier string rather than through `Locale.languageCode`,
  /// which is deprecated from iOS 16 and would warn. A region difference
  /// (`en-GB` against `en-US`) is allowed through: it cannot produce
  /// cross-language nonsense, which is the failure being guarded against.
  static func languagesMatch(_ requested: String, _ resolved: String) -> Bool {
    guard let requestedLanguage = primaryLanguageSubtag(requested),
          let resolvedLanguage = primaryLanguageSubtag(resolved)
    else { return false }
    return requestedLanguage == resolvedLanguage
  }

  static func primaryLanguageSubtag(_ identifier: String) -> String? {
    let normalized = identifier.replacingOccurrences(of: "_", with: "-")
    guard let first = normalized.split(separator: "-").first, !first.isEmpty else {
      return nil
    }
    return first.lowercased()
  }
}

/// Owns everything that has to outlive the call that created it.
///
/// `recognizer` and `request` are held only to keep them alive for the
/// duration of the task, per Apple's guidance, and are never read back.
private final class RecognitionSession {
  private let recognizer: SFSpeechRecognizer
  private let request: SFSpeechURLRecognitionRequest
  private let gate: NativeSpeechTerminalGate

  private let lock = NSLock()
  private var task: SFSpeechRecognitionTask?
  private var deadline: DispatchSourceTimer?
  /// Keeps the session alive across its own callbacks; cleared by `finish`.
  private var selfReference: RecognitionSession?

  init(
    recognizer: SFSpeechRecognizer,
    request: SFSpeechURLRecognitionRequest,
    gate: NativeSpeechTerminalGate
  ) {
    self.recognizer = recognizer
    self.request = request
    self.gate = gate
    self.selfReference = self
  }

  func startDeadline(after seconds: Double, outcome: @escaping () -> NativeSpeechOutcome) {
    let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
    timer.schedule(deadline: .now() + seconds)
    timer.setEventHandler { [weak self] in
      // The transcript so far is deliberately discarded. A recognition that
      // ran out of time has, by definition, not finished reading the
      // recording, and its partial output would be indistinguishable from a
      // complete one once it crosses the channel.
      self?.finish(outcome())
    }
    lock.lock()
    deadline = timer
    lock.unlock()
    timer.resume()
  }

  /// Takes ownership of the task, cancelling it if the session already ended.
  ///
  /// The callback can fire before `recognitionTask(with:)` returns, so the
  /// session may already be finished by the time we get the handle back.
  func adopt(_ started: SFSpeechRecognitionTask) {
    lock.lock()
    let alreadyFinished = selfReference == nil
    if !alreadyFinished { task = started }
    lock.unlock()
    if alreadyFinished { started.cancel() }
  }

  /// Delivers the outcome if nothing else has, then tears the session down.
  func finish(_ outcome: NativeSpeechOutcome) {
    guard gate.deliver(outcome) else { return }
    lock.lock()
    let endingTask = task
    let endingDeadline = deadline
    task = nil
    deadline = nil
    selfReference = nil
    lock.unlock()
    endingDeadline?.cancel()
    endingTask?.cancel()
  }
}

final class IosNativeSpeechTranscriptionHandler {
  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "transcribeFile":
      guard let args = call.arguments as? [String: Any],
            let audioPath = args["audioPath"] as? String else {
        result(
          FlutterError(code: "invalid_args", message: "Expected audioPath", details: nil)
        )
        return
      }
      let preferOnDevice = args["preferOnDevice"] as? Bool ?? true
      IosNativeSpeechTranscription.shared.transcribe(
        audioPath: audioPath,
        preferOnDevice: preferOnDevice,
        localeIdentifier: args["localeIdentifier"] as? String
      ) { outcome in
        switch outcome {
        case .success(let payload):
          result(payload)
        case .failure(let error):
          result(
            FlutterError(
              code: "native_stt_failed",
              message: error.localizedDescription,
              details: nil
            )
          )
        }
      }
    case "supportedLocales":
      // The device's own answer about which languages it can recognise, which
      // is wider than any list this repo can keep current — 63 identifiers
      // against the 13 in `SpeechLocaleCatalog.offered` at the time of
      // writing, and the hand-maintained list also offers `gu-IN`, which is
      // not among them.
      //
      // This widens what a customer is *offered*. It does not answer "which
      // language is this recording in": that still comes from the customer
      // through `ConfirmedSpeechLocale`, and `transcribeFile` above still
      // refuses `locale_not_specified` without one. A device capability list
      // is not a statement about the person holding the device.
      result(SFSpeechRecognizer.supportedLocales().map(\.identifier))
    case "supportsOnDeviceRecognition":
      // A malformed call is answered with an error rather than `false`.
      // `PlatformLocalTranscriptionAvailability` reads a throw as "could not
      // find out" and leaves availability alone, but reads `false` as a real
      // capability gap and raises a prompt whose easiest dismissal is to allow
      // audio uploads. Only the recognizer itself may say `false` here.
      guard let args = call.arguments as? [String: Any],
            let localeIdentifier = args["localeIdentifier"] as? String,
            !localeIdentifier.trimmingCharacters(in: .whitespaces).isEmpty
      else {
        result(
          FlutterError(
            code: "invalid_args",
            message: "Expected localeIdentifier",
            details: nil
          )
        )
        return
      }
      let recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier))
      result([
        "supportsOnDeviceRecognition": recognizer?.supportsOnDeviceRecognition ?? false
      ])
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
