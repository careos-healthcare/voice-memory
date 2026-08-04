import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/monetization/domain/services/monetization_analytics.dart';

void main() {
  group('MonetizationAnalytics', () {
    late _RecordingAnalyticsEngine engine;
    late MonetizationAnalytics analytics;

    setUp(() {
      engine = _RecordingAnalyticsEngine();
      analytics = MonetizationAnalytics(engine);
    });

    test('tracks a value-moment paywall impression', () {
      analytics.trackPaywallImpression(PaywallSource.valueMoment);

      expect(engine.events, hasLength(1));
      final event = engine.events.single;
      expect(event.name, MonetizationAnalytics.paywallImpressionEvent);
      expect(event.parameters['source'], 'value_moment');
      expect(event.parameters['is_value_moment'], 1);
      expect(event.parameters, isNot(contains('timestamp')));
    });

    test('tracks non-value paywall sources without high-intent flag', () {
      analytics.trackPaywallImpression(PaywallSource.archiveHeader);
      analytics.trackPaywallImpression(PaywallSource.settings);

      expect(engine.events.map((event) => event.parameters['source']), [
        'archive_header',
        'settings',
      ]);
      expect(
        engine.events.map((event) => event.parameters['is_value_moment']),
        everyElement(0),
      );
    });

    test('tracks a completed subscription with stable metadata', () {
      analytics.trackSubscriptionCompleted(
        productId: 'archiveme_pro_annual',
        source: PaywallSource.settings,
      );

      final event = engine.events.single;
      expect(event.name, MonetizationAnalytics.subscriptionCompletedEvent);
      expect(event.parameters['source'], 'settings');
      expect(event.parameters, isNot(contains('product_id')));
      expect(event.parameters, isNot(contains('timestamp')));
    });

    test('allows analytics to be disabled explicitly', () {
      const disabledAnalytics = MonetizationAnalytics(null);

      expect(
        () =>
            disabledAnalytics.trackPaywallImpression(PaywallSource.valueMoment),
        returnsNormally,
      );
    });
  });
}

final class _RecordingAnalyticsEngine implements AnalyticsEngine {
  final List<_RecordedEvent> events = [];

  @override
  void logEvent(String name, {Map<String, Object>? parameters}) {
    events.add(_RecordedEvent(name, parameters ?? const {}));
  }
}

final class _RecordedEvent {
  const _RecordedEvent(this.name, this.parameters);

  final String name;
  final Map<String, Object> parameters;
}
