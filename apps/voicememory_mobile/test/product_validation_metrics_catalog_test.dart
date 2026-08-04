import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/product_metrics/product_validation_metrics.dart';

void main() {
  test(
    'product validation event and property registry aligns with catalog',
    () {
      expect(ProductValidationMetrics.uncataloguedEventIds, isEmpty);
      expect(ProductValidationMetrics.unregisteredPropertyKeys, isEmpty);

      final registeredEvents = ProductValidationMetrics.funnelEventIds.toSet();
      for (final metric in ProductValidationMetrics.all) {
        if (!metric.isClientDerivable) {
          expect(metric.eventIds, isEmpty);
          expect(metric.propertyKeys, isEmpty);
          continue;
        }
        expect(
          registeredEvents.containsAll(metric.eventIds),
          isTrue,
          reason: metric.id,
        );
      }
    },
  );
}
