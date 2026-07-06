import 'package:flutter/foundation.dart';

import '../../services/activation_funnel_analytics.dart';
import 'belief_change_moment_model.dart';

/// Safe analytics for belief change moment — no transcript text.
abstract final class BeliefChangeMomentAnalytics {
  BeliefChangeMomentAnalytics._();

  static const seenEvent = 'belief_change_moment_seen';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
      captureForTest;

  static void seen({
    required String source,
    required int entryCount,
    required BeliefChangeType changeType,
  }) {
    final props = <String, Object>{
      'source': source,
      'entry_count': entryCount,
      'change_type': changeType.analyticsValue,
    };
    captureForTest?.call(seenEvent, props);
    ActivationFunnelAnalytics.track(
      seenEvent,
      source: source,
      entryCount: entryCount,
      answer: changeType.analyticsValue,
    );
    if (kDebugMode) {
      debugPrint(
        'ARCHIVEME_BELIEF_CHANGE_MOMENT event=$seenEvent source=$source '
        'entry_count=$entryCount change_type=${changeType.analyticsValue}',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}
