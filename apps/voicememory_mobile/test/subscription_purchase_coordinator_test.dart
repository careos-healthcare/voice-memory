import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/subscription_purchase_coordinator.dart';
import 'package:voicememory_mobile/subscriptions/domain/subscription_models.dart';

import 'subscriptions/fake_subscription_repository.dart';

const _offer = SubscriptionOffer(
  id: 'monthly',
  productIdentifier: 'store.monthly',
  price: '€4,99',
  period: SubscriptionPeriod.monthly,
);

const _pro = SubscriptionState(
  tier: SubscriptionTier.pro,
  entitlementIds: [SubscriptionEntitlements.pro],
  billingConnected: true,
  origin: SubscriptionStateOrigin.store,
);

void main() {
  test('purchase refreshes entitlement immediately', () async {
    final repository = FakeSubscriptionRepository(purchaseResult: _pro);
    final result = await SubscriptionPurchaseCoordinator(
      repository: repository,
    ).purchase(_offer);

    expect(result.isPro, isTrue);
    expect(repository.purchaseCalls, 1);
    expect(repository.refreshCalls, 1);
  });

  test('restore refreshes entitlement immediately', () async {
    final repository = FakeSubscriptionRepository(restoreResult: _pro);
    final result = await SubscriptionPurchaseCoordinator(
      repository: repository,
    ).restore();

    expect(result.isPro, isTrue);
    expect(repository.restoreCalls, 1);
    expect(repository.refreshCalls, 1);
  });

  test('verified revoked refresh wins over purchase response', () async {
    final repository = _RefreshOverrideRepository(
      purchaseResult: _pro,
      refreshed: const SubscriptionState(
        tier: SubscriptionTier.free,
        entitlementIds: [],
        billingConnected: true,
        origin: SubscriptionStateOrigin.store,
        verification: SubscriptionVerification.verified,
      ),
    );

    final result = await SubscriptionPurchaseCoordinator(
      repository: repository,
    ).purchase(_offer);

    expect(result.isPro, isFalse);
    expect(result.isVerified, isTrue);
  });

  test('cancelled purchase releases the transaction guard', () async {
    final repository = FakeSubscriptionRepository(
      purchaseError: const SubscriptionPurchaseException(
        SubscriptionPurchaseFailureKind.cancelled,
        cause: 'cancelled',
      ),
    );
    final coordinator = SubscriptionPurchaseCoordinator(repository: repository);

    await expectLater(
      coordinator.purchase(_offer),
      throwsA(
        isA<SubscriptionPurchaseException>().having(
          (error) => error.isCancelled,
          'isCancelled',
          isTrue,
        ),
      ),
    );

    expect(coordinator.isBusy, isFalse);
  });

  test('duplicate tap is rejected while purchase is pending', () async {
    final completer = Completer<SubscriptionState>();
    final repository = _PendingPurchaseRepository(completer.future);
    final coordinator = SubscriptionPurchaseCoordinator(repository: repository);

    final first = coordinator.purchase(_offer);
    await expectLater(
      coordinator.purchase(_offer),
      throwsA(
        isA<SubscriptionPurchaseException>().having(
          (error) => error.kind,
          'kind',
          SubscriptionPurchaseFailureKind.pending,
        ),
      ),
    );
    completer.complete(_pro);

    expect((await first).isPro, isTrue);
    expect(repository.purchaseCalls, 1);
  });
}

class _PendingPurchaseRepository extends FakeSubscriptionRepository {
  _PendingPurchaseRepository(this.result);

  final Future<SubscriptionState> result;

  @override
  Future<SubscriptionState> purchase(String offerId) {
    purchaseCalls++;
    purchasedOfferIds.add(offerId);
    return result;
  }
}

class _RefreshOverrideRepository extends FakeSubscriptionRepository {
  _RefreshOverrideRepository({
    required super.purchaseResult,
    required this.refreshed,
  });

  final SubscriptionState refreshed;

  @override
  Future<SubscriptionState> refresh({bool force = false}) async {
    refreshCalls++;
    return refreshed;
  }
}
