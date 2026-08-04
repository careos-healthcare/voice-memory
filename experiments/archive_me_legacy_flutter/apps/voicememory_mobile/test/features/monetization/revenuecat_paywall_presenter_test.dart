import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart' as purchases_ui;
import 'package:voicememory_mobile/features/monetization/presentation/models/paywall_result.dart';
import 'package:voicememory_mobile/features/monetization/presentation/services/revenuecat_paywall_presenter.dart';
import 'package:voicememory_mobile/subscriptions/domain/subscription_models.dart';

import '../../subscriptions/fake_subscription_repository.dart';

const _pro = SubscriptionState(
  tier: SubscriptionTier.pro,
  entitlementIds: [SubscriptionEntitlements.pro],
  billingConnected: true,
  origin: SubscriptionStateOrigin.store,
);

void main() {
  test('refreshes repository after native purchase', () async {
    final repository = FakeSubscriptionRepository(state: _pro);
    final presenter = RevenueCatPaywallPresenter(
      subscriptionRepository: repository,
      canOpenPaywall: () async => true,
      presentPaywallOverride: ({displayCloseButton = true}) async =>
          purchases_ui.PaywallResult.purchased,
    );

    final result = await presenter.triggerNativePaywallSheet();

    expect(result, PaywallResult.purchased);
    expect(repository.refreshCalls, 1);
  });

  test('fails when repository does not verify native purchase', () async {
    final repository = FakeSubscriptionRepository();
    final presenter = RevenueCatPaywallPresenter(
      subscriptionRepository: repository,
      canOpenPaywall: () async => true,
      presentPaywallOverride: ({displayCloseButton = true}) async =>
          purchases_ui.PaywallResult.purchased,
    );

    expect(await presenter.triggerNativePaywallSheet(), PaywallResult.failed);
  });

  test('maps native cancellation without entitlement refresh', () async {
    final repository = FakeSubscriptionRepository();
    final presenter = RevenueCatPaywallPresenter(
      subscriptionRepository: repository,
      canOpenPaywall: () async => true,
      presentPaywallOverride: ({displayCloseButton = true}) async =>
          purchases_ui.PaywallResult.cancelled,
    );

    expect(
      await presenter.triggerNativePaywallSheet(),
      PaywallResult.cancelled,
    );
    expect(repository.refreshCalls, 0);
  });

  test('presentIfNeeded skips launcher when repository is Pro', () async {
    var launched = false;
    final repository = FakeSubscriptionRepository(state: _pro);
    final presenter = RevenueCatPaywallPresenter(
      subscriptionRepository: repository,
      canOpenPaywall: () async => true,
      presentPaywallIfNeededOverride: ({displayCloseButton = true}) async {
        launched = true;
        return purchases_ui.PaywallResult.purchased;
      },
    );

    expect(
      await presenter.presentIfNeeded(SubscriptionEntitlements.pro),
      PaywallResult.notPresented,
    );
    expect(launched, isFalse);
  });
}
