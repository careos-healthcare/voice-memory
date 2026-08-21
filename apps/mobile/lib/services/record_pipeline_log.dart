import 'package:archiveme_mobile/security/release_logger.dart';
import 'package:archiveme_mobile/security/release_log_sanitizer.dart';
import 'package:flutter/foundation.dart';

/// Release-safe logging for the voice capture pipeline.
abstract class RecordPipelineLog {
  RecordPipelineLog._();

  static void log(String message) {
    if (kDebugMode) {
      debugPrint('ARCHIVEME_RECORD_PIPELINE: $message');
    }
  }

  static void permission({required String status}) {
    ReleaseLogger.emit(
      event: 'capture_permission',
      category: ReleaseLogCategory.permission,
      fields: {
        'success': true,
        'status': ReleaseLogSanitizer.sanitizeReasonCode(status),
      },
    );
  }

  static void microphonePermission({
    required String before,
    required String after,
    String prefix = 'check',
  }) {
    ReleaseLogger.emit(
      event: 'microphone_permission',
      category: ReleaseLogCategory.permission,
      fields: {
        'operation': ReleaseLogSanitizer.sanitizeReasonCode(prefix),
        'before_status': ReleaseLogSanitizer.sanitizeReasonCode(before),
        'after_status': ReleaseLogSanitizer.sanitizeReasonCode(after),
      },
    );
  }

  static void microphonePermissionRequestShown({required bool shown}) {
    ReleaseLogger.emit(
      event: 'microphone_permission_request',
      category: ReleaseLogCategory.permission,
      fields: {'shown': shown},
    );
  }

  static void microphonePermissionBlocked({required bool blocked}) {
    ReleaseLogger.emit(
      event: 'microphone_permission_blocked',
      category: ReleaseLogCategory.permission,
      severity: ReleaseLogSeverity.warn,
      fields: {'blocked': blocked},
    );
  }

  static void recorderStart({required bool success, String? detail}) {
    ReleaseLogger.emit(
      event: 'recorder_start',
      category: ReleaseLogCategory.capture,
      fields: {'success': success},
    );
    if (detail != null) {
      ReleaseLogger.debugDetail(
        event: 'recorder_start_detail',
        category: ReleaseLogCategory.capture,
        fields: {'detail': detail},
      );
    }
  }

  static void audioFile({
    required String path,
    required bool exists,
    required int byteLength,
  }) {
    ReleaseLogger.emit(
      event: 'capture_audio_file',
      category: ReleaseLogCategory.capture,
      fields: {
        'exists': exists,
        'bytes_bucket': ReleaseLogSanitizer.bytesBucket(byteLength),
      },
    );
    ReleaseLogger.debugDetail(
      event: 'capture_audio_file_detail',
      category: ReleaseLogCategory.capture,
      fields: {'path': path, 'byte_length': byteLength},
    );
  }

  static void transcriptLengths({
    required int transcriptLength,
    required int bodyLength,
    required int observationLength,
    required int exactLanguageLength,
  }) {
    ReleaseLogger.emit(
      event: 'capture_transcript_lengths',
      category: ReleaseLogCategory.capture,
      fields: {
        'transcript_length_bucket':
            ReleaseLogSanitizer.lengthBucket(transcriptLength),
        'body_length_bucket': ReleaseLogSanitizer.lengthBucket(bodyLength),
        'observation_length_bucket':
            ReleaseLogSanitizer.lengthBucket(observationLength),
        'exact_language_length_bucket':
            ReleaseLogSanitizer.lengthBucket(exactLanguageLength),
      },
    );
  }

  static void savedEntry({
    required String entryId,
    required int displayTextLength,
  }) {
    ReleaseLogger.emit(
      event: 'capture_saved',
      category: ReleaseLogCategory.capture,
      fields: {
        'success': true,
        'display_text_length_bucket':
            ReleaseLogSanitizer.lengthBucket(displayTextLength),
      },
    );
    ReleaseLogger.debugDetail(
      event: 'capture_saved_detail',
      category: ReleaseLogCategory.capture,
      fields: {'entry_id': entryId},
    );
  }

  static void rejectInsufficientAudio({required int byteLength}) {
    ReleaseLogger.emit(
      event: 'capture_reject_insufficient_audio',
      category: ReleaseLogCategory.capture,
      severity: ReleaseLogSeverity.warn,
      fields: {
        'success': false,
        'bytes_bucket': ReleaseLogSanitizer.bytesBucket(byteLength),
        'error_code': 'insufficient_audio',
      },
    );
  }

