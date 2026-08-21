import 'package:archiveme_mobile/security/release_logger.dart';
import 'package:archiveme_mobile/security/release_log_sanitizer.dart';

/// Release-safe logging for Firebase Cloud Messaging setup.
abstract final class FcmLog {
  FcmLog._();

  static void initializeFailed({
    required Object error,
    StackTrace? stackTrace,
  }) {
    ReleaseLogger.emit(
      event: 'firebase_initialize_failed',
      category: ReleaseLogCategory.startup,
      severity: ReleaseLogSeverity.warn,
      fields: {
        'error_code': ReleaseLogSanitizer.errorCodeFromObject(error),
      },
    );
    if (stackTrace != null) {
      ReleaseLogger.debugDetail(
        event: 'firebase_initialize_failed_detail',
        category: ReleaseLogCategory.startup,
        fields: {
          'error_type': error.runtimeType.toString(),
          'stack_trace': stackTrace.toString(),
        },
      );
    }
  }

  static void disabled({required String reason}) {
    ReleaseLogger.emit(
      event: 'fcm_disabled',
      category: ReleaseLogCategory.startup,
      severity: ReleaseLogSeverity.info,
      fields: {'reason': reason},
    );
  }

  static void tokenRegistrationFailed({
    required Object error,
    StackTrace? stackTrace,
  }) {
    ReleaseLogger.emit(
      event: 'fcm_token_registration_failed',
      category: ReleaseLogCategory.startup,
      severity: ReleaseLogSeverity.warn,
      fields: {
        'error_code': ReleaseLogSanitizer.errorCodeFromObject(error),
      },
    );
    if (stackTrace != null) {
      ReleaseLogger.debugDetail(
        event: 'fcm_token_registration_failed_detail',
        category: ReleaseLogCategory.startup,
        fields: {
          'error_type': error.runtimeType.toString(),
          'stack_trace': stackTrace.toString(),
        },
      );
    }
  }

  static void setupFailed({
    required Object error,
    StackTrace? stackTrace,
  }) {
    ReleaseLogger.emit(
      event: 'fcm_setup_failed',
      category: ReleaseLogCategory.startup,
      severity: ReleaseLogSeverity.warn,
      fields: {
        'error_code': ReleaseLogSanitizer.errorCodeFromObject(error),
      },
    );
    if (stackTrace != null) {
      ReleaseLogger.debugDetail(
        event: 'fcm_setup_failed_detail',
        category: ReleaseLogCategory.startup,
        fields: {
          'error_type': error.runtimeType.toString(),
          'stack_trace': stackTrace.toString(),
        },
      );
    }
  }

  static void requestPermissionFailed({
    required Object error,
    StackTrace? stackTrace,
  }) {
    ReleaseLogger.emit(
      event: 'fcm_request_permission_failed',
      category: ReleaseLogCategory.permission,
      severity: ReleaseLogSeverity.warn,
      fields: {
        'error_code': ReleaseLogSanitizer.errorCodeFromObject(error),
      },
    );
    if (stackTrace != null) {
      ReleaseLogger.debugDetail(
        event: 'fcm_request_permission_failed_detail',
        category: ReleaseLogCategory.permission,
        fields: {
          'error_type': error.runtimeType.toString(),
          'stack_trace': stackTrace.toString(),
        },
      );
    }
  }
}
