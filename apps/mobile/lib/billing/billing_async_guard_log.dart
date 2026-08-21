import 'package:archiveme_mobile/security/release_logger.dart';
import 'package:archiveme_mobile/security/release_log_sanitizer.dart';

/// Structured logs for billing network timeout guards.
abstract final class BillingAsyncGuardLog {
  BillingAsyncGuardLog._();

  static void timeout({required String label, required int timeoutSeconds}) {
    ReleaseLogger.emit(
      event: 'billing_operation_timeout',
      category: ReleaseLogCategory.billing,
      severity: ReleaseLogSeverity.warn,
      fields: {
        'label': label,
        'timeout_seconds': timeoutSeconds,
      },
    );
  }

  static void error({
    required String label,
    required Object error,
    StackTrace? stackTrace,
  }) {
    ReleaseLogger.emit(
      event: 'billing_operation_error',
      category: ReleaseLogCategory.billing,
      severity: ReleaseLogSeverity.warn,
      fields: {
        'label': label,
        'error_code': ReleaseLogSanitizer.errorCodeFromObject(error),
      },
    );
    if (stackTrace != null) {
      ReleaseLogger.debugDetail(
        event: 'billing_operation_error_detail',
        category: ReleaseLogCategory.billing,
        fields: {
          'label': label,
          'error_type': error.runtimeType.toString(),
          'stack_trace': stackTrace.toString(),
        },
      );
    }
  }
}
