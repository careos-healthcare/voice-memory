import AVFoundation
import Flutter
import Speech
import UIKit
import XCTest

@testable import Runner

// Behaviour tests for `ios/Runner/IosNativeSpeechTranscription.swift`.
//
// The thing being defended is narrow and specific. A transcript that leaves
// this channel is handed to the capture pipeline, stamped
// `TranscriptProvenance.speechToText`, and later quoted back to the user as
// evidence for a claim about their own beliefs. So a transcript the recognizer
// was not certain of is not a slightly worse transcript — presented as a quote
// it is a fabricated quotation. Every test below exists to keep an uncertain
// outcome from becoming quotable text.
//
// Each class is named for the defect it guards so a red test names the failure
// rather than an index.

private let sampleError = NSError(domain: "kAFAssistantErrorDomain", code: 1101, userInfo: nil)

// MARK: - Defect 3: the completion handler must fire exactly once

/// A faithful reproduction of the pre-fix recognition callback, taken from the
/// original `IosNativeSpeechTranscription.swift`. Only the two Speech types are
/// swapped for fakes, because `SFSpeechRecognitionResult` cannot be constructed
/// by a test. The delivery structure — which is where the defect lived — is
/// unchanged.
private struct FakeTranscription {
  let formattedString: String
}

private struct FakeRecognitionResult {
  let isFinal: Bool
  let bestTranscription: FakeTranscription
}

private enum OriginalDelivery {
  static func recognitionHandler(
    completion: @escaping (Result<[String: Any], Error>) -> Void
  ) -> (FakeRecognitionResult?, Error?) -> Void {
    return { result, error in
      if let error {
        completion(.success(["transcript": "", "reason": error.localizedDescription]))
        return
      }
      guard let result, result.isFinal else { return }
      let transcript = result.bestTranscription.formattedString.trimmingCharacters(
        in: .whitespacesAndNewlines
      )
      completion(
        .success([
          "transcript": transcript,
          "reason": transcript.isEmpty ? "empty_native_transcript" : "",
        ])
      )
    }
  }
}

final class NativeSpeechTerminalDeliveryTests: XCTestCase {

  /// Establishes that the defect was real before asserting that it is fixed.
  func testPreFixCallbackDeliversTwiceForOneRecognition() {
    var deliveries: [[String: Any]] = []
    let handler = OriginalDelivery.recognitionHandler { outcome in
      if case .success(let payload) = outcome { deliveries.append(payload) }
    }

    // The sequence SFSpeechRecognizer is documented to be able to produce: a
    // final result, and then a failure while tearing the task down.
    handler(
      FakeRecognitionResult(
        isFinal: true,
        bestTranscription: .init(formattedString: "i think i was angry")
      ),
      nil
    )
    handler(nil, sampleError)

    XCTAssertEqual(deliveries.count, 2, "unguarded completion is invoked twice")
    XCTAssertNotEqual(
      deliveries.first?["transcript"] as? String,
      deliveries.last?["transcript"] as? String,
      "second invocation would hand FlutterResult a different payload"
    )
  }

  func testGateDeliversTheFirstOutcomeAndRefusesTheSecond() {
    var deliveries: [NativeSpeechOutcome] = []
    let gate = NativeSpeechTerminalGate { deliveries.append($0) }

    let first = gate.deliver(.forTranscript("i think i was angry", localeIdentifier: "en-US"))
    let second = gate.deliver(
      .failure(
        reason: NativeSpeechReason.recognitionError(sampleError),
        localeIdentifier: "en-US"
      )
    )

    XCTAssertTrue(first, "first delivery wins")
    XCTAssertFalse(second, "second delivery is refused")
    XCTAssertEqual(deliveries.count, 1, "sink saw exactly one outcome")
    XCTAssertTrue(gate.hasDelivered, "gate reports itself spent")
  }

