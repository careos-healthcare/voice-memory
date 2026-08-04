import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:voicememory_mobile/api/api_exceptions.dart';
import 'package:voicememory_mobile/billing/purchase_failure.dart';
import 'package:voicememory_mobile/billing/revenuecat_service.dart';
import 'package:voicememory_mobile/features/monetization/domain/generated/monetization_policy.g.dart';
import 'package:voicememory_mobile/models/entitlement.dart';
import 'package:voicememory_mobile/subscriptions/data/default_subscription_repository.dart';
import 'package:voicememory_mobile/subscriptions/data/legacy_subscription_mapper.dart';
import 'package:voicememory_mobile/subscriptions/domain/subscription_models.dart';

const _pro = PremiumEntitlements(
  tier: BillingTier.pro,
  entitlementIds: ['archive_loop_pro'],
  billingConnected: true,
  source: 'revenuecat',
);

PlatformException _platformError(PurchasesErrorCode code) =>
    PlatformException(code: code.index.toString(), message: code.name);

EntitlementInfo _entitlement({
  required bool active,
  required bool willRenew,
  String? expirationDate,
  String? unsubscribeDetectedAt,
  String? billingIssueDetectedAt,
  String productIdentifier = 'archive_loop_pro_yearly',
}) => EntitlementInfo(
  'archive_loop_pro',
  active,
  willRenew,
  '2026-07-20T12:00:00Z',
  '2026-01-01T12:00:00Z',
  productIdentifier,
  false,
  expirationDate: expirationDate,
  unsubscribeDetectedAt: unsubscribeDetectedAt,
  billingIssueDetectedAt: billingIssueDetectedAt,
);

