import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../api/api_client.dart';
import '../../../api/api_exceptions.dart';
import '../../capture_api_retry/capture_api_retry_queue.dart';
import '../../../security/api_usage_guard.dart';
import '../../../security/api_response_safety.dart';
import 'on_device_transcription_engine.dart';
import 'transcript_quality.dart';
import 'transcription_connectivity.dart';
import 'transcription_log.dart';

/// How auto transcription is performed for a voice capture.
enum TranscriptionMode {
  /// Backend `/api/transcribe` — the only supported auto path today.
  server,

  /// On-device Whisper inference over the completed local WAV file.
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
    this.retryableCloudFailure = false,
    this.cloudIdempotencyKey,
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
    bool retryableCloudFailure = false,
    String? cloudIdempotencyKey,
  }) : this(
         mode: mode,
         attempted: true,
         failureReason: reason,
         speechPermissionStatus: speechPermissionStatus,
         retryableCloudFailure: retryableCloudFailure,
         cloudIdempotencyKey: cloudIdempotencyKey,
       );

  const TranscriptionOutcome.success({
    required TranscriptionMode mode,
    required String transcript,
    String? speechPermissionStatus,
    bool retryableCloudFailure = false,
    String? cloudIdempotencyKey,
  }) : this(
         mode: mode,
         attempted: true,
         transcript: transcript,
         speechPermissionStatus: speechPermissionStatus,
         retryableCloudFailure: retryableCloudFailure,
         cloudIdempotencyKey: cloudIdempotencyKey,
       );

  final TranscriptionMode mode;
  final bool attempted;
  final String? transcript;
  final String? failureReason;
  final String? skippedReason;
  final String? speechPermissionStatus;
  final bool retryableCloudFailure;
  final String? cloudIdempotencyKey;

  bool get succeeded => transcript != null && transcript!.trim().isNotEmpty;
}

/// Voice transcription orchestration with deterministic local fallback.
abstract class TranscriptionService {
  TranscriptionService._();

  static const bool localIosSpeechRecognitionImplemented = true;

  static TranscriptionMode activeMode({
    bool testStub = false,
    bool isOnline = true,
  }) {
    if (testStub) return TranscriptionMode.stubbed;
    return isOnline ? TranscriptionMode.server : TranscriptionMode.local;
  }

  static Future<String> speechPermissionStatusLabel() async {
    if (kIsWeb || !Platform.isIOS) return 'not_applicable';
    try {
      return (await Permission.speech.status).toString();
    } catch (e) {
      return 'unavailable:$e';
    }
  }

