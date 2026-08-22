import 'dart:io';

import 'package:archiveme_mobile/api/api_exceptions.dart';
import 'package:archiveme_mobile/core/network/api_failure.dart';
import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/core/network/network_cancel_token.dart';
import 'package:archiveme_mobile/data/repositories/capture_repository.dart';
import 'package:archiveme_mobile/features/voice_capture/audio/capture_audio_compressor.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/native_speech_transcription.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/speech_locale.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/transcript_quality.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/transcription_log.dart';
import 'package:archiveme_mobile/security/api_response_safety.dart';
import 'package:archiveme_mobile/security/api_usage_guard.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// How auto transcription is performed for a voice capture.
enum TranscriptionMode {
  /// Backend `/api/transcribe`.
  server,

  /// On-device platform speech recognition.
  ///
  /// Reached two ways: as the primary path when the customer has on-device-only
  /// processing on, and as the fallback when a permitted upload finds the
  /// network gone. The first is the mode the privacy setting promises; it used
  /// to be unreachable, so a default iOS install produced no transcript at all.
  local,

  /// Auto transcription intentionally not attempted.
  disabled,

  /// Test doubles only.
  stubbed,
}

extension TranscriptionModeLabel on TranscriptionMode {
  String get logLabel => switch (this) {
    TranscriptionMode.server => 'server',
    TranscriptionMode.local => 'local',
    TranscriptionMode.disabled => 'disabled',
    TranscriptionMode.stubbed => 'stubbed',
  };
}

class TranscriptionOutcome {
  const TranscriptionOutcome({
    required this.mode,
    required this.attempted,
    this.transcript,
    this.failureReason,
    this.skippedReason,
    this.speechPermissionStatus,
    this.isProvisional = false,
    this.uploadAudioPath,
  });

  const TranscriptionOutcome.skipped({
    required TranscriptionMode mode,
    required String reason,
    String? speechPermissionStatus,
  }) : this(
         mode: mode,
         attempted: false,
         skippedReason: reason,
         speechPermissionStatus: speechPermissionStatus,
       );

  const TranscriptionOutcome.failed({
    required TranscriptionMode mode,
    required String reason,
    String? speechPermissionStatus,
  }) : this(
         mode: mode,
         attempted: true,
         failureReason: reason,
         speechPermissionStatus: speechPermissionStatus,
       );

  const TranscriptionOutcome.success({
    required TranscriptionMode mode,
    required String transcript,
    String? speechPermissionStatus,
    bool isProvisional = false,
    String? uploadAudioPath,
  }) : this(
         mode: mode,
         attempted: true,
         transcript: transcript,
         speechPermissionStatus: speechPermissionStatus,
         isProvisional: isProvisional,
         uploadAudioPath: uploadAudioPath,
       );

  final TranscriptionMode mode;
  final bool attempted;
  final String? transcript;
  final String? failureReason;
  final String? skippedReason;
  final String? speechPermissionStatus;
  final bool isProvisional;
  final String? uploadAudioPath;

  bool get succeeded => transcript != null && transcript!.trim().isNotEmpty;
}

/// Voice transcription — on-device first when the customer asked for that,
/// server otherwise, with a native fallback when a permitted upload goes
/// offline.
abstract class TranscriptionService {
  TranscriptionService._();

  static bool get localIosSpeechRecognitionImplemented =>
      NativeSpeechTranscription.isSupported;

  /// Which path this recording takes.
  ///
  /// [onDeviceOnly] is the customer's "Never send to server" setting. When it
  /// is on, the answer is [TranscriptionMode.local] and nothing in
  /// [transcribeRecording] reaches the network — not as a fallback, not on a
  /// local failure. When the platform has no local recogniser at all, the
  /// honest answer is [TranscriptionMode.disabled] rather than quietly
  /// upgrading to the server the customer just said not to use.
  static TranscriptionMode activeMode({
    bool testStub = false,
    bool onDeviceOnly = false,
  }) {
    if (testStub) return TranscriptionMode.stubbed;
    if (onDeviceOnly) {
      return NativeSpeechTranscription.isSupported
          ? TranscriptionMode.local
          : TranscriptionMode.disabled;
    }
    return TranscriptionMode.server;
  }

  static Future<String> speechPermissionStatusLabel() async {
    if (kIsWeb || !Platform.isIOS) return 'not_applicable';
    try {
      return (await Permission.speech.status).toString();
    } catch (e, stackTrace) {
      return 'unavailable:$e';
    }
  }

