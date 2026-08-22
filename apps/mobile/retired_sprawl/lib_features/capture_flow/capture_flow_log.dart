import 'package:archiveme_mobile/security/release_logger.dart';
import 'package:archiveme_mobile/security/release_log_sanitizer.dart';

/// Release-safe logging for the strangler capture flow controller.
abstract final class CaptureFlowLog {
  CaptureFlowLog._();

  static void unexpectedFailure({
    required String operation,
    required Object error,
    StackTrace? stackTrace,
  }) {
    ReleaseLogger.emit(
      event: 'capture_flow_unexpected_failure',
      category: ReleaseLogCategory.capture,
      severity: ReleaseLogSeverity.warn,
      fields: {
        'operation': operation,
        'error_code': ReleaseLogSanitizer.errorCodeFromObject(error),
      },
    );
    if (stackTrace != null) {
      ReleaseLogger.debugDetail(
        event: 'capture_flow_unexpected_failure_detail',
        category: ReleaseLogCategory.capture,
        fields: {
          'operation': operation,
          'error_type': error.runtimeType.toString(),
          'stack_trace': stackTrace.toString(),
        },
      );
    }
  }
}
