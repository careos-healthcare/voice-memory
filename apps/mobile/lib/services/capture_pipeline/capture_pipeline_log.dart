import 'package:archiveme_mobile/security/release_logger.dart';
import 'package:archiveme_mobile/security/release_log_sanitizer.dart';

/// Release-safe logging for capture pipeline orchestration.
abstract class CapturePipelineLog {
  CapturePipelineLog._();

  static void postSaveMomentDetailFailed({
    required Object error,
    required StackTrace stackTrace,
  }) {
    ReleaseLogger.emit(
      event: 'capture_post_save_detail_failed',
      category: ReleaseLogCategory.capture,
      severity: ReleaseLogSeverity.warn,
      fields: {
        'success': false,
        'error_code': ReleaseLogSanitizer.errorCodeFromObject(error),
      },
    );
    ReleaseLogger.debugDetail(
      event: 'capture_post_save_detail_failed_detail',
      category: ReleaseLogCategory.capture,
      fields: {
        'error_type': error.runtimeType.toString(),
        'stack_trace': stackTrace.toString(),
      },
    );
  }
}
