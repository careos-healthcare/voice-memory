import 'package:flutter/foundation.dart';

import '../../services/activation_funnel_analytics.dart';

/// Metadata-only analytics for the TestFlight metrics dashboard.
abstract final class TestFlightMetricsAnalytics {
  TestFlightMetricsAnalytics._();

  static const seenEvent = 'testflight_metrics_dashboard_seen';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
      captureForTest;

  static void seen({
    required String source,
    required String surface,
    required int metricCount,
  }) {
    final props = <String, Object>{
      'source': source,
      'surface': surface,
      'metric_count': metricCount,
    };
    captureForTest?.call(seenEvent, props);
    ActivationFunnelAnalytics.track(
      seenEvent,
      source: source,
      entryCount: metricCount,
      surfaceType: surface,
    );
    if (kDebugMode) {
      debugPrint(
        'ARCHIVEME_TESTFLIGHT_METRICS event=$seenEvent source=$source '
        'surface=$surface metric_count=$metricCount',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}