  static Future<TranscriptionOutcome> transcribeRecording({
    required File audioFile,
    required int durationSeconds,
    required CaptureRepository captureRepository,
    required Future<String> Function({bool forceRefresh}) ensureCaptureToken,
    required String scopeKey,
    required ApiUsageGuard usageGuard,

    /// The language the customer confirmed they speak, or null when they have
    /// not been asked yet.
    ///
    /// Required-but-nullable on purpose. Every caller has to state an answer,
    /// and null is a real one meaning "do not run speech recognition" — never
    /// "work it out from the phone". A recogniser aimed at the wrong language
    /// returns fluent text that the pipeline stamps
    /// `TranscriptProvenance.speechToText` and the archive later quotes back as
    /// the customer's own words.
    required ConfirmedSpeechLocale? speechLocale,

    /// The customer's "Never send to server" setting.
    required bool onDeviceOnly,
    NetworkCancelToken? cancelToken,
    bool testStub = false,
  }) async {
    final mode = activeMode(testStub: testStub, onDeviceOnly: onDeviceOnly);
    TranscriptionLog.mode(mode.logLabel);

    final speechStatus = await speechPermissionStatusLabel();
    TranscriptionLog.permission(status: speechStatus);

    if (!audioFile.existsSync()) {
      const reason = 'audio_file_missing';
      TranscriptionLog.failed(reason: reason);
      return TranscriptionOutcome.failed(
        mode: mode,
        reason: reason,
        speechPermissionStatus: speechStatus,
      );
    }

    TranscriptionLog.started(audioPath: audioFile.path);

    if (mode == TranscriptionMode.disabled) {
      const reason = 'transcription_disabled';
      TranscriptionLog.skipped(reason: reason);
      return TranscriptionOutcome.skipped(
        mode: mode,
        reason: reason,
        speechPermissionStatus: speechStatus,
      );
    }

    if (mode == TranscriptionMode.local) {
      return _transcribeOnDevice(
        audioFile: audioFile,
        speechLocale: speechLocale,
        speechPermissionStatus: speechStatus,
      );
    }

    final compressed = await CaptureAudioCompressor.compressForUpload(audioFile);
    final uploadFile = compressed.file;

    final guard = usageGuard.checkAttempt(
      scopeKey: scopeKey,
      operation: ApiUsageOperation.transcribe,
    );
    if (!guard.allowed) {
      final reason = guard.reason ?? 'api_guard_blocked';
      TranscriptionLog.skipped(reason: reason);
      return TranscriptionOutcome.skipped(
        mode: mode,
        reason: reason,
        speechPermissionStatus: speechStatus,
      );
    }

    final idempotencyKey = usageGuard.idempotencyKey(
      scopeKey: scopeKey,
      operation: ApiUsageOperation.transcribe,
    );

    Future<ApiResult<String>> requestTranscript(String token) {
      return captureRepository.postTranscribe(
        audioFile: uploadFile,
        durationSeconds: durationSeconds,
        captureToken: token,
        idempotencyKey: idempotencyKey,
        cancelToken: cancelToken,
      );
    }

    var token = await ensureCaptureToken();
    var result = await requestTranscript(token);

    if (result case ApiFailureResult(
      :final failure,
    ) when failure is ApiFailureAuthRequired) {
      token = await ensureCaptureToken(forceRefresh: true);
      result = await requestTranscript(token);
    }

    if (result case ApiSuccess<String>(:final value)) {
      usageGuard.recordAttempt(
        scopeKey: scopeKey,
        operation: ApiUsageOperation.transcribe,
        success: true,
      );
      return _successOutcome(
        mode: TranscriptionMode.server,
        transcript: value,
        speechPermissionStatus: speechStatus,
        uploadAudioPath: uploadFile.path,
      );
    }

    if (result case ApiFailureResult(:final failure)) {
      usageGuard.recordAttempt(
        scopeKey: scopeKey,
        operation: ApiUsageOperation.transcribe,
        success: false,
      );
      final reason = failureReason(failure);
      TranscriptionLog.failed(reason: reason);

      if (failure is ApiFailureOffline &&
          NativeSpeechTranscription.isSupported &&
          speechLocale != null) {
        final nativeTranscript = await NativeSpeechTranscription.transcribeFile(
          uploadFile,
          locale: speechLocale,
        );
        if (nativeTranscript != null) {
          return _successOutcome(
            mode: TranscriptionMode.local,
            transcript: nativeTranscript,
            speechPermissionStatus: speechStatus,
            isProvisional: true,
            uploadAudioPath: uploadFile.path,
          );
        }
      }

      return TranscriptionOutcome.failed(
        mode: mode,
        reason: reason,
        speechPermissionStatus: speechStatus,
      );
    }

    return TranscriptionOutcome.failed(
      mode: mode,
      reason: 'transcription_unexpected',
      speechPermissionStatus: speechStatus,
    );
  }

