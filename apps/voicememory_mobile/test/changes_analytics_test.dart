import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/changes/changes_analytics.dart';
import 'package:voicememory_mobile/services/product_analytics.dart';

void main() {
  setUp(ProductAnalytics.resetForTest);

  test('Changes metrics emit only fixed content-free events', () async {
    for (final event in ChangesAnalyticsEvent.values) {
      await ChangesAnalytics.record(event);
    }

    expect(
      ProductAnalytics.eventsForTest
          .map((record) => record.event)
          .toList(growable: false),
      ['changes_opened', 'change_thread_opened', 'weekly_review_opened'],
    );
    expect(
      ProductAnalytics.eventsForTest.every(
        (record) => record.parameters.isEmpty,
      ),
      isTrue,
    );
  });
}
