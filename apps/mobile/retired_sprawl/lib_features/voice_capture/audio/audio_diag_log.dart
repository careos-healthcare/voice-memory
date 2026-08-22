import 'package:archiveme_mobile/security/release_logger.dart';
import 'package:archiveme_mobile/security/release_log_sanitizer.dart';
import 'package:flutter/foundation.dart';

/// Debug logging for captured audio files — filter with `ARCHIVEME_AUDIO_`.
abstract class AudioDiagLog {
  AudioDiagLog._();

  static void recorderConfig({
    required String encoder,
    required int sampleRate,
    required int numChannels,
    required int bitRate,
    required String containerExtension,
  }) {
    debugPrint(
      'ARCHIVEME_AUDIO_RECORDER_CONFIG encoder=$encoder '
      'sampleRate=$sampleRate bitRate=$bitRate '
      'channels=$numChannels format=$containerExtension',
    );
  }

  static void capturedFile({
    required String path,
    required bool exists,
    required int bytes,
    required String extension,
    required int? durationMs,
    required String mimeGuess,
    required String firstBytesHex,
  }) {
    if (kReleaseMode) {
      debugPrint(
        'ARCHIVEME_AUDIO_DIAG exists=$exists bytesBucket=${_bytesBucket(bytes)}',
      );
      return;
    }
    debugPrint('ARCHIVEME_AUDIO_DIAG path=$path');
    debugPrint('ARCHIVEME_AUDIO_DIAG exists=$exists');
    debugPrint('ARCHIVEME_AUDIO_DIAG bytes=$bytes');
    debugPrint('ARCHIVEME_AUDIO_DIAG extension=$extension');
    debugPrint('ARCHIVEME_AUDIO_DIAG durationMs=${durationMs ?? 'unknown'}');
    debugPrint('ARCHIVEME_AUDIO_DIAG mimeGuess=$mimeGuess');
    debugPrint('ARCHIVEME_AUDIO_DIAG firstBytes=$firstBytesHex');
  }

  static void upload({
    required String fileName,
    required String contentType,
    required int bytes,
  }) {
    if (kReleaseMode) {
      debugPrint(
        'ARCHIVEME_TRANSCRIPTION_UPLOAD bytesBucket=${_bytesBucket(bytes)}',
      );
      return;
    }
    debugPrint(
      'ARCHIVEME_TRANSCRIPTION_UPLOAD fileName=$fileName '
      'contentType=$contentType bytes=$bytes',
    );
  }

  static void playbackStarted() {
    debugPrint('ARCHIVEME_AUDIO_PLAYBACK_STARTED');
  }

  static void playbackFailed({required String reason}) {
    ReleaseLogger.logFailure(
      event: 'audio_playback_failed',
      category: ReleaseLogCategory.capture,
      errorCode: reason,
    );
  }

  static void iosAudioSession({
    required bool configured,
    required String category,
    required String mode,
    double? sampleRate,
    int? inputChannels,
    double? outputVolume,
    String? detail,
  }) {
    debugPrint(
      'ARCHIVEME_IOS_AUDIO_SESSION configured=$configured '
      'category=$category mode=$mode'
      '${sampleRate == null ? '' : ' sampleRate=$sampleRate'}'
      '${inputChannels == null ? '' : ' inputChannels=$inputChannels'}'
      '${outputVolume == null ? '' : ' outputVolume=$outputVolume'}'
      '${detail == null ? '' : ' detail=$detail'}',
    );
  }

  static void iosAudioRoute({required String inputs, required String outputs}) {
    debugPrint('ARCHIVEME_IOS_AUDIO_ROUTE inputs=$inputs outputs=$outputs');
  }

  static void iosAudioInput({
    required String portName,
    required String portType,
  }) {
    debugPrint('ARCHIVEME_IOS_AUDIO_INPUT selected=$portName type=$portType');
  }

  static void iosAudioAvailableInputs({
    required int count,
    required String names,
  }) {
    debugPrint(
      'ARCHIVEME_IOS_AUDIO_AVAILABLE_INPUTS count=$count names=$names',
    );
  }

  static void level({
    required double currentDb,
    required double minDb,
    required double maxDb,
    required double avgDb,
  }) {
    debugPrint(
      'ARCHIVEME_AUDIO_LEVEL currentDb=$currentDb minDb=$minDb '
      'maxDb=$maxDb avgDb=$avgDb',
    );
  }

  static void levelSummary({
    required double minDb,
    required double maxDb,
    required double avgDb,
    required int sampleCount,
    required bool likelySilent,
  }) {
    debugPrint(
      'ARCHIVEME_AUDIO_LEVEL_SUMMARY minDb=$minDb maxDb=$maxDb avgDb=$avgDb '
      'sampleCount=$sampleCount likelySilent=$likelySilent',
    );
  }

  static void silenceRetry({required String reason, required double oldMaxDb}) {
    debugPrint(
      'ARCHIVEME_AUDIO_SILENCE_RETRY reason=$reason oldMaxDb=$oldMaxDb',
    );
  }

  static void silenceRetryStarted({required String mode}) {
    debugPrint('ARCHIVEME_AUDIO_SILENCE_RETRY_STARTED mode=$mode');
  }

  static void share({
    required String path,
    required bool exists,
    required int bytes,
  }) {
    if (kReleaseMode) {
      debugPrint(
        'ARCHIVEME_AUDIO_SHARE exists=$exists bytesBucket=${_bytesBucket(bytes)}',
      );
      return;
    }
    debugPrint('ARCHIVEME_AUDIO_SHARE path=$path exists=$exists bytes=$bytes');
  }

  /// Free-form record-flow trace. Debug builds only: callers pass interpolated
  /// exception text, which must not reach a release log.
  static void recordingMessage(String message) {
    if (kReleaseMode) return;
    debugPrint('ARCHIVEME_AUDIO_RECORD $message');
  }

  /// Stack trace for a failed capture operation. Callers already guard on
  /// [kDebugMode]; this repeats the check so a release caller cannot leak one.
  static void operationStackTrace({
    required String operation,
    required StackTrace stackTrace,
  }) {
    if (kReleaseMode) return;
    final code = ReleaseLogSanitizer.sanitizeReasonCode(operation) ?? 'unknown';
    debugPrint('ARCHIVEME_AUDIO_OPERATION_FAILED operation=$code');
    debugPrint('$stackTrace');
  }

  /// Mic route health. [selected] is a device-supplied port name, so it is held
  /// back in release builds while the verdict itself still ships.
  static void micInputHealth({
    required String selected,
    required bool likelySilent,
    required String recommendation,
  }) {
    final code =
        ReleaseLogSanitizer.sanitizeReasonCode(recommendation) ?? 'none';
    if (kReleaseMode) {
      debugPrint(
        'ARCHIVEME_AUDIO_MIC_INPUT_HEALTH likelySilent=$likelySilent '
        'recommendation=$code',
      );
      return;
    }
    debugPrint(
      'ARCHIVEME_AUDIO_MIC_INPUT_HEALTH selected=$selected '
      'likelySilent=$likelySilent recommendation=$code',
    );
  }

  static void nativeRecorderFailed({
    required String step,
    required String reason,
    String? format,
  }) {
    debugPrint(
      'ARCHIVEME_NATIVE_RECORDER_FAILED step=$step reason=$reason'
      '${format == null ? '' : ' format=$format'}',
    );
  }

  static String _bytesBucket(int bytes) {
    if (bytes < 1024) return 'lt_1kb';
    if (bytes < 64 * 1024) return 'lt_64kb';
    if (bytes < 1024 * 1024) return 'lt_1mb';
    return 'gte_1mb';
  }
}
