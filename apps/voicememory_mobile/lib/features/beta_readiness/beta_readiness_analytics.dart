import 'package:flutter/foundation.dart';

import '../../services/activation_funnel_analytics.dart';

/// Safe analytics for beta readiness checklist — source only.
abstract final class BetaReadinessAnalytics {
  BetaReadinessAnalytics._();

  static const openedEvent = 'beta_readiness_check_opened';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
      captureForTest;

  static void opened({required String source}) {
    final props = <String, Object>{'source': source};
    captureForTest?.call(openedEvent, props);
    ActivationFunnelAnalytics.track(
      openedEvent,
      source: source,
    );
    if (kDebugMode) {
      debugPrint('ARCHIVEME_BETA_READINESS event=$openedEvent source=$source');
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}