  static Future<TranscriptionOutcome> transcribeRecording({
    required File audioFile,
    required int durationSeconds,
    required VoiceCaptureApiClient api,
    required Future<String> Function({bool forceRefresh}) ensureCaptureToken,
    required String scopeKey,
    required ApiUsageGuard usageGuard,
    OnDeviceTranscriptionEngine? localEngine,
    TranscriptionConnectivity? connectivity,
    bool testStub = false,
  }) async {
    final speechStatus = await speechPermissionStatusLabel();
    TranscriptionLog.permission(status: speechStatus);

    if (!audioFile.existsSync()) {
      const reason = 'audio_file_missing';
      TranscriptionLog.failed(reason: reason);
      return TranscriptionOutcome.failed(
        mode: TranscriptionMode.disabled,
        reason: reason,
        speechPermissionStatus: speechStatus,
      );
    }

    TranscriptionLog.started(audioPath: audioFile.path);

    final network = connectivity ?? PlatformTranscriptionConnectivity();
    final onDevice = localEngine ?? WhisperOnDeviceTranscriptionEngine();
    bool online;
    try {
      online = await network.isOnline();
    } catch (_) {
      online = false;
    }
    final mode = activeMode(testStub: testStub, isOnline: online);
    TranscriptionLog.mode(mode.logLabel);
    final idempotencyKey = usageGuard.idempotencyKey(
      scopeKey: scopeKey,
      operation: ApiUsageOperation.transcribe,
    );

    if (!online) {
      return _transcribeLocally(
        engine: onDevice,
        audioFile: audioFile,
        speechPermissionStatus: speechStatus,
        cloudFailure: NetworkOfflineException(),
        cloudIdempotencyKey: idempotencyKey,
      );
    }

    final guard = usageGuard.checkAttempt(
      scopeKey: scopeKey,
      operation: ApiUsageOperation.transcribe,
    );
    if (!guard.allowed) {
      final reason = guard.reason ?? 'api_guard_blocked';
      TranscriptionLog.skipped(reason: reason);
      return _transcribeLocally(
        engine: onDevice,
        audioFile: audioFile,
        speechPermissionStatus: speechStatus,
        cloudFailureReason: reason,
      );
    }

    try {
      var token = await ensureCaptureToken();
      final transcript = await _requestTranscript(
        api: api,
        audioFile: audioFile,
        durationSeconds: durationSeconds,
        captureToken: token,
        idempotencyKey: idempotencyKey,
      );
      usageGuard.recordAttempt(
        scopeKey: scopeKey,
        operation: ApiUsageOperation.transcribe,
        success: true,
      );
      return _successOutcome(
        mode: TranscriptionMode.server,
        transcript: transcript,
        speechPermissionStatus: speechStatus,
      );
    } on AuthRequiredException {
      try {
        final token = await ensureCaptureToken(forceRefresh: true);
        final transcript = await _requestTranscript(
          api: api,
          audioFile: audioFile,
          durationSeconds: durationSeconds,
          captureToken: token,
          idempotencyKey: idempotencyKey,
        );
        usageGuard.recordAttempt(
          scopeKey: scopeKey,
          operation: ApiUsageOperation.transcribe,
          success: true,
        );
        return _successOutcome(
          mode: mode,
          transcript: transcript,
          speechPermissionStatus: speechStatus,
        );
      } catch (e) {
        usageGuard.recordAttempt(
          scopeKey: scopeKey,
          operation: ApiUsageOperation.transcribe,
          success: false,
        );
        return _transcribeLocally(
          engine: onDevice,
          audioFile: audioFile,
          speechPermissionStatus: speechStatus,
          cloudFailure: e,
          cloudIdempotencyKey: idempotencyKey,
        );
      }
    } catch (e) {
      usageGuard.recordAttempt(
        scopeKey: scopeKey,
        operation: ApiUsageOperation.transcribe,
        success: false,
      );
      return _transcribeLocally(
        engine: onDevice,
        audioFile: audioFile,
        speechPermissionStatus: speechStatus,
        cloudFailure: e,
        cloudIdempotencyKey: idempotencyKey,
      );
    }
  }

  static Future<TranscriptionOutcome> _transcribeLocally({
    required OnDeviceTranscriptionEngine engine,
    required File audioFile,
    required String speechPermissionStatus,
    String? cloudFailureReason,
    Object? cloudFailure,
    String? cloudIdempotencyKey,
  }) async {
    TranscriptionLog.mode(TranscriptionMode.local.logLabel);
    try {
      final transcript = await engine.transcribe(audioFile);
      return _successOutcome(
        mode: TranscriptionMode.local,
        transcript: transcript,
        speechPermissionStatus: speechPermissionStatus,
        retryableCloudFailure:
            cloudFailure != null &&
            classifyCaptureApiRetryFailure(cloudFailure) !=
                CaptureApiRetryFailure.permanent,
        cloudIdempotencyKey: cloudIdempotencyKey,
      );
    } catch (error) {
      final localReason = failureReason(error);
      final resolvedCloudReason = cloudFailure == null
          ? cloudFailureReason
          : failureReason(cloudFailure);
      final reason = resolvedCloudReason == null
          ? 'local:$localReason'
          : 'cloud:$resolvedCloudReason|local:$localReason';
      TranscriptionLog.failed(reason: reason);
      return TranscriptionOutcome.failed(
        mode: TranscriptionMode.local,
        reason: reason,
        speechPermissionStatus: speechPermissionStatus,
        retryableCloudFailure:
            cloudFailure != null &&
            classifyCaptureApiRetryFailure(cloudFailure) !=
                CaptureApiRetryFailure.permanent,
        cloudIdempotencyKey: cloudIdempotencyKey,
      );
    }
  }

  static Future<String> _requestTranscript({
    required VoiceCaptureApiClient api,
    required File audioFile,
    required int durationSeconds,
    required String captureToken,
    required String idempotencyKey,
  }) async {
    return api.postTranscribe(
      audioFile: audioFile,
      durationSeconds: durationSeconds,
      captureToken: captureToken,
      idempotencyKey: idempotencyKey,
    );
  }

  static TranscriptionOutcome _successOutcome({
    required TranscriptionMode mode,
    required String transcript,
    required String speechPermissionStatus,
    bool retryableCloudFailure = false,
    String? cloudIdempotencyKey,
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
      retryableCloudFailure: retryableCloudFailure,
      cloudIdempotencyKey: cloudIdempotencyKey,
    );
  }

  static String failureReason(Object error) {
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
