import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:flutter/foundation.dart';

/// Optional safe analytics for pattern lifecycle — metadata only.
abstract final class PatternLifecycleAnalytics {
  PatternLifecycleAnalytics._();

  static const seenEvent = 'pattern_lifecycle_seen';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
  captureForTest;

  static void seen({
    required String source,
    required int entryCount,
    required String lifecycleState,
  }) {
    final props = <String, Object>{
      'source': source,
      'entry_count': entryCount,
      'lifecycle_state': lifecycleState,
    };

    captureForTest?.call(seenEvent, props);
    ActivationFunnelAnalytics.track(
      seenEvent,
      source: source,
      entryCount: entryCount,
      lifecycleState: lifecycleState,
      oncePerSession: true,
    );
    if (kDebugMode) {
      AppLogger.debug(
        'ARCHIVEME_PATTERN_LIFECYCLE event=$seenEvent source=$source '
        'entry_count=$entryCount lifecycle_state=$lifecycleState',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}