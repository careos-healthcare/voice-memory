import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/restore_purchases_flow.dart';
import 'package:voicememory_mobile/services/product_analytics.dart';
import 'package:voicememory_mobile/subscriptions/domain/subscription_models.dart';

import 'subscriptions/fake_subscription_repository.dart';

const _pro = SubscriptionState(
  tier: SubscriptionTier.pro,
  entitlementIds: [SubscriptionEntitlements.pro],
  billingConnected: true,
  origin: SubscriptionStateOrigin.store,
);

void main() {
  setUp(ProductAnalytics.resetForTest);

  test('returns restored when repository verifies Pro', () async {
    final repository = FakeSubscriptionRepository(state: _pro);
    final result = await RestorePurchasesFlow(repository: repository).restore();

    expect(result.outcome, RestorePurchasesOutcome.restored);
    expect(result.subscriptionState, same(_pro));
    expect(repository.restoreCalls, 1);
    expect(
      ProductAnalytics.eventsForTest.map((event) => event.event),
      contains('restore_completed'),
    );
  });

  test('returns no purchase for verified free state', () async {
    final repository = FakeSubscriptionRepository();
    final result = await RestorePurchasesFlow(repository: repository).restore();

    expect(result.outcome, RestorePurchasesOutcome.noPurchase);
  });

  test('retains cached access without claiming a restore', () async {
    final repository = FakeSubscriptionRepository(
      state: _pro.copyWith(
        verification: SubscriptionVerification.cached,
        origin: SubscriptionStateOrigin.offline,
      ),
    );
    final result = await RestorePurchasesFlow(repository: repository).restore();

    expect(result.outcome, RestorePurchasesOutcome.cachedAccessRetained);
    final event = ProductAnalytics.eventsForTest.single;
    expect(event.event, 'restore_failed');
    expect(event.parameters['failure_reason_band'], 'provider_unavailable');
  });

  test('restore does not depend on store package availability', () async {
    final repository = FakeSubscriptionRepository(
      availability: SubscriptionAvailability.notConfigured,
    );
    final result = await RestorePurchasesFlow(repository: repository).restore();

    expect(result.outcome, RestorePurchasesOutcome.noPurchase);
    expect(repository.restoreCalls, 1);
  });

  test('guards concurrent restore calls', () async {
    final completer = Completer<SubscriptionState>();
    final repository = _BlockingRepository(completer.future);
    final flow = RestorePurchasesFlow(repository: repository);

    final first = flow.restore();
    final second = await flow.restore();
    expect(second.outcome, RestorePurchasesOutcome.skippedBusy);

    completer.complete(_pro);
    expect((await first).outcome, RestorePurchasesOutcome.restored);
  });
}

class _BlockingRepository extends FakeSubscriptionRepository {
  _BlockingRepository(this.result);

  final Future<SubscriptionState> result;

  @override
  Future<SubscriptionState> restore() => result;
}
