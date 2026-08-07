import 'package:flutter/foundation.dart';

import '../../services/activation_funnel_analytics.dart';
import 'present_day_relevance_model.dart';

/// Safe analytics for present-day relevance — metadata only.
abstract final class PresentDayRelevanceAnalytics {
  PresentDayRelevanceAnalytics._();

  static const seenEvent = 'present_day_relevance_seen';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
  captureForTest;

  static void seen({
    required String source,
    required PresentDayRelevanceResult result,
  }) {
    final props = <String, Object>{
      'source': source,
      'entry_count': result.entryCount,
      'has_confirmed_repeat': result.hasConfirmedRepeat ? 1 : 0,
      'has_belief_surface': result.hasBeliefSurface ? 1 : 0,
      'relevance_state': result.relevanceState.analyticsValue,
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
        'ARCHIVEME_PRESENT_DAY_RELEVANCE event=$seenEvent source=$source '
        'entry_count=${result.entryCount} has_confirmed_repeat=${result.hasConfirmedRepeat} '
        'has_belief_surface=${result.hasBeliefSurface} '
        'relevance_state=${result.relevanceState.analyticsValue}',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}
