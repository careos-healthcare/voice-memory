import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/subscriptions/domain/subscription_models.dart';

import 'subscriptions/fake_subscription_repository.dart';

void main() {
  test('repository watch emits cached state first', () async {
    final repository = FakeSubscriptionRepository(
      state: const SubscriptionState(
        tier: SubscriptionTier.pro,
        entitlementIds: [SubscriptionEntitlements.pro],
        billingConnected: true,
        origin: SubscriptionStateOrigin.cache,
        verification: SubscriptionVerification.cached,
      ),
    );
    final state = await repository.watchState().first;

    expect(state.isPro, isTrue);
    expect(state.verification, SubscriptionVerification.cached);
  });
}