  /// The timeout, the result callback and the error callback are on different
  /// queues, so the guard has to hold under a genuine race and not merely in
  /// sequential use.
  func testGateDeliversOnceUnderConcurrentRace() {
    let counter = NSLock()
    var delivered = 0
    let gate = NativeSpeechTerminalGate { _ in
      counter.lock()
      delivered += 1
      counter.unlock()
    }

    var wins = 0
    let winLock = NSLock()
    DispatchQueue.concurrentPerform(iterations: 512) { index in
      let won = gate.deliver(
        index % 2 == 0
          ? .forTranscript("text \(index)", localeIdentifier: "en-US")
          : .failure(reason: NativeSpeechReason.timedOut, localeIdentifier: "en-US")
      )
      if won {
        winLock.lock()
        wins += 1
        winLock.unlock()
      }
    }

    XCTAssertEqual(delivered, 1, "512 concurrent deliveries produce one call")
    XCTAssertEqual(wins, 1, "exactly one caller is told it won")
  }
}

// MARK: - An uncertain outcome must never yield quotable text

final class NativeSpeechOutcomeTests: XCTestCase {

  func testFailureNeverCarriesATranscript() {
    let failure = NativeSpeechOutcome.failure(
      reason: NativeSpeechReason.timedOut,
      localeIdentifier: "en-US"
    )
    XCTAssertEqual(
      failure.channelPayload["transcript"] as? String, "",
      "failure payload transcript is empty"
    )
    XCTAssertEqual(
      failure.channelPayload["reason"] as? String, "native_stt_timeout",
      "failure payload carries the reason"
    )
  }

  func testWhitespaceOnlyTranscriptIsDowngradedToAFailure() {
    let blank = NativeSpeechOutcome.forTranscript("   \n ", localeIdentifier: "en-US")
    XCTAssertEqual(
      blank.channelPayload["transcript"] as? String, "",
      "whitespace-only transcript becomes a failure"
    )
    XCTAssertEqual(
      blank.channelPayload["reason"] as? String, "empty_native_transcript",
      "whitespace-only transcript reports empty_native_transcript"
    )
  }

  func testSuccessPayloadIsTrimmedAndCarriesNoReason() {
    let good = NativeSpeechOutcome.forTranscript(
      "  i think i was angry  ",
      localeIdentifier: "en-US"
    )
    XCTAssertEqual(
      good.channelPayload["transcript"] as? String, "i think i was angry",
      "success payload is trimmed"
    )
    XCTAssertEqual(
      good.channelPayload["reason"] as? String, "",
      "success payload has no reason"
    )
  }

  /// The Dart caller only inspects `reason` when the transcript is empty, so an
  /// outcome carrying both would have its warning ignored and its text quoted.
  func testNoOutcomePairsATranscriptWithAReason() {
    let all: [NativeSpeechOutcome] = [
      .forTranscript("real words", localeIdentifier: "en-US"),
      .forTranscript("", localeIdentifier: "en-US"),
      .failure(reason: NativeSpeechReason.localeNotSpecified, localeIdentifier: nil),
      .failure(reason: NativeSpeechReason.truncated, localeIdentifier: "en-US"),
      .failure(reason: NativeSpeechReason.timedOut, localeIdentifier: "en-US"),
      .failure(reason: NativeSpeechReason.coverageUnverifiable, localeIdentifier: "en-US"),
    ]

    let violation = all.first { outcome in
      let payload = outcome.channelPayload
      let transcript = payload["transcript"] as? String ?? ""
      let reason = payload["reason"] as? String ?? ""
      return !transcript.isEmpty && !reason.isEmpty
    }
    XCTAssertNil(violation, "no outcome pairs a transcript with a reason")

    let missingKeys = all.first { outcome in
      outcome.channelPayload["transcript"] == nil || outcome.channelPayload["reason"] == nil
    }
    XCTAssertNil(missingKeys, "every outcome carries both keys Dart reads")
  }
}

// MARK: - Reason codes must survive release log sanitisation

final class NativeSpeechReasonCodeTests: XCTestCase {