  /// The primary path when "Never send to server" is on.
  ///
  /// Terminates either way. There is no fall-through to the network on failure,
  /// because the setting that put us here is the customer saying the recording
  /// must not leave the device, and a local recogniser that could not read it
  /// does not change that.
  static Future<TranscriptionOutcome> _transcribeOnDevice({
    required File audioFile,
    required ConfirmedSpeechLocale? speechLocale,
    required String speechPermissionStatus,
  }) async {
    if (speechLocale == null) {
      // Not a failure of the device. `TranscriptionCapabilityPolicy` turns this
      // into a one-time question, and the recording keeps its audio meanwhile.
      const reason = 'speech_language_not_confirmed';
      TranscriptionLog.skipped(reason: reason);
      return TranscriptionOutcome.skipped(
        mode: TranscriptionMode.local,
        reason: reason,
        speechPermissionStatus: speechPermissionStatus,
      );
    }

    final transcript = await NativeSpeechTranscription.transcribeFile(
      audioFile,
      locale: speechLocale,
    );
    if (transcript == null) {
      const reason = 'native_stt_unavailable';
      TranscriptionLog.failed(reason: reason);
      return TranscriptionOutcome.failed(
        mode: TranscriptionMode.local,
        reason: reason,
        speechPermissionStatus: speechPermissionStatus,
      );
    }

    // Not provisional. Provisional means "a better transcript is coming from
    // the server", and in this mode none ever is, so marking it provisional
    // would leave every entry permanently waiting on a request that will not
    // be made.
    return _successOutcome(
      mode: TranscriptionMode.local,
      transcript: transcript,
      speechPermissionStatus: speechPermissionStatus,
    );
  }

  static TranscriptionOutcome _successOutcome({
    required TranscriptionMode mode,
    required String transcript,
    required String speechPermissionStatus,
    bool isProvisional = false,
    String? uploadAudioPath,
  }) {
    final trimmed = transcript.trim();
    if (trimmed.isEmpty) {
      const reason = 'empty_transcript';
      TranscriptionLog.failed(reason: reason);
      return TranscriptionOutcome.failed(
        mode: mode,
        reason: reason,
        speechPermissionStatus: speechPermissionStatus,
      );
    }
    final quality = TranscriptQuality.evaluate(trimmed);
    if (!quality.isValid) {
      final reason = 'low_quality:${quality.reason ?? 'invalid'}';
      TranscriptionLog.lowQuality(
        transcriptLength: trimmed.length,
        reason: quality.reason ?? 'invalid',
      );
      return TranscriptionOutcome.failed(
        mode: mode,
        reason: reason,
        speechPermissionStatus: speechPermissionStatus,
      );
    }
    TranscriptionLog.success(transcriptLength: trimmed.length);
    return TranscriptionOutcome.success(
      mode: mode,
      transcript: trimmed,
      speechPermissionStatus: speechPermissionStatus,
      isProvisional: isProvisional,
      uploadAudioPath: uploadAudioPath,
    );
  }

  static String classifyFailureReason(Object error) => failureReason(error);

  @visibleForTesting
  static String failureReason(Object error) {
    if (error is ApiFailure) {
      final code = error.code;
      if (code.isNotEmpty) return '$code:${error.message}';
      return 'api_${error.statusCode ?? 0}:${error.message}';
    }
    if (error is FormatException &&
        error.message == ApiResponseSafety.htmlResponseMessage) {
      return 'wrong_api_host:html_response';
    }
    if (error is ApiException) {
      final code = error.code;
      if (code != null && code.isNotEmpty) return '$code:${error.message}';
      return 'api_${error.statusCode ?? 0}:${error.message}';
    }
    if (error is SocketException) {
      return 'network:${error.message}';
    }
    if (error is FormatException) {
      return 'format:${error.message}';
    }
    return error.toString();
  }
}