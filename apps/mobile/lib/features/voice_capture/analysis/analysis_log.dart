import 'package:archiveme_mobile/security/release_logger.dart';
import 'package:archiveme_mobile/security/release_log_sanitizer.dart';

/// Release-safe logging for transcript analysis.
abstract class AnalysisLog {
  AnalysisLog._();

  static void request({required String url}) {
    ReleaseLogger.emit(
      event: 'analysis_request',
      category: ReleaseLogCategory.network,
      fields: {'operation': 'analyze'},
    );
    ReleaseLogger.debugDetail(
      event: 'analysis_request_detail',
      category: ReleaseLogCategory.network,
      fields: {'url': url},
    );
  }

  static void response({required int status, required String contentType}) {
    ReleaseLogger.emit(
      event: 'analysis_response',
      category: ReleaseLogCategory.network,
      fields: {
        'http_status': status,
        'content_type':
            ReleaseLogSanitizer.sanitizeReasonCode(contentType) ?? 'unknown',
      },
    );
  }

  static void success({required int observationLength}) {
    ReleaseLogger.emit(
      event: 'analysis_success',
      category: ReleaseLogCategory.analysis,
      fields: {
        'success': true,
        'observation_length_bucket':
            ReleaseLogSanitizer.lengthBucket(observationLength),
      },
    );
  }

  static void failed({required String reason, int? status, String? code}) {
    ReleaseLogger.logFailure(
      event: 'analysis_failed',
      category: ReleaseLogCategory.analysis,
      errorCode: code ?? reason,
      statusCode: status,
    );
  }
}