  /// `ReleaseLogSanitizer.sanitizeReasonCode` rewrites anything outside
  /// `^[a-z][a-z0-9_]{0,47}$` to `operation_failed`, which collapses exactly the
  /// distinctions these codes exist to carry.
  func testEveryReasonCodeIsLogSafe() throws {
    let safeToken = try NSRegularExpression(pattern: "^[a-z][a-z0-9_]{0,47}$")
    func isSafe(_ code: String) -> Bool {
      safeToken.firstMatch(in: code, range: NSRange(code.startIndex..., in: code)) != nil
    }

    for code in Self.allReasonCodes {
      XCTAssertTrue(isSafe(code), "reason code '\(code)' is log-safe")
    }
  }

  func testReasonCodesAreDistinct() {
    XCTAssertEqual(
      Set(Self.allReasonCodes).count, Self.allReasonCodes.count,
      "all reason codes are distinct"
    )
  }

  /// The previous implementation sent `error.localizedDescription`, a human
  /// sentence in the device language: ungroupable in logs and free text flowing
  /// into the release log pipeline.
  func testRecognitionErrorsAreStableTokensNotLocalizedSentences() {
    XCTAssertEqual(
      NativeSpeechReason.recognitionError(sampleError),
      "stt_error_kafassistanterrordomain_1101",
      "recognition errors are stable tokens, not localized sentences"
    )
  }

  private static let allReasonCodes = [
    NativeSpeechReason.localeNotSpecified,
    NativeSpeechReason.localeUnsupported,
    NativeSpeechReason.localeMismatch,
    NativeSpeechReason.onDeviceLocaleUnsupported,
    NativeSpeechReason.remoteRecognitionRefused,
    NativeSpeechReason.recognizerUnavailable,
    NativeSpeechReason.audioUnreadable,
    NativeSpeechReason.timedOut,
    NativeSpeechReason.truncated,
    NativeSpeechReason.coverageUnverifiable,
    NativeSpeechReason.emptyTranscript,
    NativeSpeechReason.recognitionError(sampleError),
  ]
}

// MARK: - Defect 1: the locale must be stated, never inferred

final class NativeSpeechLocaleTests: XCTestCase {

  /// A recognizer running in the wrong language does not fail — it succeeds and
  /// returns fluent nonsense, which the caller then stamps as the user's own
  /// words. Nothing on this side of the channel can tell that from a good
  /// transcript, so a region difference is tolerated and a language difference
  /// is not.
  func testLanguageMatchingToleratesRegionButNotLanguage() {
    XCTAssertTrue(
      IosNativeSpeechTranscription.languagesMatch("en-US", "en-US"), "exact match")
    XCTAssertTrue(
      IosNativeSpeechTranscription.languagesMatch("en_US", "en-US"),
      "underscore and hyphen forms match")
    XCTAssertTrue(
      IosNativeSpeechTranscription.languagesMatch("en-GB", "en-US"),
      "region difference is tolerated")
    XCTAssertTrue(
      IosNativeSpeechTranscription.languagesMatch("EN-gb", "en-US"),
      "case difference is tolerated")
    XCTAssertTrue(
      IosNativeSpeechTranscription.languagesMatch("en", "en-US"),
      "bare language matches regional")
    XCTAssertFalse(
      IosNativeSpeechTranscription.languagesMatch("en-US", "ja-JP"),
      "different language is refused")
    XCTAssertFalse(
      IosNativeSpeechTranscription.languagesMatch("", "en-US"),
      "empty requested locale is refused")
    XCTAssertFalse(
      IosNativeSpeechTranscription.languagesMatch("en-US", ""),
      "empty resolved locale is refused")
  }
}

// MARK: - Defect 4: a recognition that runs out of time is not a transcript

final class NativeSpeechDeadlineTests: XCTestCase {

