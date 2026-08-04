import '../services/product_analytics.dart';
import '../services/analytics/analytics_catalog.dart';

/// Start Here recording flow analytics.
abstract class StartHereAnalytics {
  StartHereAnalytics._();

  static Future<void> shown({required String surface}) {
    return ProductAnalytics.track(
      V1AnalyticsEvent.startHereShown,
      parameters: {'surface': surface},
    );
  }

  static Future<void> selected({
    required String surface,
    required String captureMode,
  }) {
    return ProductAnalytics.track(
      V1AnalyticsEvent.startHereSelected,
      parameters: {'surface': surface, 'capture_mode': captureMode},
    );
  }
}