void main() {
  test('restore reports a domain error when RevenueCat is not configured', () {
    expect(
      RevenueCatService.instance.restorePurchases(),
      throwsA(isA<BillingUnavailableException>()),
    );
  });

  test('transient RevenueCat refresh state preserves cached Pro', () {
    final unavailable = RevenueCatService.unavailableFrom(
      _pro,
      source: 'revenuecat_refresh_error',
    );
    final merged = DefaultSubscriptionRepository.mergeStates(
      server: LegacySubscriptionMapper.fromEntitlements(_pro),
      store: LegacySubscriptionMapper.fromEntitlements(unavailable),
      storeAvailable: true,
    );

    expect(merged.isPro, isTrue);
    expect(merged.billingConnected, isFalse);
    expect(merged.verification, SubscriptionVerification.cached);
  });

  test('verified successful RevenueCat free response downgrades Pro', () {
    final free = RevenueCatService.mapEntitlementInfo(
      entitlement: null,
      activeProIds: const [],
      requestDate: '2026-07-25T12:00:00Z',
      billingConnected: true,
      now: DateTime.utc(2026, 7, 25, 12, 1),
    );

    final merged = DefaultSubscriptionRepository.mergeStates(
      server: LegacySubscriptionMapper.fromEntitlements(_pro),
      store: LegacySubscriptionMapper.fromEntitlements(free),
      storeAvailable: true,
    );
    expect(free.canDowngrade, isTrue);
    expect(merged.isPro, isFalse);
  });

  test('cancelled renewal remains active through future expiration', () {
    final mapped = RevenueCatService.mapEntitlementInfo(
      entitlement: _entitlement(
        active: true,
        willRenew: false,
        expirationDate: '2026-08-01T12:00:00Z',
        unsubscribeDetectedAt: '2026-07-24T12:00:00Z',
      ),
      activeProIds: const ['archive_loop_pro'],
      requestDate: '2026-07-25T12:00:00Z',
      billingConnected: true,
      now: DateTime.utc(2026, 7, 25, 12, 1),
    );

    expect(mapped.isPro, isTrue);
    expect(mapped.willRenew, isFalse);
    expect(mapped.unsubscribeDetectedAt, isNotNull);
    expect(mapped.expirationDate, DateTime.utc(2026, 8, 1, 12));
  });

  test('billing issue grace remains active while RevenueCat says active', () {
    final mapped = RevenueCatService.mapEntitlementInfo(
      entitlement: _entitlement(
        active: true,
        willRenew: true,
        expirationDate: '2026-07-26T12:00:00Z',
        billingIssueDetectedAt: '2026-07-25T08:00:00Z',
      ),
      activeProIds: const ['archive_loop_pro'],
      requestDate: '2026-07-25T12:00:00Z',
      billingConnected: true,
      now: DateTime.utc(2026, 7, 25, 12, 1),
    );

    expect(mapped.isPro, isTrue);
    expect(mapped.billingIssueDetectedAt, isNotNull);
    expect(mapped.subscriptionState, PolicySubscriptionState.gracePeriod);
  });

  test('verified non-expiring entitlement is legacy grandfathered', () {
    final mapped = RevenueCatService.mapEntitlementInfo(
      entitlement: _entitlement(
        active: true,
        willRenew: false,
        productIdentifier: 'archive_loop_pro_lifetime',
      ),
      activeProIds: const ['pro'],
      requestDate: '2026-07-25T12:00:00Z',
      billingConnected: true,
      now: DateTime.utc(2026, 7, 25, 12, 1),
    );
    final subscription = LegacySubscriptionMapper.fromEntitlements(mapped);

    expect(mapped.accessKind, PlanKind.legacyGrandfathered);
    expect(subscription.isLegacyGrandfathered, isTrue);
    expect(subscription.entitlementIds, ['archive_loop_pro']);
  });

  test(
    'non-expiring subscription product is not accidentally grandfathered',
    () {
      final mapped = RevenueCatService.mapEntitlementInfo(
        entitlement: _entitlement(active: true, willRenew: false),
        activeProIds: const ['archive_loop_pro'],
        requestDate: '2026-07-25T12:00:00Z',
        billingConnected: true,
        now: DateTime.utc(2026, 7, 25, 12, 1),
      );

      expect(mapped.accessKind, PlanKind.pro);
      expect(mapped.subscriptionState, PolicySubscriptionState.active);
    },
  );

  test('expired or revoked entitlement does not grant access', () {
    final mapped = RevenueCatService.mapEntitlementInfo(
      entitlement: _entitlement(
        active: false,
        willRenew: false,
        expirationDate: '2026-07-24T12:00:00Z',
      ),
      activeProIds: const [],
      requestDate: '2026-07-25T12:00:00Z',
      billingConnected: true,
      now: DateTime.utc(2026, 7, 25, 12, 1),
    );

    expect(mapped.isPro, isFalse);
    expect(mapped.accessKind, PlanKind.free);
  });

  test('stale RevenueCat customer info cannot extend offline Pro access', () {
    final mapped = RevenueCatService.mapEntitlementInfo(
      entitlement: _entitlement(
        active: true,
        willRenew: true,
        expirationDate: '2026-08-01T12:00:00Z',
      ),
      activeProIds: const ['archive_loop_pro'],
      requestDate: '2026-07-20T12:00:00Z',
      billingConnected: true,
      now: DateTime.utc(2026, 7, 25, 12),
    );

    expect(mapped.isPro, isFalse);
    expect(mapped.verification, EntitlementVerification.cached);
    expect(mapped.canDowngrade, isFalse);
    expect(mapped.expirationDate, DateTime.utc(2026, 8, 1, 12));
  });

  test('purchase errors classify cancellation network and unavailable', () {
    expect(
      PurchaseFailureMapper.from(
        _platformError(PurchasesErrorCode.purchaseCancelledError),
      ).kind,
      PurchaseFailureKind.cancelled,
    );
    expect(
      PurchaseFailureMapper.from(
        _platformError(PurchasesErrorCode.offlineConnectionError),
      ).kind,
      PurchaseFailureKind.temporary,
    );
    expect(
      PurchaseFailureMapper.from(
        _platformError(PurchasesErrorCode.productNotAvailableForPurchaseError),
      ).kind,
      PurchaseFailureKind.productUnavailable,
    );
  });
}
