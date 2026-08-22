import 'package:archiveme_mobile/core/network/api_failure.dart';
import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/security/release_log_sanitizer.dart';
import 'package:flutter/foundation.dart';

enum ReleaseLogSeverity { debug, info, warn, error }

enum ReleaseLogCategory {
  capture,
  transcription,
  analysis,
  sync,
  auth,
  export,
  billing,
  storage,
  network,
  startup,
  permission,
  unknown,
}

/// Structured, release-safe logging for the focused beta production graph.
abstract final class ReleaseLogger {
  ReleaseLogger._();

  static const prefix = 'ARCHIVEME_LOG';

  @visibleForTesting
  static bool forceReleaseSanitizationForTest = false;

  @visibleForTesting
  static final List<String> testLines = <String>[];

  @visibleForTesting
  static void resetForTest() {
    testLines.clear();
    forceReleaseSanitizationForTest = false;
  }

  static bool get _release =>
      forceReleaseSanitizationForTest || kReleaseMode;

  static void emit({
    required String event,
    ReleaseLogSeverity severity = ReleaseLogSeverity.info,
    ReleaseLogCategory category = ReleaseLogCategory.unknown,
    int? durationMs,
    Map<String, Object?> fields = const {},
  }) {
    final sanitized = ReleaseLogSanitizer.sanitizeFields(
      fields,
      releaseMode: _release,
    );
    final parts = <String>[
      prefix,
      'event=$event',
      'severity=${severity.name}',
      'category=${category.name}',
      if (durationMs != null)
        'duration_bucket=${ReleaseLogSanitizer.durationBucket(durationMs)}',
      ...sanitized.entries.map((e) => '${e.key}=${e.value}'),
    ];
    final line = parts.join(' ');
    testLines.add(line);
    if (severity == ReleaseLogSeverity.debug && _release) return;
    AppLogger.debug(line);
  }

  /// Debug-only detail — stripped entirely in release builds.
  static void debugDetail({
    required String event,
    required Map<String, Object?> fields,
    ReleaseLogCategory category = ReleaseLogCategory.unknown,
  }) {
    if (!_release) {
      emit(
        event: event,
        severity: ReleaseLogSeverity.debug,
        category: category,
        fields: fields,
      );
      return;
    }
    if (kDebugMode) {
      final parts = <String>[
        '$prefix debug',
        'event=$event',
        'category=${category.name}',
        ...fields.entries.map((e) => '${e.key}=${e.value}'),
      ];
      AppLogger.debug(parts.join(' '));
    }
  }

  static void logFailure({
    required String event,
    required ReleaseLogCategory category,
    required String errorCode,
    int? durationMs,
    int? statusCode,
    Map<String, Object?> fields = const {},
  }) {
    emit(
      event: event,
      severity: ReleaseLogSeverity.error,
      category: category,
      durationMs: durationMs,
      fields: {
        'success': false,
        'error_code': ReleaseLogSanitizer.sanitizeReasonCode(errorCode) ??
            'operation_failed',
        if (statusCode != null) 'http_status': statusCode,
        ...fields,
      },
    );
  }

  static void apiFailure({
    required String event,
    required ReleaseLogCategory category,
    required ApiFailure failure,
    int? durationMs,
  }) {
    logFailure(
      event: event,
      category: category,
      errorCode: ReleaseLogSanitizer.errorCodeFromApiFailure(failure),
      durationMs: durationMs,
      statusCode: failure.statusCode,
    );
  }

  static void exceptionFailure({
    required String event,
    required ReleaseLogCategory category,
    required Object error,
    int? durationMs,
  }) {
    logFailure(
      event: event,
      category: category,
      errorCode: ReleaseLogSanitizer.errorCodeFromObject(error),
      durationMs: durationMs,
    );
  }
}