  func testDeadlineScalesWithTheRecordingAndIsBounded() {
    XCTAssertEqual(
      NativeSpeechDeadline.seconds(forAudioDuration: 5), 90,
      "short clip gets the floor")
    XCTAssertEqual(
      NativeSpeechDeadline.seconds(forAudioDuration: 300), 600,
      "300 s recording gets 630 s capped to 600")
    XCTAssertEqual(
      NativeSpeechDeadline.seconds(forAudioDuration: 120), 270,
      "120 s recording gets 270 s")
    XCTAssertEqual(
      NativeSpeechDeadline.seconds(forAudioDuration: 100_000), 600,
      "absurd duration is capped")
    XCTAssertEqual(
      NativeSpeechDeadline.seconds(forAudioDuration: 0), 90,
      "zero duration still gets the floor")
  }
}

// MARK: - Silent truncation must be detected, not returned as a whole transcript

final class NativeSpeechTruncationTests: XCTestCase {

  private func verdict(
    duration: Double,
    lastSegmentEnd: Double?,
    tailSpeech: Double? = nil,
    onProbe: (() -> Void)? = nil
  ) -> NativeSpeechCoverage.Verdict {
    NativeSpeechCoverage.verdict(
      audioDurationSeconds: duration,
      lastSegmentEndSeconds: lastSegmentEnd,
      tailSpeechSeconds: { _ in
        onProbe?()
        return tailSpeech
      }
    )
  }

  func testShortRecordingsSkipTheGate() {
    XCTAssertEqual(
      verdict(duration: 40, lastSegmentEnd: nil), .notApplicable,
      "short recording skips the gate entirely")
  }

  /// The failure this whole file guards against: half a reflection, stored and
  /// quoted as the whole of it.
  func testSpeechContinuingAfterTheTranscriptIsTruncation() {
    XCTAssertEqual(
      verdict(duration: 300, lastSegmentEnd: 62, tailSpeech: 180), .truncated,
      "the 60 s truncation of a 300 s recording is caught")
    XCTAssertEqual(
      verdict(duration: 300, lastSegmentEnd: 62, tailSpeech: 5.0), .truncated,
      "a tail at the speech threshold is refused")
  }

  func testSilenceAfterTheTranscriptIsNotTruncation() {
    XCTAssertEqual(
      verdict(duration: 300, lastSegmentEnd: 62, tailSpeech: 0), .complete,
      "a long silent tail is not mistaken for truncation")
    XCTAssertEqual(
      verdict(duration: 300, lastSegmentEnd: 62, tailSpeech: 4.9), .complete,
      "a tail below the speech threshold is accepted")
    XCTAssertEqual(
      verdict(duration: 300, lastSegmentEnd: 290), .complete,
      "a natural trailing pause is accepted without touching the audio")
  }

  /// "Cannot tell" must not collapse into "complete", which is the whole point:
  /// an unverifiable transcript is withheld rather than quoted.
  func testUnestablishableCoverageIsWithheldNotAccepted() {
    XCTAssertEqual(
      verdict(duration: 300, lastSegmentEnd: nil), .unverifiable,
      "missing segment timing on a long recording is unverifiable")
    XCTAssertEqual(
      verdict(duration: 300, lastSegmentEnd: 0), .unverifiable,
      "zero segment timing on a long recording is unverifiable")
    XCTAssertEqual(
      verdict(duration: 300, lastSegmentEnd: 62, tailSpeech: nil), .unverifiable,
      "an unreadable tail is unverifiable, not complete")
  }

  func testAudioScanIsSkippedWhenTheTailIsShort() {
    var probed = false
    _ = verdict(duration: 300, lastSegmentEnd: 295, onProbe: { probed = true })
    XCTAssertFalse(probed, "the audio scan is skipped when the tail is short")
  }
}

// MARK: - The audio probe, against synthesised recordings

final class NativeSpeechAudioProbeTests: XCTestCase {

