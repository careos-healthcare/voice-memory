import 'package:flutter/foundation.dart';

import '../../services/activation_funnel_analytics.dart';

/// Safe analytics for local archive backup — metadata only.
abstract final class LocalBackupAnalytics {
  LocalBackupAnalytics._();

  static const exportedEvent = 'archive_backup_exported';
  static const restoredEvent = 'archive_backup_restored';
  static const restoreFailedEvent = 'archive_backup_restore_failed';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
  captureForTest;

  static void exported({
    required String source,
    required bool hasEntries,
    required int schemaVersion,
  }) => _track(
    exportedEvent,
    source: source,
    hasEntries: hasEntries,
    schemaVersion: schemaVersion,
  );

  static void restored({
    required String source,
    required bool hasEntries,
    required int schemaVersion,
  }) => _track(
    restoredEvent,
    source: source,
    hasEntries: hasEntries,
    schemaVersion: schemaVersion,
  );

  static void restoreFailed({
    required String source,
    required int schemaVersion,
  }) => _track(
    restoreFailedEvent,
    source: source,
    hasEntries: false,
    schemaVersion: schemaVersion,
  );

  static void _track(
    String event, {
    required String source,
    required bool hasEntries,
    required int schemaVersion,
  }) {
    final props = <String, Object>{
      'source': source,
      'has_entries': hasEntries ? 1 : 0,
      'schema_version': schemaVersion,
    };

    captureForTest?.call(event, props);
    ActivationFunnelAnalytics.track(
      event,
      source: source,
      entryCount: hasEntries ? 1 : 0,
    );
    if (kDebugMode) {
      debugPrint(
        'ARCHIVEME_LOCAL_BACKUP event=$event source=$source '
        'has_entries=$hasEntries schema_version=$schemaVersion',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}
