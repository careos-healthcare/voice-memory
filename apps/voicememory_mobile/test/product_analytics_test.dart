import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/services/analytics/analytics_catalog.dart';
import 'package:voicememory_mobile/services/product_analytics.dart';

void main() {
  setUp(() => ProductAnalytics.resetForTest());

  test('catalogued event queues without Firebase', () async {
    await ProductAnalytics.trackStrings(V1AnalyticsEvent.changesViewed, {
      'reliable_change_available': 'yes',
    });
    expect(ProductAnalytics.queuedEventCountForTest, 1);
  });

  test('unknown event and property fail loudly', () async {
    expect(
      () => ProductAnalytics.trackActivation('analytics_sentinel_unknown'),
      throwsStateError,
    );
    expect(
      () => ProductAnalytics.track(
        V1AnalyticsEvent.changesViewed,
        parameters: const {'unknown_key': 'yes'},
      ),
      throwsStateError,
    );
  });

  test('sensitive keys and values fail before provider', () async {
    for (final key in const [
      'memory_id',
      'entry_id',
      'email',
      'auth_token',
      'customer_id',
      'product_id',
      'timestamp',
      'topic_label',
      'prompt_text',
      'generated_title',
      'category',
      'content_hash',
    ]) {
      expect(
        () => ProductAnalytics.track(
          V1AnalyticsEvent.auditableConclusionShown,
          parameters: {key: 'safe'},
        ),
        throwsStateError,
        reason: key,
      );
    }

    for (final value in const [
      'SENTINEL_PRIVATE_ARCHIVE',
      'person@example.com',
      'bearer_token',
      '0123456789abcdef0123456789abcdef',
    ]) {
      expect(
        () => ProductAnalytics.track(
          V1AnalyticsEvent.auditableConclusionShown,
          parameters: {'conclusion_kind': value},
        ),
        throwsStateError,
        reason: value,
      );
    }
  });

  test('nested and null values fail loudly', () async {
    expect(
      () => ProductAnalytics.track(
        V1AnalyticsEvent.auditableConclusionShown,
        parameters: const {
          'conclusion_kind': <String, Object>{'nested': 'sentinel'},
        },
      ),
      throwsStateError,
    );
    final withNull = <String, Object?>{'conclusion_kind': null};
    expect(
      () => ProductAnalytics.track(
        V1AnalyticsEvent.auditableConclusionShown,
        parameters: withNull,
      ),
      throwsStateError,
    );
  });

  test('provider sees only bucketed content-free payload', () async {
    final sent = <({String event, Map<String, Object> parameters})>[];
    ProductAnalytics.installProviderForTest((event, parameters) async {
      sent.add((event: event, parameters: parameters));
    });

    await ProductAnalytics.track(
      V1AnalyticsEvent.playbackCompleted,
      parameters: const {'duration_seconds': 987654321},
    );

    expect(sent, hasLength(1));
    expect(sent.single.event, 'playback_completed');
    expect(sent.single.parameters, {'duration_seconds_bucket': 'many'});
  });

  test(
    'queued events are revalidated and privacy reset clears queue',
    () async {
      await ProductAnalytics.trackStrings(V1AnalyticsEvent.changesViewed, {
        'reliable_change_available': 'yes',
      });
      expect(
        () => ProductAnalytics.trackStrings(V1AnalyticsEvent.changesViewed, {
          'reliable_change_available': 'sentinel_breadcrumb_private_content',
        }),
        throwsStateError,
      );
      expect(ProductAnalytics.queuedEventCountForTest, 1);

      await ProductAnalytics.resetIdentityAndQueue();
      expect(ProductAnalytics.queuedEventCountForTest, 0);
      expect(ProductAnalytics.eventsForTest, isEmpty);

      final sent = <String>[];
      ProductAnalytics.installProviderForTest(
        (event, _) async => sent.add(event),
      );
      await Future<void>.delayed(Duration.zero);
      expect(sent, isEmpty);
    },
  );
}
