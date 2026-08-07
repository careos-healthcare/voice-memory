import 'package:flutter/foundation.dart';

import '../../services/activation_funnel_analytics.dart';
import 'timeline_positioning_model.dart';

/// Safe analytics for timeline positioning — metadata only.
abstract final class TimelinePositioningAnalytics {
  TimelinePositioningAnalytics._();

  static const seenEvent = 'timeline_positioning_seen';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
  captureForTest;

  static void seen({
    required String source,
    required TimelinePositioningResult result,
  }) {
    final props = <String, Object>{
      'source': source,
      'entry_count': result.entryCount,
      'has_confirmed_repeat': result.hasConfirmedRepeat ? 1 : 0,
      'has_belief_surface': result.hasBeliefSurface ? 1 : 0,
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
        'ARCHIVEME_TIMELINE_POSITIONING event=$seenEvent source=$source '
        'entry_count=${result.entryCount} has_confirmed_repeat=${result.hasConfirmedRepeat} '
        'has_belief_surface=${result.hasBeliefSurface}',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}
