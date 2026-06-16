import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../api/api_client.dart';
import '../../../api/api_exceptions.dart';
import '../../../security/api_usage_guard.dart';
import '../../../security/api_response_safety.dart';
import 'transcript_quality.dart';
import 'transcription_log.dart';

/// How auto transcription is performed for a voice capture.
enum TranscriptionMode {
  /// Backend `/api/transcribe` — the only supported auto path today.
  server,

  /// On-device iOS speech recognition — not implemented yet.
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
  }) : this(
         mode: mode,
         attempted: true,
         transcript: transcript,
         speechPermissionStatus: speechPermissionStatus,
       );

  final TranscriptionMode mode;
  final bool attempted;
  final String? transcript;
  final String? failureReason;
  final String? skippedReason;
  final String? speechPermissionStatus;

  bool get succeeded => transcript != null && transcript!.trim().isNotEmpty;
}

/// Voice transcription orchestration — server-side today; local iOS not wired.
abstract class TranscriptionService {
  TranscriptionService._();

  /// Native on-device speech recognition is not implemented in this app yet.
  static const bool localIosSpeechRecognitionImplemented = false;

  static TranscriptionMode activeMode({bool testStub = false}) {
    if (testStub) return TranscriptionMode.stubbed;
    if (!localIosSpeechRecognitionImplemented) return TranscriptionMode.server;
    return TranscriptionMode.local;
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
    required ApiClient api,
    required Future<String> Function({bool forceRefresh}) ensureCaptureToken,
    required String scopeKey,
    required ApiUsageGuard usageGuard,
    bool testStub = false,
  }) async {
    final mode = activeMode(testStub: testStub);
    TranscriptionLog.mode(mode.logLabel);
    if (!localIosSpeechRecognitionImplemented) {
      TranscriptionLog.mode('local_not_implemented');
    }

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
      const reason = 'local_ios_not_implemented';
      TranscriptionLog.skipped(reason: reason);
      return TranscriptionOutcome.skipped(
        mode: mode,
        reason: reason,
        speechPermissionStatus: speechStatus,
      );
    }

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
        mode: mode,
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
        final reason = failureReason(e);
        TranscriptionLog.failed(reason: reason);
        return TranscriptionOutcome.failed(
          mode: mode,
          reason: reason,
          speechPermissionStatus: speechStatus,
        );
      }
    } catch (e) {
      usageGuard.recordAttempt(
        scopeKey: scopeKey,
        operation: ApiUsageOperation.transcribe,
        success: false,
      );
      final reason = failureReason(e);
      TranscriptionLog.failed(reason: reason);
      return TranscriptionOutcome.failed(
        mode: mode,
        reason: reason,
        speechPermissionStatus: speechStatus,
      );
    }
  }

  static Future<String> _requestTranscript({
    required ApiClient api,
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
    );
  }

  @visibleForTesting
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
