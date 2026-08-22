import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/features/revenue_metrics/revenue_funnel_analytics.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:flutter/foundation.dart';

/// Metadata-only analytics for the archive preservation bridge.
abstract final class ArchiveBackupBridgeAnalytics {
  ArchiveBackupBridgeAnalytics._();

  static const seenEvent = 'archive_backup_bridge_seen';
  static const ctaTappedEvent = 'archive_backup_bridge_cta_tapped';
  static const dismissedEvent = 'archive_backup_bridge_dismissed';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
  captureForTest;

  static void seen({
    required String source,
    required int entryCount,
    required bool hasConfirmedRepeat,
    required bool hasReportPreview,
  }) {
    _emit(
      seenEvent,
      source: source,
      entryCount: entryCount,
      hasConfirmedRepeat: hasConfirmedRepeat,
      hasReportPreview: hasReportPreview,
    );
  }

  static void ctaTapped({
    required String source,
    required int entryCount,
    required bool hasConfirmedRepeat,
    required bool hasReportPreview,
    required String actionType,
  }) {
    _emit(
      ctaTappedEvent,
      source: source,
      entryCount: entryCount,
      hasConfirmedRepeat: hasConfirmedRepeat,
      hasReportPreview: hasReportPreview,
      actionType: actionType,
    );
  }

  static void dismissed({
    required String source,
    required int entryCount,
    required bool hasConfirmedRepeat,
    required bool hasReportPreview,
  }) {
    _emit(
      dismissedEvent,
      source: source,
      entryCount: entryCount,
      hasConfirmedRepeat: hasConfirmedRepeat,
      hasReportPreview: hasReportPreview,
    );
  }

  static void _emit(
    String event, {
    required String source,
    required int entryCount,
    required bool hasConfirmedRepeat,
    required bool hasReportPreview,
    String? actionType,
  }) {
    final props = <String, Object>{
      'source': source,
      'entry_count': entryCount,
      'has_confirmed_repeat': hasConfirmedRepeat ? 1 : 0,
      'has_report_preview': hasReportPreview ? 1 : 0,
      'action_type': ?actionType,
    };

    captureForTest?.call(event, props);
    if (event == seenEvent) {
      RevenueFunnelAnalytics.backupBridgeSeen(
        source: source,
        entryCount: entryCount,
        hasConfirmedRepeat: hasConfirmedRepeat,
        hasReportPreview: hasReportPreview,
      );
    } else if (event == ctaTappedEvent) {
      RevenueFunnelAnalytics.backupBridgeCtaTapped(
        source: source,
        entryCount: entryCount,
        hasConfirmedRepeat: hasConfirmedRepeat,
        hasReportPreview: hasReportPreview,
      );
    }
    ActivationFunnelAnalytics.track(
      event,
      source: source,
      entryCount: entryCount,
    );
    if (kDebugMode) {
      AppLogger.debug(
        'ARCHIVEME_ARCHIVE_BACKUP_BRIDGE event=$event source=$source '
        'entry_count=$entryCount has_confirmed_repeat=${props['has_confirmed_repeat']} '
        'has_report_preview=${props['has_report_preview']}',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}