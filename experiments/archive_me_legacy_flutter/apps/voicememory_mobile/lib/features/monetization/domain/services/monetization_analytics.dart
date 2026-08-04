import 'dart:async';

import '../../../../billing/paywall_source.dart';
import '../../../../services/product_analytics.dart';

export '../../../../billing/paywall_source.dart' show PaywallSource;

abstract interface class AnalyticsEngine {
  void logEvent(String name, {Map<String, Object>? parameters});
}

final class ProductMonetizationAnalyticsEngine implements AnalyticsEngine {
  const ProductMonetizationAnalyticsEngine();

  @override
  void logEvent(String name, {Map<String, Object>? parameters}) {
    unawaited(ProductAnalytics.track(name, parameters: parameters));
  }
}

class MonetizationAnalytics {
  const MonetizationAnalytics([
    this._engine = const ProductMonetizationAnalyticsEngine(),
  ]);

  static const paywallImpressionEvent = 'paywall_seen';
  static const subscriptionCompletedEvent = 'purchase_completed';

  final AnalyticsEngine? _engine;

  /// Tracks when the paywall is displayed and its stable source id.
  void trackPaywallImpression(PaywallSource source) {
    _engine?.logEvent(
      paywallImpressionEvent,
      parameters: {
        'source': source.id,
        'is_value_moment': source == PaywallSource.valueMoment ? 1 : 0,
      },
    );
  }

  /// Tracks a verified successful subscription conversion.
  void trackSubscriptionCompleted({
    required String productId,
    required PaywallSource source,
  }) {
    _engine?.logEvent(
      subscriptionCompletedEvent,
      parameters: {'source': source.id},
    );
  }
}