  static void apiGuardBlocked({
    required String operation,
    required String reason,
  }) {
    ReleaseLogger.emit(
      event: 'capture_api_guard_blocked',
      category: ReleaseLogCategory.capture,
      severity: ReleaseLogSeverity.warn,
      fields: {
        'operation': ReleaseLogSanitizer.sanitizeReasonCode(operation),
        'error_code': ReleaseLogSanitizer.sanitizeReasonCode(reason),
      },
    );
  }

  static void preSaveFinalTranscript({required int length}) {
    ReleaseLogger.emit(
      event: 'capture_presave_transcript',
      category: ReleaseLogCategory.capture,
      fields: {
        'transcript_length_bucket': ReleaseLogSanitizer.lengthBucket(length),
      },
    );
  }

  static void persistedCaptureText({
    required int transcriptLength,
    required int bodyLength,
    required String displayTextSource,
  }) {
    ReleaseLogger.emit(
      event: 'capture_persisted',
      category: ReleaseLogCategory.capture,
      fields: {
        'transcript_length_bucket':
            ReleaseLogSanitizer.lengthBucket(transcriptLength),
        'body_length_bucket': ReleaseLogSanitizer.lengthBucket(bodyLength),
        'display_text_source':
            ReleaseLogSanitizer.sanitizeReasonCode(displayTextSource),
      },
    );
  }

  static void voiceSavedTranscriptMissing() {
    ReleaseLogger.emit(
      event: 'capture_voice_transcript_missing',
      category: ReleaseLogCategory.capture,
      severity: ReleaseLogSeverity.warn,
      fields: {'missing': true},
    );
  }

  static void voiceSavedTranscriptPresent() {
    ReleaseLogger.emit(
      event: 'capture_voice_transcript_present',
      category: ReleaseLogCategory.capture,
      fields: {'missing': false},
    );
  }

  static void typedTextAttachedToVoiceEntry({required String entryId}) {
    ReleaseLogger.emit(
      event: 'capture_typed_text_attached',
      category: ReleaseLogCategory.capture,
      fields: {'attached': true},
    );
    ReleaseLogger.debugDetail(
      event: 'capture_typed_text_attached_detail',
      category: ReleaseLogCategory.capture,
      fields: {'entry_id': entryId},
    );
  }

  static void typedFallbackInsightShown() {
    ReleaseLogger.emit(
      event: 'capture_typed_fallback_insight',
      category: ReleaseLogCategory.capture,
      fields: {'shown': true},
    );
  }

  static void transcriptionFallback({
    required String reason,
    required String audioPath,
  }) {
    ReleaseLogger.emit(
      event: 'capture_transcription_fallback',
      category: ReleaseLogCategory.transcription,
      severity: ReleaseLogSeverity.warn,
      fields: {
        'error_code': ReleaseLogSanitizer.sanitizeReasonCode(reason),
      },
    );
    ReleaseLogger.debugDetail(
      event: 'capture_transcription_fallback_detail',
      category: ReleaseLogCategory.transcription,
      fields: {'audio_path': audioPath},
    );
  }

  static void analysisFailed({required String reason}) {
    ReleaseLogger.logFailure(
      event: 'capture_analysis_failed',
      category: ReleaseLogCategory.analysis,
      errorCode: reason,
    );
  }

  static void analysisFallback({
    required String reason,
    required String audioPath,
  }) {
    ReleaseLogger.emit(
      event: 'capture_analysis_fallback',
      category: ReleaseLogCategory.analysis,
      severity: ReleaseLogSeverity.warn,
      fields: {
        'error_code': ReleaseLogSanitizer.sanitizeReasonCode(reason),
      },
    );
    ReleaseLogger.debugDetail(
      event: 'capture_analysis_fallback_detail',
      category: ReleaseLogCategory.analysis,
      fields: {'audio_path': audioPath},
    );
  }

  static void postSaveComparisonSkipped({required String reason}) {
    ReleaseLogger.emit(
      event: 'capture_post_save_comparison_skipped',
      category: ReleaseLogCategory.capture,
      fields: {
        'error_code': ReleaseLogSanitizer.sanitizeReasonCode(reason),
      },
    );
  }

  static void micPermissionDebug(String message) {
    ReleaseLogger.debugDetail(
      event: 'microphone_permission_debug',
      category: ReleaseLogCategory.permission,
      fields: {'message': message},
    );
  }

