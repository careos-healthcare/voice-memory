import 'dart:io';

import 'package:archiveme_mobile/features/voice_capture/transcription/speech_locale.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/transcription_log.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The Dart half of `archive_me/native_speech_transcription`.
///
/// `locale` is a required, non-nullable [ConfirmedSpeechLocale] because the
/// Swift handler refuses the call without one — see the `localeNotSpecified`
/// guard at the top of `IosNativeSpeechTranscription.transcribe`. Before this
/// was typed, the Dart side simply never sent the key and every call came back
/// `{transcript: "", reason: "locale_not_specified"}`, which the caller read as
/// "no transcript available" and silently dropped. A required parameter of a
/// type that cannot be conjured out of a device setting is what stops that
/// returning.
abstract class NativeSpeechTranscriptionPlatform {
  Future<Map<Object?, Object?>?> transcribeFile({
    required String audioPath,
    required bool preferOnDevice,
    required ConfirmedSpeechLocale locale,
  });

  /// Whether `SFSpeechRecognizer` can recognise [locale] without a network.
  ///
  /// Answering "not implemented" is allowed and means "no opinion": callers
  /// must treat a thrown [MissingPluginException] as absence of evidence, not
  /// as a capability gap.
  Future<bool> supportsOnDeviceRecognition({
    required ConfirmedSpeechLocale locale,
  });

  /// Every locale identifier `SFSpeechRecognizer` reports on this device.
  ///
  /// This is a capability list — which languages the recogniser can decode —
  /// and says nothing about which language the customer speaks. It widens
  /// what [SpeechLocaleCatalog] can offer; it is never an answer to "which
  /// language is this recording in".
  ///
  /// Throwing is allowed and means "no opinion", the same as above: a build
  /// whose native side predates the `supportedLocales` case raises
  /// [MissingPluginException], and callers fall back to the curated list.
  Future<List<String>> supportedLocales();
}

class MethodChannelNativeSpeechTranscriptionPlatform
    implements NativeSpeechTranscriptionPlatform {
  MethodChannelNativeSpeechTranscriptionPlatform({MethodChannel? channel})
    : _channel = channel ??
          const MethodChannel(NativeSpeechTranscription.channelName);

  final MethodChannel _channel;

  @override
  Future<Map<Object?, Object?>?> transcribeFile({
    required String audioPath,
    required bool preferOnDevice,
    required ConfirmedSpeechLocale locale,
  }) async {
    final result = await _channel.invokeMethod<Object?>(
      'transcribeFile',
      {
        'audioPath': audioPath,
        'preferOnDevice': preferOnDevice,
        'localeIdentifier': locale.identifier,
      },
    );
    if (result is Map) return result;
    return null;
  }

  @override
  Future<bool> supportsOnDeviceRecognition({
    required ConfirmedSpeechLocale locale,
  }) async {
    final result = await _channel.invokeMethod<Object?>(
      'supportsOnDeviceRecognition',
      {'localeIdentifier': locale.identifier},
    );
    if (result is bool) return result;
    if (result is Map) {
      final supported = result['supportsOnDeviceRecognition'];
      if (supported is bool) return supported;
    }
    throw MissingPluginException(
      'supportsOnDeviceRecognition returned no answer',
    );
  }

  @override
  Future<List<String>> supportedLocales() async {
    final result = await _channel.invokeMethod<Object?>('supportedLocales');
    if (result is List) {
      return [
        for (final entry in result)
          if (entry is String && entry.trim().isNotEmpty) entry.trim(),
      ];
    }
    throw MissingPluginException('supportedLocales returned no answer');
  }
}

/// On-device platform speech recognition.
///
/// iOS only. Android is deliberately excluded and must stay that way until
/// someone implements `SpeechRecognizer.createOnDeviceSpeechRecognizer`
/// (API 31+), which accepts an audio file directly.
///
/// The previous Android implementation had no way to feed a recorded file to
/// `SpeechRecognizer`, so it played the recording out loud through the speaker
/// while the microphone recognizer listened. That played a private
/// mental-health reflection into whatever room the phone was in, and because
/// `EXTRA_PREFER_OFFLINE` is only a hint, on a device with no offline
/// recognizer installed it also streamed that audio to Google. See
/// `android/app/src/main/kotlin/com/voicememory/mobile/NativeSpeechTranscription.kt`,
/// which now refuses the call outright.
abstract final class NativeSpeechTranscription {
  NativeSpeechTranscription._();

  static const channelName = 'archive_me/native_speech_transcription';

  /// Platforms that must never reach the native speech channel, whatever else
  /// is configured — including [testPlatform].
  static const blockedPlatforms = {'android'};

  @visibleForTesting
  static NativeSpeechTranscriptionPlatform? testPlatform;

  /// Lets host-VM tests exercise per-platform behaviour without a device.
  @visibleForTesting
  static String? debugPlatformOverride;

  static NativeSpeechTranscriptionPlatform get platform =>
      testPlatform ?? MethodChannelNativeSpeechTranscriptionPlatform();

  static String get _platformName {
    final override = debugPlatformOverride;
    if (override != null) return override;
    if (kIsWeb) return 'web';
    return Platform.operatingSystem;
  }

  static bool get isSupported {
    if (blockedPlatforms.contains(_platformName)) return false;
    if (testPlatform != null) return true;
    return _platformName == 'ios';
  }

  /// Returns trimmed transcript text, or null when native STT produced none.
  ///
  /// Null covers every uncertain outcome the Swift side reports — a refused
  /// locale, a truncated recognition, an unverifiable one, a timeout. Those
  /// arrive as an empty transcript plus a reason code precisely so that
  /// uncertain output cannot become quotable text, and this method preserves
  /// that by never synthesising a partial result.
  static Future<String?> transcribeFile(
    File audioFile, {
    required ConfirmedSpeechLocale locale,
    bool preferOnDevice = true,
  }) async {
    if (!isSupported || !audioFile.existsSync()) return null;
    TranscriptionLog.mode('native_file_stt_start');
    try {
      final payload = await platform.transcribeFile(
        audioPath: audioFile.path,
        preferOnDevice: preferOnDevice,
        locale: locale,
      );
      final transcript = payload?['transcript']?.toString().trim() ?? '';
      if (transcript.isEmpty) {
        final reason = payload?['reason']?.toString() ?? 'empty_native_transcript';
        TranscriptionLog.failed(reason: reason);
        return null;
      }
      TranscriptionLog.success(transcriptLength: transcript.length);
      return transcript;
    } on PlatformException catch (error) {
      TranscriptionLog.failed(reason: 'native_stt:${error.code}');
      return null;
    } catch (error) {
      TranscriptionLog.failed(reason: 'native_stt:$error');
      return null;
    }
  }

  /// Locale identifiers this device's recogniser reports, or empty when it has
  /// no answer to give.
  ///
  /// Empty means "fall back to [SpeechLocaleCatalog.offered]", never "this
  /// device recognises no languages" — an older build without the
  /// `supportedLocales` case and a platform with no recogniser both land here,
  /// and emptying the picker would remove the choice this exists to widen.
  static Future<List<String>> supportedLocaleIdentifiers() async {
    if (!isSupported) return const [];
    try {
      return await platform.supportedLocales();
    } on Object {
      // ignore: silent_catch_audit — a device that cannot answer which
      // languages it knows is not a device that knows none.
      return const [];
    }
  }
}
