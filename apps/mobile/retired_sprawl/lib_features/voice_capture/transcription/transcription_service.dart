import 'dart:io';

import 'package:archiveme_mobile/api/api_exceptions.dart';
import 'package:archiveme_mobile/core/network/api_failure.dart';
import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/core/network/network_cancel_token.dart';
import 'package:archiveme_mobile/data/repositories/capture_repository.dart';
import 'package:archiveme_mobile/features/voice_capture/audio/capture_audio_compressor.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/native_speech_transcription.dart';
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

  /// On-device platform speech recognition (offline fallback).
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

/// Voice transcription — server-first with native offline fallback.
abstract class TranscriptionService {
  TranscriptionService._();

  static bool get localIosSpeechRecognitionImplemented =>
      NativeSpeechTranscription.isSupported;

  static TranscriptionMode activeMode({bool testStub = false}) {
    if (testStub) return TranscriptionMode.stubbed;
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
    NetworkCancelToken? cancelToken,
    bool testStub = false,
  }) async {
    final mode = activeMode(testStub: testStub);
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

      if (failure is ApiFailureOffline && NativeSpeechTranscription.isSupported) {
        final nativeTranscript = await NativeSpeechTranscription.transcribeFile(
          uploadFile,
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