  static void micPermissionNativeStatus({
    required String status,
    required bool granted,
  }) {
    ReleaseLogger.emit(
      event: 'microphone_native_status',
      category: ReleaseLogCategory.permission,
      fields: {
        'granted': granted,
        'status': ReleaseLogSanitizer.sanitizeReasonCode(status),
      },
    );
  }

  static void micPermissionNativeResolved({required String resolved}) {
    ReleaseLogger.emit(
      event: 'microphone_native_resolved',
      category: ReleaseLogCategory.permission,
      fields: {
        'resolved': ReleaseLogSanitizer.sanitizeReasonCode(resolved),
      },
    );
  }

  static void micPermissionNativeAction({required String action}) {
    ReleaseLogger.emit(
      event: 'microphone_native_action',
      category: ReleaseLogCategory.permission,
      fields: {
        'action': ReleaseLogSanitizer.sanitizeReasonCode(action),
      },
    );
  }

  static void micPermissionNativeRequestResult({
    required bool granted,
    required String status,
  }) {
    ReleaseLogger.emit(
      event: 'microphone_native_request_result',
      category: ReleaseLogCategory.permission,
      fields: {
        'granted': granted,
        'status': ReleaseLogSanitizer.sanitizeReasonCode(status),
      },
    );
  }

  static void micPermissionResult({
    required String channel,
    required String detail,
  }) {
    ReleaseLogger.emit(
      event: 'microphone_permission_result',
      category: ReleaseLogCategory.permission,
      fields: {
        'channel': ReleaseLogSanitizer.sanitizeReasonCode(channel),
      },
    );
    ReleaseLogger.debugDetail(
      event: 'microphone_permission_result_detail',
      category: ReleaseLogCategory.permission,
      fields: {'detail': detail},
    );
  }

  static void recorderStop({required bool success}) {
    ReleaseLogger.emit(
      event: 'recorder_stop',
      category: ReleaseLogCategory.capture,
      fields: {'success': success},
    );
  }

  static void localSaveStarted({required String kind}) {
    ReleaseLogger.emit(
      event: 'capture_local_save_started',
      category: ReleaseLogCategory.capture,
      fields: {'kind': ReleaseLogSanitizer.sanitizeReasonCode(kind)},
    );
  }

  static void localSaveCompleted({required bool success, required String kind}) {
    ReleaseLogger.emit(
      event: 'capture_local_save_completed',
      category: ReleaseLogCategory.capture,
      fields: {
        'success': success,
        'kind': ReleaseLogSanitizer.sanitizeReasonCode(kind),
      },
    );
  }

  static void remoteProcessingStarted({required String kind}) {
    ReleaseLogger.emit(
      event: 'capture_remote_started',
      category: ReleaseLogCategory.capture,
      fields: {'kind': ReleaseLogSanitizer.sanitizeReasonCode(kind)},
    );
  }

  static void remoteProcessingCompleted({
    required bool success,
    required String kind,
  }) {
    ReleaseLogger.emit(
      event: 'capture_remote_completed',
      category: ReleaseLogCategory.capture,
      fields: {
        'success': success,
        'kind': ReleaseLogSanitizer.sanitizeReasonCode(kind),
      },
    );
  }

  static void illegalCaptureTransition({
    required String from,
    required String to,
  }) {
    ReleaseLogger.emit(
      event: 'capture_illegal_transition',
      category: ReleaseLogCategory.capture,
      severity: ReleaseLogSeverity.warn,
      fields: {
        'from_phase': ReleaseLogSanitizer.sanitizeReasonCode(from),
        'to_phase': ReleaseLogSanitizer.sanitizeReasonCode(to),
      },
    );
  }

  static void recoverableCaptureFailure({
    required String reason,
    required bool hasLocalSave,
  }) {
    ReleaseLogger.emit(
      event: 'capture_recoverable_failure',
      category: ReleaseLogCategory.capture,
      severity: ReleaseLogSeverity.warn,
      fields: {
        'error_code': ReleaseLogSanitizer.sanitizeReasonCode(reason),
        'has_local_save': hasLocalSave,
      },
    );
  }

  /// Post-save background work that must not block capture (embedding index,
  /// related-source lookup, etc.).
  static void backgroundProcessingFailed({
    required String operation,
    required Object error,
  }) {
    ReleaseLogger.emit(
      event: 'capture_background_processing_failed',
      category: ReleaseLogCategory.capture,
      severity: ReleaseLogSeverity.warn,
      fields: {
        'success': false,
        'operation': ReleaseLogSanitizer.sanitizeReasonCode(operation),
        'error_code': ReleaseLogSanitizer.errorCodeFromObject(error),
      },
    );
  }
}
