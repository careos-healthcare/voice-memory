import 'package:archiveme_mobile/features/voice_capture/transcription/native_speech_transcription.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/speech_locale.dart';
import 'package:flutter/services.dart';

/// A test double for the native speech channel that follows the Swift.
///
/// The fakes this replaces were written against the Dart signature, which at
/// the time omitted `localeIdentifier` entirely. They therefore agreed with the
/// caller about a message the real handler rejects, and every one of them
/// passed while a shipped iOS device returned `locale_not_specified` for every
/// recording ever made. A double is only worth having if disagreeing with the
/// platform makes it fail, so this one reproduces the decision tree in
/// `ios/Runner/IosNativeSpeechTranscription.swift` — including the outcomes
/// where the recogniser did produce text and the Swift side withholds it.
///
/// Every arm returns the wire shape `channelPayload` builds: a `transcript`
/// key, a `reason` key, and a `localeIdentifier` key, with a non-empty
/// transcript paired only with an empty reason.
class SwiftContractNativeSpeechPlatform
    implements NativeSpeechTranscriptionPlatform {
  SwiftContractNativeSpeechPlatform({
    this.transcript = 'I felt pressure before saying yes again today.',
    Set<String>? recognisableLanguages,
    Set<String>? onDeviceLanguages,
    this.recognizerAvailable = true,
    this.coverage = NativeSpeechCoverageVerdict.complete,
    this.resolvedLocaleOverride,
    this.probeThrows = false,
    this.supportedLocalesThrows = false,
    List<String>? deviceLocaleIdentifiers,
  }) : recognisableLanguages =
           recognisableLanguages ?? const {'en', 'es', 'fr', 'gu', 'hi'},
       onDeviceLanguages =
           onDeviceLanguages ?? const {'en', 'es', 'fr', 'gu', 'hi'},
       deviceLocaleIdentifiers =
           deviceLocaleIdentifiers ?? const ['en-US', 'es-ES', 'fr-FR'];

  /// What the recogniser would return if everything checks out.
  final String transcript;

  /// Primary language subtags `SFSpeechRecognizer(locale:)` resolves at all.
  final Set<String> recognisableLanguages;

  /// Subtags that additionally report `supportsOnDeviceRecognition`.
  final Set<String> onDeviceLanguages;

  final bool recognizerAvailable;
  final NativeSpeechCoverageVerdict coverage;

  /// Forces `recognizer.locale.identifier` to differ from what was requested,
  /// which is the `locale_mismatch` arm.
  final String? resolvedLocaleOverride;

  /// Makes the capability probe throw, as it does on a build whose Swift side
  /// has no `supportsOnDeviceRecognition` case yet.
  final bool probeThrows;

  /// Makes the locale query throw, as it does on a build whose Swift side has
  /// no `supportedLocales` case yet. Callers must fall back to the curated
  /// catalogue rather than showing an empty picker.
  final bool supportedLocalesThrows;

  /// What `SFSpeechRecognizer.supportedLocales()` reports on this "device".
  final List<String> deviceLocaleIdentifiers;

  final List<Map<String, Object?>> calls = [];
  final List<String> probedLocales = [];
  int supportedLocalesCallCount = 0;

  int get callCount => calls.length;

  @override
  Future<Map<Object?, Object?>?> transcribeFile({
    required String audioPath,
    required bool preferOnDevice,
    required ConfirmedSpeechLocale locale,
  }) async {
    calls.add({
      'audioPath': audioPath,
      'preferOnDevice': preferOnDevice,
      'localeIdentifier': locale.identifier,
    });

    if (!preferOnDevice) {
      return _failure('remote_recognition_refused', locale.identifier);
    }

    final requested = locale.primaryLanguageSubtag;
    if (!recognisableLanguages.contains(requested)) {
      return _failure('locale_unsupported', locale.identifier);
    }

    final resolved = resolvedLocaleOverride;
    if (resolved != null &&
        resolved.split('-').first.toLowerCase() != requested) {
      return _failure('locale_mismatch', resolved);
    }

    if (!onDeviceLanguages.contains(requested)) {
      return _failure('on_device_locale_unsupported', locale.identifier);
    }

    if (!recognizerAvailable) {
      return _failure('recognizer_unavailable', locale.identifier);
    }

    switch (coverage) {
      case NativeSpeechCoverageVerdict.truncated:
        return _failure('native_stt_truncated', locale.identifier);
      case NativeSpeechCoverageVerdict.unverifiable:
        return _failure('native_stt_coverage_unknown', locale.identifier);
      case NativeSpeechCoverageVerdict.timedOut:
        return _failure('native_stt_timeout', locale.identifier);
      case NativeSpeechCoverageVerdict.complete:
        break;
    }

    final trimmed = transcript.trim();
    if (trimmed.isEmpty) {
      return _failure('empty_native_transcript', locale.identifier);
    }
    return {
      'transcript': trimmed,
      'reason': '',
      'localeIdentifier': locale.identifier,
    };
  }

  @override
  Future<bool> supportsOnDeviceRecognition({
    required ConfirmedSpeechLocale locale,
  }) async {
    probedLocales.add(locale.identifier);
    if (probeThrows) {
      throw MissingPluginException('supportsOnDeviceRecognition');
    }
    return onDeviceLanguages.contains(locale.primaryLanguageSubtag);
  }

  @override
  Future<List<String>> supportedLocales() async {
    supportedLocalesCallCount += 1;
    if (supportedLocalesThrows) {
      throw MissingPluginException('supportedLocales');
    }
    return deviceLocaleIdentifiers;
  }

  static Map<Object?, Object?> _failure(String reason, String localeIdentifier) {
    // The Swift `channelPayload` hard-codes an empty transcript on the failure
    // arm, so an uncertain recognition can never reach the caller as text.
    return {
      'transcript': '',
      'reason': reason,
      'localeIdentifier': localeIdentifier,
    };
  }
}

/// Mirrors `NativeSpeechCoverage.Verdict` plus the deadline outcome.
enum NativeSpeechCoverageVerdict { complete, truncated, unverifiable, timedOut }