  /// Writes a mono 16 kHz file whose amplitude is chosen per second by `level`.
  private func writeClip(_ name: String, seconds: Int, level: (Int) -> Float) -> URL? {
    let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(name)
    try? FileManager.default.removeItem(at: url)
    guard let format = AVAudioFormat(standardFormatWithSampleRate: 16_000, channels: 1),
      let file = try? AVAudioFile(forWriting: url, settings: format.settings)
    else { return nil }

    let framesPerSecond = AVAudioFrameCount(16_000)
    guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: framesPerSecond) else {
      return nil
    }
    buffer.frameLength = framesPerSecond
    for second in 0..<seconds {
      let amplitude = level(second)
      guard let samples = buffer.floatChannelData?[0] else { return nil }
      for index in 0..<Int(framesPerSecond) {
        let phase = 2.0 * Float.pi * 220.0 * Float(index) / 16_000.0
        samples[index] = amplitude * sin(phase)
      }
      try? file.write(from: buffer)
    }
    return url
  }

  func testProbeDistinguishesASilentTailFromALostHalfOfTheRecording() throws {
    // 120 s: talking for the first 60, then genuinely quiet. A transcript that
    // stops at 60 s has not lost anything.
    let quietTail = writeClip("stt_quiet_tail.wav", seconds: 120) { $0 < 60 ? 0.3 : 0.0002 }
    // 120 s: talking throughout. A transcript that stops at 60 s has lost half
    // the reflection.
    let speechTail = writeClip("stt_speech_tail.wav", seconds: 120) { _ in 0.3 }

    XCTAssertTrue(
      quietTail != nil && speechTail != nil, "test clips were written")

    let quiet = try XCTUnwrap(quietTail)
    let speech = try XCTUnwrap(speechTail)
    defer {
      try? FileManager.default.removeItem(at: quiet)
      try? FileManager.default.removeItem(at: speech)
    }

    let quietDuration = NativeSpeechAudioProbe.durationSeconds(of: quiet)
    XCTAssertTrue(
      quietDuration != nil && abs(quietDuration! - 120) < 0.5,
      "duration is read from the file — got \(String(describing: quietDuration))")

    let quietSpeech = NativeSpeechAudioProbe.speechSeconds(after: 60, in: quiet)
    XCTAssertTrue(
      quietSpeech != nil && quietSpeech! < NativeSpeechCoverage.speechInTailSeconds,
      "a quiet tail reports no lost speech — got \(String(describing: quietSpeech))")

    let loudSpeech = NativeSpeechAudioProbe.speechSeconds(after: 60, in: speech)
    XCTAssertTrue(
      loudSpeech != nil && loudSpeech! > 55,
      "continuous speech in the tail is detected — got \(String(describing: loudSpeech))")

    // The end-to-end verdict, using real audio rather than a stub.
    XCTAssertEqual(
      NativeSpeechCoverage.verdict(
        audioDurationSeconds: 120,
        lastSegmentEndSeconds: 60,
        tailSpeechSeconds: { NativeSpeechAudioProbe.speechSeconds(after: $0, in: speech) }
      ),
      .truncated,
      "a real truncated recording is refused")

    XCTAssertEqual(
      NativeSpeechCoverage.verdict(
        audioDurationSeconds: 120,
        lastSegmentEndSeconds: 60,
        tailSpeechSeconds: { NativeSpeechAudioProbe.speechSeconds(after: $0, in: quiet) }
      ),
      .complete,
      "a real complete recording is accepted")

    XCTAssertNil(
      NativeSpeechAudioProbe.speechSeconds(after: 0, in: speech),
      "no reference region means unverifiable, not complete")
  }

  func testAnUnreadableFileIsNeverReportedAsSilence() {
    let absent = URL(fileURLWithPath: "/tmp/definitely-not-here-\(UUID().uuidString).m4a")
    XCTAssertNil(
      NativeSpeechAudioProbe.durationSeconds(of: absent), "a missing file has no duration")
    XCTAssertNil(
      NativeSpeechAudioProbe.speechSeconds(after: 10, in: absent),
      "a missing file cannot be probed")
  }
}

