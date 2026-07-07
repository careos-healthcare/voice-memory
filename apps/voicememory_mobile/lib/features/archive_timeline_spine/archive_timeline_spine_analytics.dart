import 'package:flutter/foundation.dart';

import '../../services/activation_funnel_analytics.dart';
import 'archive_timeline_spine_model.dart';

/// Safe analytics for archive timeline spine — metadata only.
abstract final class ArchiveTimelineSpineAnalytics {
  ArchiveTimelineSpineAnalytics._();

  static const seenEvent = 'archive_timeline_spine_seen';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
      captureForTest;

  static void seen({
    required String source,
    required ArchiveTimelineSpineResult result,
  }) {
    final props = <String, Object>{
      'source': source,
      'entry_count': result.entryCount,
      'has_confirmed_repeat': result.hasConfirmedRepeat ? 1 : 0,
      'has_correction': result.hasCorrection ? 1 : 0,
      'current_weight_state': result.currentWeight.analyticsValue,
      'row_count': result.rowCount,
    };
    captureForTest?.call(seenEvent, props);
    ActivationFunnelAnalytics.track(
      seenEvent,
      source: source,
      entryCount: result.entryCount,
      hasConfirmedRepeat: result.hasConfirmedRepeat,
    );
    if (kDebugMode) {
      debugPrint(
        'ARCHIVEME_TIMELINE_SPINE event=$seenEvent source=$source '
        'entry_count=${result.entryCount} has_confirmed_repeat=${result.hasConfirmedRepeat} '
        'has_correction=${result.hasCorrection} '
        'current_weight_state=${result.currentWeight.analyticsValue} '
        'row_count=${result.rowCount}',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}
