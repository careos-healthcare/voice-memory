import 'package:archiveme_mobile/security/release_logger.dart';
import 'package:archiveme_mobile/security/release_log_sanitizer.dart';

/// Release-safe logging for voice transcription.
abstract class TranscriptionLog {
  TranscriptionLog._();

  static void started({required String audioPath}) {
    ReleaseLogger.emit(
      event: 'transcription_started',
      category: ReleaseLogCategory.transcription,
      fields: {'success': true},
    );
    ReleaseLogger.debugDetail(
      event: 'transcription_started_detail',
      category: ReleaseLogCategory.transcription,
      fields: {'audio_path': audioPath},
    );
  }

  static void mode(String mode) {
    ReleaseLogger.emit(
      event: 'transcription_mode',
      category: ReleaseLogCategory.transcription,
      fields: {
        'mode': ReleaseLogSanitizer.sanitizeReasonCode(mode),
      },
    );
  }

  static void permission({required String status}) {
    ReleaseLogger.emit(
      event: 'transcription_permission',
      category: ReleaseLogCategory.permission,
      fields: {
        'status': ReleaseLogSanitizer.sanitizeReasonCode(status),
      },
    );
  }

  static void success({required int transcriptLength}) {
    ReleaseLogger.emit(
      event: 'transcription_success',
      category: ReleaseLogCategory.transcription,
      fields: {
        'success': true,
        'transcript_length_bucket':
            ReleaseLogSanitizer.lengthBucket(transcriptLength),
      },
    );
  }

  static void failed({required String reason}) {
    ReleaseLogger.logFailure(
      event: 'transcription_failed',
      category: ReleaseLogCategory.transcription,
      errorCode: reason,
    );
  }

  static void lowQuality({
    required int transcriptLength,
    required String reason,
  }) {
    ReleaseLogger.emit(
      event: 'transcription_low_quality',
      category: ReleaseLogCategory.transcription,
      severity: ReleaseLogSeverity.warn,
      fields: {
        'transcript_length_bucket':
            ReleaseLogSanitizer.lengthBucket(transcriptLength),
        'error_code': ReleaseLogSanitizer.sanitizeReasonCode(reason),
      },
    );
  }

  static void skipped({required String reason}) {
    ReleaseLogger.emit(
      event: 'transcription_skipped',
      category: ReleaseLogCategory.transcription,
      fields: {
        'error_code': ReleaseLogSanitizer.sanitizeReasonCode(reason),
      },
    );
  }

  static void request({required String url}) {
    ReleaseLogger.emit(
      event: 'transcription_request',
      category: ReleaseLogCategory.network,
      fields: {'operation': 'transcribe'},
    );
    ReleaseLogger.debugDetail(
      event: 'transcription_request_detail',
      category: ReleaseLogCategory.network,
      fields: {'url': url},
    );
  }

  static void response({required int status, required String contentType}) {
    ReleaseLogger.emit(
      event: 'transcription_response',
      category: ReleaseLogCategory.network,
      fields: {
        'http_status': status,
        'content_type':
            ReleaseLogSanitizer.sanitizeReasonCode(contentType) ?? 'unknown',
      },
    );
  }
}