// MARK: - The handler refuses calls it cannot make safe

final class NativeSpeechHandlerRefusalTests: XCTestCase {

  /// `transcribe` delivers via `DispatchQueue.main.async`, so the wait has to
  /// pump the main run loop rather than block it.
  private func invoke(_ arguments: [String: Any]) throws -> [String: Any] {
    var captured: Any?
    let done = expectation(description: "transcribeFile returned")
    IosNativeSpeechTranscriptionHandler().handle(
      FlutterMethodCall(methodName: "transcribeFile", arguments: arguments)
    ) { value in
      captured = value
      done.fulfill()
    }
    wait(for: [done], timeout: 5)
    return try XCTUnwrap(captured as? [String: Any], "expected a channel payload")
  }

  /// Inferring the device locale was the original bug: it turned "we do not
  /// know what language this is" into a confident transcription in whatever
  /// language the phone happened to be set to.
  func testAMissingLocaleIsRefusedRatherThanInferred() throws {
    let payload = try invoke([
      "audioPath": "/tmp/does-not-exist.m4a",
      "preferOnDevice": true,
    ])
    XCTAssertEqual(
      payload["reason"] as? String, "locale_not_specified", "an absent locale is refused")
    XCTAssertEqual(
      payload["transcript"] as? String, "", "a refused locale returns no transcript")
  }

  /// The native path exists only as the offline fallback. Falling back to
  /// server recognition would send a private mental-health recording off the
  /// device on a code path justified by the network being unavailable.
  func testRemoteRecognitionIsRefused() throws {
    let payload = try invoke([
      "audioPath": "/tmp/does-not-exist.m4a",
      "preferOnDevice": false,
      "localeIdentifier": "en-US",
    ])
    XCTAssertEqual(
      payload["reason"] as? String, "remote_recognition_refused",
      "preferOnDevice:false is refused")
  }

  func testAMissingAudioFileIsRefusedBeforeRequestingAuthorization() throws {
    let payload = try invoke([
      "audioPath": "/tmp/does-not-exist.m4a",
      "preferOnDevice": true,
      "localeIdentifier": "en-US",
    ])
    XCTAssertEqual(
      payload["reason"] as? String, "audio_unreadable",
      "a missing audio file is refused before authorization")
  }
}

// MARK: - Defect 8: the offered language list was 13 hand-maintained entries

/// The catalogue in `speech_locale.dart` is hand-maintained, so a speaker of
/// any language missing from it cannot pick one, and therefore cannot use
/// on-device transcription at all — the private path was available in 13
/// languages and everyone else had to choose between privacy and a transcript.
///
/// These cover the two channel methods that let Dart ask the device instead.
/// They assert shape rather than an exact locale set, because the set is a
/// property of the OS build the suite happens to run on.
final class NativeSpeechCapabilityQueryTests: XCTestCase {

  /// Both new methods answer synchronously, unlike `transcribeFile`.
  private func invoke(_ method: String, _ arguments: Any? = nil) throws -> Any {
    var captured: Any?
    var delivered = 0
    IosNativeSpeechTranscriptionHandler().handle(
      FlutterMethodCall(methodName: method, arguments: arguments)
    ) { value in
      captured = value
      delivered += 1
    }
    XCTAssertEqual(delivered, 1, "\(method) must answer exactly once")
    return try XCTUnwrap(captured, "expected an answer from \(method)")
  }

  /// The number of entries in `SpeechLocaleCatalog.offered`, which this
  /// channel method exists to stop being the limit.
  private let handMaintainedCatalogueSize = 13

  func testSupportedLocalesReportsTheDevicesOwnList() throws {
    let identifiers = try XCTUnwrap(
      invoke("supportedLocales") as? [String],
      "supportedLocales must answer a list of identifier strings")

    XCTAssertFalse(identifiers.isEmpty, "a device with Speech.framework offers locales")
    XCTAssertEqual(
      Set(identifiers).count, identifiers.count, "identifiers are not duplicated")
    XCTAssertEqual(
      identifiers.sorted(), SFSpeechRecognizer.supportedLocales().map(\.identifier).sorted(),
      "the answer is the framework's, unfiltered")
  }

