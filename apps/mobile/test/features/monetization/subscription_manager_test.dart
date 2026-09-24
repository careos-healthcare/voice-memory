import 'dart:io';

import 'package:archiveme_mobile/billing/store_billing_port.dart';
import 'package:archiveme_mobile/features/monetization/subscription_manager.dart';
import 'package:archiveme_mobile/models/entitlement.dart';
import 'package:archiveme_mobile/storage/entitlement_cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class _Store implements StoreBillingPort {
  _Store({required this.configured, required this.current});

  final bool configured;
  PremiumEntitlements current;
  var purchaseCount = 0;

  @override
  bool get isConfigured => configured;

  @override
  Stream<PremiumEntitlements> get entitlementStream => Stream.value(current);

  @override
  Future<PremiumEntitlements> refreshEntitlements() async => current;

  @override
  Future<PremiumEntitlements> restorePurchases() async => current;

  @override
  Future<PremiumEntitlements> purchasePackage(Package package) async {
    purchaseCount += 1;
    return current;
  }
}

void main() {
  test('refresh uses the store and skips a webhook entitlement', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final cache = await EntitlementCache.open(
      '/tmp/vm_subscription_$stamp.json',
    );
    await cache.save(
      const PremiumEntitlements(
        tier: BillingTier.pro,
        entitlementIds: ['pro'],
        billingConnected: true,
        source: 'stripe_webhook',
      ),
    );
    final store = _Store(
      configured: true,
      current: const PremiumEntitlements(
        tier: BillingTier.pro,
        entitlementIds: ['archive_loop_pro'],
        billingConnected: true,
        source: 'revenuecat',
      ),
    );
    final manager = SubscriptionManager(store: store, cache: cache);

    final live = await manager.refresh(force: true);
    expect(live.entitlementIds, ['archive_loop_pro']);
    expect(live.source, 'revenuecat');
    expect((await cache.load())?.source, 'revenuecat');

    if (await File('/tmp/vm_subscription_$stamp.json').exists()) {
      await File('/tmp/vm_subscription_$stamp.json').delete();
    }
  });

  test('missing store configuration stays free', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final cache = await EntitlementCache.open(
      '/tmp/vm_subscription_free_$stamp.json',
    );
    final manager = SubscriptionManager(
      store: _Store(configured: false, current: PremiumEntitlements.free()),
      cache: cache,
    );

    final live = await manager.refresh(force: true);
    expect(live.isPro, isFalse);

    if (await File('/tmp/vm_subscription_free_$stamp.json').exists()) {
      await File('/tmp/vm_subscription_free_$stamp.json').delete();
    }
  });

  testWidgets('presentPaywall uses the injected presenter', (tester) async {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final cache = await EntitlementCache.open(
      '/tmp/vm_subscription_paywall_$stamp.json',
    );
    var presented = false;
    final manager = SubscriptionManager(
      store: _Store(configured: false, current: PremiumEntitlements.free()),
      cache: cache,
      presentPaywallOverride: (_) async {
        presented = true;
      },
    );

    await tester.pumpWidget(
      const MaterialApp(home: SizedBox(key: Key('paywall_host'))),
    );
    final context = tester.element(find.byKey(const Key('paywall_host')));
    await manager.presentPaywall(context);
    expect(presented, isTrue);

    if (await File('/tmp/vm_subscription_paywall_$stamp.json').exists()) {
      await File('/tmp/vm_subscription_paywall_$stamp.json').delete();
    }
  });
}
