import 'package:flutter/foundation.dart';

import '../../services/activation_funnel_analytics.dart';

/// Safe analytics for daily archive memory — metadata only.
abstract final class DailyArchiveMemoryAnalytics {
  DailyArchiveMemoryAnalytics._();

  static const seenEvent = 'daily_archive_memory_seen';
  static const ctaTappedEvent = 'daily_archive_memory_cta_tapped';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
      captureForTest;

  static void seen({
    required String source,
    required int entryCount,
    required bool hasWatchTarget,
  }) {
    final props = <String, Object>{
      'source': source,
      'entry_count': entryCount,
      'has_watch_target': hasWatchTarget ? 1 : 0,
    };
    captureForTest?.call(seenEvent, props);
    ActivationFunnelAnalytics.track(
      seenEvent,
      source: source,
      entryCount: entryCount,
      hasWatchTarget: hasWatchTarget,
      oncePerSession: true,
    );
    if (kDebugMode) {
      debugPrint(
        'ARCHIVEME_DAILY_ARCHIVE_MEMORY event=$seenEvent source=$source '
        'entry_count=$entryCount has_watch_target=$hasWatchTarget',
      );
    }
  }

  static void ctaTapped({
    required String source,
    required int entryCount,
    required String actionType,
  }) {
    final props = <String, Object>{
      'source': source,
      'entry_count': entryCount,
      'action_type': actionType,
    };
    captureForTest?.call(ctaTappedEvent, props);
    ActivationFunnelAnalytics.track(
      ctaTappedEvent,
      source: source,
      entryCount: entryCount,
      actionType: actionType,
    );
    if (kDebugMode) {
      debugPrint(
        'ARCHIVEME_DAILY_ARCHIVE_MEMORY event=$ctaTappedEvent source=$source '
        'entry_count=$entryCount action_type=$actionType',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}