  func testSupportedLocalesIsWiderThanTheHandMaintainedCatalogue() throws {
    let identifiers = try XCTUnwrap(invoke("supportedLocales") as? [String])
    XCTAssertGreaterThan(
      identifiers.count, handMaintainedCatalogueSize,
      "the point of asking the device is that it knows more languages than the list")
  }

  /// Every identifier has to survive `ConfirmedSpeechLocale.confirmed`, whose
  /// pattern is `^[A-Za-z]{2,3}(-[A-Za-z0-9]{2,8})*$`. One that does not is a
  /// language the Dart side would silently drop after widening the list, which
  /// would be the same exclusion in a new place.
  func testEveryReportedIdentifierIsOfferableToDart() throws {
    let identifiers = try XCTUnwrap(invoke("supportedLocales") as? [String])
    let offerable = try NSRegularExpression(
      pattern: "^[A-Za-z]{2,3}(-[A-Za-z0-9]{2,8})*$")

    for identifier in identifiers {
      let range = NSRange(identifier.startIndex..., in: identifier)
      XCTAssertNotNil(
        offerable.firstMatch(in: identifier, range: range),
        "\(identifier) cannot be built into a ConfirmedSpeechLocale")
    }
  }

  /// Widening the offered list must not become a way to skip the question.
  ///
  /// The device knowing 63 languages says nothing about which one was spoken
  /// into the microphone, and this channel must keep refusing to guess.
  func testKnowingTheLocalesDoesNotLetTranscriptionProceedWithoutOne() throws {
    _ = try invoke("supportedLocales")

    var captured: Any?
    let done = expectation(description: "transcribeFile returned")
    IosNativeSpeechTranscriptionHandler().handle(
      FlutterMethodCall(
        methodName: "transcribeFile",
        arguments: ["audioPath": "/tmp/does-not-exist.m4a", "preferOnDevice": true])
    ) { value in
      captured = value
      done.fulfill()
    }
    wait(for: [done], timeout: 5)

    let payload = try XCTUnwrap(captured as? [String: Any])
    XCTAssertEqual(
      payload["reason"] as? String, "locale_not_specified",
      "a supported-locale query is not a confirmed locale")
  }

  func testSupportsOnDeviceRecognitionAnswersForAnExplicitLocale() throws {
    let payload = try XCTUnwrap(
      invoke("supportsOnDeviceRecognition", ["localeIdentifier": "en-US"])
        as? [String: Any],
      "the answer is a map Dart can read the flag out of")
    XCTAssertNotNil(
      payload["supportsOnDeviceRecognition"] as? Bool,
      "the flag is a bool under its own key")
  }

  /// A `false` here raises a prompt in front of the customer whose easiest
  /// dismissal is to allow audio uploads, so only the recognizer may say it.
  /// A call this handler cannot understand is "could not find out".
  func testAMalformedCallIsAnErrorRatherThanAManufacturedCapabilityGap() throws {
    let malformed: [Any?] = [
      nil,
      [String: Any](),
      ["localeIdentifier": "  "],
      ["localeIdentifier": 7],
    ]

    for arguments in malformed {
      let answer = try invoke("supportsOnDeviceRecognition", arguments)
      XCTAssertEqual(
        (answer as? FlutterError)?.code, "invalid_args",
        "expected an error; a false here would read as a real capability gap")
    }
  }

  func testAnUnknownMethodIsStillNotImplemented() throws {
    let answer = try invoke("someMethodThatDoesNotExist")
    XCTAssertTrue(
      answer as AnyObject === FlutterMethodNotImplemented as AnyObject,
      "the default arm still reports not-implemented")
  }
}
