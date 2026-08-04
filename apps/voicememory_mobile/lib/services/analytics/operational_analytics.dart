import '../product_analytics.dart';
import 'analytics_catalog.dart';

enum OperationalSource { voice, text, imported, manual, background, system }

enum OperationalFailureCategory {
  offline,
  timeout,
  providerUnavailable,
  permissionDenied,
  authentication,
  validation,
  storageUnavailable,
  quota,
  cancelled,
  unknown,
}

enum OperationalAttemptBand { first, second, thirdOrMore }

enum OperationalExportFormat { readable, full }

enum OperationalTimingBand {
  under200ms,
  under500ms,
  under1s,
  under2s,
  under5s,
  over5s,
}

String _source(OperationalSource value) => switch (value) {
  OperationalSource.voice => 'voice',
  OperationalSource.text => 'text',
  OperationalSource.imported => 'import',
  OperationalSource.manual => 'manual',
  OperationalSource.background => 'background',
  OperationalSource.system => 'system',
};

String _failure(OperationalFailureCategory value) => switch (value) {
  OperationalFailureCategory.offline => 'offline',
  OperationalFailureCategory.timeout => 'timeout',
  OperationalFailureCategory.providerUnavailable => 'provider_unavailable',
  OperationalFailureCategory.permissionDenied => 'permission_denied',
  OperationalFailureCategory.authentication => 'authentication',
  OperationalFailureCategory.validation => 'validation',
  OperationalFailureCategory.storageUnavailable => 'storage_unavailable',
  OperationalFailureCategory.quota => 'quota',
  OperationalFailureCategory.cancelled => 'cancelled',
  OperationalFailureCategory.unknown => 'unknown',
};

String _attempt(OperationalAttemptBand value) => switch (value) {
  OperationalAttemptBand.first => 'first',
  OperationalAttemptBand.second => 'second',
  OperationalAttemptBand.thirdOrMore => 'third_or_more',
};

String _exportFormat(OperationalExportFormat value) => switch (value) {
  OperationalExportFormat.readable => 'readable',
  OperationalExportFormat.full => 'full',
};

String _timing(OperationalTimingBand value) => switch (value) {
  OperationalTimingBand.under200ms => 'under_200ms',
  OperationalTimingBand.under500ms => 'under_500ms',
  OperationalTimingBand.under1s => 'under_1s',
  OperationalTimingBand.under2s => 'under_2s',
  OperationalTimingBand.under5s => 'under_5s',
  OperationalTimingBand.over5s => 'over_5s',
};

/// Construction boundary for operational telemetry.
///
/// Only enums and pre-bucketed counts can enter this object. Its private
/// constructor prevents feature code from attaching ids, content, paths, raw
/// errors, or arbitrary strings. [ProductAnalytics] validates the resulting
/// payload again immediately before dispatch.
final class OperationalAnalyticsRecord {
  OperationalAnalyticsRecord._(
    this.event, {
    OperationalSource? source,
    OperationalFailureCategory? failure,
    OperationalAttemptBand? attempt,
    OperationalTimingBand? timing,
    OperationalExportFormat? exportFormat,
    int? itemCount,
  }) : parameters = Map.unmodifiable({
         if (source != null) 'operation_source': _source(source),
         if (failure != null) 'failure_reason_band': _failure(failure),
         if (attempt != null) 'attempt_band': _attempt(attempt),
         if (timing != null) 'performance_duration_band': _timing(timing),
         if (exportFormat != null) 'format': _exportFormat(exportFormat),
         if (itemCount != null)
           'item_count_bucket': AnalyticsCatalog.countBucket(itemCount),
       });

  final OperationalAnalyticsEvent event;
  final Map<String, Object> parameters;

  Future<void> dispatch() =>
      ProductAnalytics.trackOperational(event, parameters: parameters);
}

abstract final class CaptureOperationalAnalytics {
  static Future<void> originalSaveStarted(OperationalSource source) =>
      OperationalAnalyticsRecord._(
        OperationalAnalyticsEvent.originalSaveStarted,
        source: source,
      ).dispatch();

  static Future<void> originalSaveCompleted(
    OperationalSource source,
    OperationalTimingBand timing,
  ) => OperationalAnalyticsRecord._(
    OperationalAnalyticsEvent.originalSaveCompleted,
    source: source,
    timing: timing,
  ).dispatch();

  static Future<void> originalSaveFailed(
    OperationalSource source,
    OperationalFailureCategory failure,
  ) => OperationalAnalyticsRecord._(
    OperationalAnalyticsEvent.originalSaveFailed,
    source: source,
    failure: failure,
  ).dispatch();
}

abstract final class TranscriptionOperationalAnalytics {
  static Future<void> started(OperationalSource source) =>
      OperationalAnalyticsRecord._(
        OperationalAnalyticsEvent.transcriptionStarted,
        source: source,
      ).dispatch();

  static Future<void> completed(OperationalTimingBand timing) =>
      OperationalAnalyticsRecord._(
        OperationalAnalyticsEvent.transcriptionCompleted,
        timing: timing,
      ).dispatch();

  static Future<void> failed(OperationalFailureCategory failure) =>
      OperationalAnalyticsRecord._(
        OperationalAnalyticsEvent.transcriptionFailed,
        failure: failure,
      ).dispatch();
}

abstract final class InterpretationOperationalAnalytics {
  static Future<void> started() => OperationalAnalyticsRecord._(
    OperationalAnalyticsEvent.interpretationStarted,
  ).dispatch();

  static Future<void> completed(OperationalTimingBand timing) =>
      OperationalAnalyticsRecord._(
        OperationalAnalyticsEvent.interpretationCompleted,
        timing: timing,
      ).dispatch();

