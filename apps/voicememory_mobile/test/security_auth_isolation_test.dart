import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'helpers/test_billing_service.dart';
import 'package:voicememory_mobile/billing/billing_service.dart';
import 'package:voicememory_mobile/billing/store_billing_port.dart';
import 'package:voicememory_mobile/models/entitlement.dart';
import 'package:voicememory_mobile/storage/entitlement_cache.dart';

class _FreeStoreBilling implements StoreBillingPort {
  @override
  bool get isConfigured => false;

  @override
  Stream<PremiumEntitlements> get entitlementStream => const Stream.empty();

  @override
  Future<PremiumEntitlements> refreshEntitlements() async =>
      PremiumEntitlements.free();

  @override
  Future<PremiumEntitlements> restorePurchases() async =>
      PremiumEntitlements.free();

  @override
  Future<PremiumEntitlements> purchasePackage(Package package) async =>
      PremiumEntitlements.free();
}

void main() {
  test(
    'resetCachedEntitlementsForAuthChange clears memory and disk cache',
    () async {
      final stamp = DateTime.now().microsecondsSinceEpoch;
      final cache = await EntitlementCache.open('/tmp/vm_ent_auth_$stamp.json');
      await cache.save(
        const PremiumEntitlements(
          tier: BillingTier.pro,
          entitlementIds: ['pro'],
          billingConnected: true,
          source: 'test',
        ),
      );

      final billing = createBillingServiceForTest(
        cache: cache,
        revenueCat: _FreeStoreBilling(),
      );

      billing.startListening();
      final loaded = await billing.loadEntitlements(forceRefresh: true);
      expect(loaded.isPro, isFalse);

      await billing.resetCachedEntitlementsForAuthChange();
      expect(await cache.load(), isNull);
      expect(await billing.loadCachedEntitlements(), isNull);

      if (await File('/tmp/vm_ent_auth_$stamp.json').exists()) {
        await File('/tmp/vm_ent_auth_$stamp.json').delete();
      }
    },
  );
}
