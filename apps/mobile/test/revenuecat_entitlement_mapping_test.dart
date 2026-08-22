import 'package:archiveme_mobile/billing/archive_loop_entitlement_ids.dart';
import 'package:archiveme_mobile/billing/revenuecat_service.dart';
import 'package:archiveme_mobile/models/entitlement.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

Map<String, dynamic> _entitlementJson(String id, {required bool active}) => {
  'identifier': id,
  'isActive': active,
  'willRenew': active,
  'latestPurchaseDate': '2026-01-01T00:00:00Z',
  'originalPurchaseDate': '2026-01-01T00:00:00Z',
  'productIdentifier': '${id}_monthly',
  'isSandbox': false,
  'periodType': 'NORMAL',
  'ownershipType': 'PURCHASED',
  'store': 'APP_STORE',
  'verification': 'NOT_REQUESTED',
};

CustomerInfo _customerInfoWithActiveEntitlements(List<String> activeIds) {
  final all = <String, dynamic>{};
  final active = <String, dynamic>{};
  for (final id in activeIds) {
    final json = _entitlementJson(id, active: true);
    all[id] = json;
    active[id] = json;
  }
  return CustomerInfo.fromJson(<String, dynamic>{
    'entitlements': <String, dynamic>{
      'all': all,
      'active': active,
      'verification': 'NOT_REQUESTED',
    },
    'allPurchaseDates': <String, dynamic>{},
    'activeSubscriptions': <String>[],
    'allPurchasedProductIdentifiers': <String>[],
    'nonSubscriptionTransactions': <dynamic>[],
    'firstSeen': '2026-01-01T00:00:00Z',
    'originalAppUserId': 'test-user',
    'allExpirationDates': <String, dynamic>{},
    'requestDate': '2026-01-01T00:00:00Z',
  });
}

void main() {
  final service = RevenueCatService.instance;

  test('a customer entitled only under the primary archive_loop_pro id is '
      'recognized as Pro (P0 — billing entitlement ID conflict)', () {
    final info = _customerInfoWithActiveEntitlements([
      ArchiveLoopEntitlementIds.archiveLoopPro,
    ]);

    final mapped = service.mapCustomerInfoForTest(info);

    expect(mapped.tier, BillingTier.pro);
    expect(mapped.isPro, isTrue);
    expect(mapped.entitlementIds, [ArchiveLoopEntitlementIds.archiveLoopPro]);
  });

  test(
    'a customer entitled only under the legacy pro id is still recognized',
    () {
      final info = _customerInfoWithActiveEntitlements([
        ArchiveLoopEntitlementIds.revenueCatLegacyPro,
      ]);

      final mapped = service.mapCustomerInfoForTest(info);

      expect(mapped.tier, BillingTier.pro);
      expect(mapped.isPro, isTrue);
      expect(mapped.entitlementIds, [
        ArchiveLoopEntitlementIds.revenueCatLegacyPro,
      ]);
    },
  );

  test('a customer with no active entitlement is free', () {
    final info = _customerInfoWithActiveEntitlements(const []);

    final mapped = service.mapCustomerInfoForTest(info);

    expect(mapped.tier, BillingTier.free);
    expect(mapped.isPro, isFalse);
    expect(mapped.entitlementIds, isEmpty);
  });

  test('an unrelated active entitlement id does not grant Pro', () {
    final info = _customerInfoWithActiveEntitlements([
      'some_other_entitlement',
    ]);

    final mapped = service.mapCustomerInfoForTest(info);

    expect(mapped.tier, BillingTier.free);
    expect(mapped.isPro, isFalse);
  });
}