  static Future<void> suppressed(OperationalFailureCategory category) =>
      OperationalAnalyticsRecord._(
        OperationalAnalyticsEvent.interpretationSuppressed,
        failure: category,
      ).dispatch();

  static Future<void> failed(OperationalFailureCategory failure) =>
      OperationalAnalyticsRecord._(
        OperationalAnalyticsEvent.interpretationFailed,
        failure: failure,
      ).dispatch();
}

abstract final class RetryOperationalAnalytics {
  static Future<void> scheduled(OperationalAttemptBand attempt) =>
      OperationalAnalyticsRecord._(
        OperationalAnalyticsEvent.retryScheduled,
        attempt: attempt,
      ).dispatch();

  static Future<void> started(OperationalAttemptBand attempt) =>
      OperationalAnalyticsRecord._(
        OperationalAnalyticsEvent.retryStarted,
        attempt: attempt,
      ).dispatch();

  static Future<void> completed(OperationalAttemptBand attempt) =>
      OperationalAnalyticsRecord._(
        OperationalAnalyticsEvent.retryCompleted,
        attempt: attempt,
      ).dispatch();

  static Future<void> exhausted(
    OperationalAttemptBand attempt,
    OperationalFailureCategory failure,
  ) => OperationalAnalyticsRecord._(
    OperationalAnalyticsEvent.retryExhausted,
    attempt: attempt,
    failure: failure,
  ).dispatch();
}

abstract final class VaultOperationalAnalytics {
  static Future<void> writeStarted() => OperationalAnalyticsRecord._(
    OperationalAnalyticsEvent.vaultWriteStarted,
  ).dispatch();

  static Future<void> writeCompleted(OperationalTimingBand timing) =>
      OperationalAnalyticsRecord._(
        OperationalAnalyticsEvent.vaultWriteCompleted,
        timing: timing,
      ).dispatch();

  static Future<void> writeFailed(OperationalFailureCategory failure) =>
      OperationalAnalyticsRecord._(
        OperationalAnalyticsEvent.vaultWriteFailed,
        failure: failure,
      ).dispatch();
}

abstract final class SyncRecoveryOperationalAnalytics {
  static Future<void> syncStarted() => OperationalAnalyticsRecord._(
    OperationalAnalyticsEvent.syncStarted,
  ).dispatch();

  static Future<void> syncCompleted() => OperationalAnalyticsRecord._(
    OperationalAnalyticsEvent.syncCompleted,
  ).dispatch();

  static Future<void> syncFailed(OperationalFailureCategory failure) =>
      OperationalAnalyticsRecord._(
        OperationalAnalyticsEvent.syncFailed,
        failure: failure,
      ).dispatch();

  static Future<void> recoveryStarted() => OperationalAnalyticsRecord._(
    OperationalAnalyticsEvent.recoveryStarted,
  ).dispatch();

  static Future<void> recoveryCompleted() => OperationalAnalyticsRecord._(
    OperationalAnalyticsEvent.recoveryCompleted,
  ).dispatch();

  static Future<void> recoveryFailed(OperationalFailureCategory failure) =>
      OperationalAnalyticsRecord._(
        OperationalAnalyticsEvent.recoveryFailed,
        failure: failure,
      ).dispatch();
}

abstract final class CommerceOperationalAnalytics {
  static Future<void> purchaseStarted() => OperationalAnalyticsRecord._(
    OperationalAnalyticsEvent.purchaseStarted,
  ).dispatch();

  static Future<void> purchaseCompleted() => OperationalAnalyticsRecord._(
    OperationalAnalyticsEvent.purchaseCompleted,
  ).dispatch();

  static Future<void> purchaseFailed(OperationalFailureCategory failure) =>
      OperationalAnalyticsRecord._(
        OperationalAnalyticsEvent.purchaseFailed,
        failure: failure,
      ).dispatch();

  static Future<void> restoreCompleted() => OperationalAnalyticsRecord._(
    OperationalAnalyticsEvent.restoreCompleted,
  ).dispatch();

  static Future<void> restoreFailed(OperationalFailureCategory failure) =>
      OperationalAnalyticsRecord._(
        OperationalAnalyticsEvent.restoreFailed,
        failure: failure,
      ).dispatch();
}

abstract final class DeletionOperationalAnalytics {
  static Future<void> started() => OperationalAnalyticsRecord._(
    OperationalAnalyticsEvent.deletionStarted,
  ).dispatch();

  static Future<void> completed() => OperationalAnalyticsRecord._(
    OperationalAnalyticsEvent.deletionCompleted,
  ).dispatch();

  static Future<void> failed(OperationalFailureCategory failure) =>
      OperationalAnalyticsRecord._(
        OperationalAnalyticsEvent.deletionFailed,
        failure: failure,
      ).dispatch();
}

abstract final class ExportOperationalAnalytics {
  static Future<void> started(OperationalExportFormat format) =>
      OperationalAnalyticsRecord._(
        OperationalAnalyticsEvent.exportStarted,
        exportFormat: format,
      ).dispatch();

  static Future<void> completed(
    OperationalExportFormat format,
    int itemCount,
  ) => OperationalAnalyticsRecord._(
    OperationalAnalyticsEvent.exportCompleted,
    exportFormat: format,
    itemCount: itemCount,
  ).dispatch();

  static Future<void> failed(
    OperationalExportFormat format,
    OperationalFailureCategory failure,
  ) => OperationalAnalyticsRecord._(
    OperationalAnalyticsEvent.exportFailed,
    exportFormat: format,
    failure: failure,
  ).dispatch();
}
