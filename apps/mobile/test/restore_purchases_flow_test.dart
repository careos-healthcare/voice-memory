import 'dart:async';
import 'dart:io';

import 'package:archiveme_mobile/billing/billing_async_guard.dart';
import 'package:archiveme_mobile/billing/billing_service.dart';
import 'package:archiveme_mobile/billing/restore_purchases_copy.dart';
import 'package:archiveme_mobile/billing/restore_purchases_feedback.dart';
import 'package:archiveme_mobile/billing/restore_purchases_flow.dart';
import 'package:archiveme_mobile/billing/revenuecat_service.dart';
import 'package:archiveme_mobile/billing/store_billing_port.dart';
import 'package:archiveme_mobile/models/entitlement.dart';
import 'package:archiveme_mobile/storage/entitlement_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'helpers/test_billing_service.dart';

class _FakeStoreBilling implements StoreBillingPort {
  _FakeStoreBilling({
    this.configured = true,
    PremiumEntitlements? restoreResult,
    this.restoreError,
    PremiumEntitlements? refreshResult,
    this.restoreDelay = Duration.zero,
  }) : _restoreResult = restoreResult ?? PremiumEntitlements.free(),
       _refreshResult =
           refreshResult ?? restoreResult ?? PremiumEntitlements.free();

  final bool configured;
  final PremiumEntitlements _restoreResult;
  final PremiumEntitlements _refreshResult;
  final Object? restoreError;
  final Duration restoreDelay;

  int restoreCalls = 0;
  int refreshCalls = 0;

  @override
  bool get isConfigured => configured;

  @override
  Stream<PremiumEntitlements> get entitlementStream => const Stream.empty();

  @override
  Future<PremiumEntitlements> restorePurchases() async {
    restoreCalls++;
    if (restoreError != null) throw restoreError!;
    await Future<void>.delayed(restoreDelay);
    return _restoreResult;
  }

  @override
  Future<PremiumEntitlements> refreshEntitlements() async {
    refreshCalls++;
    return _refreshResult;
  }

  @override
  Future<PremiumEntitlements> purchasePackage(Package package) async =>
      _restoreResult;
}

PremiumEntitlements _proEntitlements() => const PremiumEntitlements(
  tier: BillingTier.pro,
  entitlementIds: ['pro'],
  billingConnected: true,
  source: 'revenuecat',
);

Future<({BillingService billing, EntitlementCache cache, Directory dir})>
_openBillingHarness(_FakeStoreBilling store) async {
  final dir = await Directory.systemTemp.createTemp('restore_flow_test');
  final cache = await EntitlementCache.open('${dir.path}/entitlements.json');
  final billing = createBillingServiceWithTestOverrides(
    cache: cache,
    revenueCat: store,
  );
  return (billing: billing, cache: cache, dir: dir);
}

void main() {
  group('RestorePurchasesCopy', () {
    test('uses App Store-safe restore messaging', () {
      expect(RestorePurchasesCopy.restorePurchases, 'Restore purchases');
      expect(
        RestorePurchasesCopy.purchaseRestored,
        'Purchase restored. Pro is active.',
      );
      expect(
        RestorePurchasesCopy.noActivePurchase,
        'No previous Pro purchase was found on this Apple ID.',
      );
      expect(
        RestorePurchasesCopy.restoreError,
        'We could not check purchases right now. Please try again.',
      );
    });
  });

  group('RestorePurchasesFlow', () {
    late Directory tempDir;
    late _FakeStoreBilling store;
    late BillingService billing;
    late RestorePurchasesFlow flow;

    setUp(() async {
      store = _FakeStoreBilling();
      final harness = await _openBillingHarness(store);
      tempDir = harness.dir;
      billing = harness.billing;
      flow = RestorePurchasesFlow(
        billing: billing,
        isBillingConfigured: () => store.configured,
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('restore success updates entitlement state', () async {
      store = _FakeStoreBilling(
        restoreResult: _proEntitlements(),
        refreshResult: _proEntitlements(),
      );
      final harness = await _openBillingHarness(store);
      tempDir = harness.dir;
      flow = RestorePurchasesFlow(
        billing: harness.billing,
        isBillingConfigured: () => store.configured,
      );

      final result = await flow.restore();

      expect(result.outcome, RestorePurchasesOutcome.restored);
      expect(result.isPro, isTrue);
      expect(result.userMessage, RestorePurchasesCopy.purchaseRestored);
      expect(store.restoreCalls, 1);
    });

    test('restore with no active purchase shows no-purchase message', () async {
      final result = await flow.restore();

      expect(result.outcome, RestorePurchasesOutcome.noPurchase);
      expect(result.userMessage, RestorePurchasesCopy.noActivePurchase);
    });

    test('restore error shows retryable error', () async {
      store = _FakeStoreBilling(restoreError: StateError('network down'));
      final harness = await _openBillingHarness(store);
      tempDir = harness.dir;
      flow = RestorePurchasesFlow(
        billing: harness.billing,
        isBillingConfigured: () => store.configured,
      );

      final result = await flow.restore();

      expect(result.outcome, RestorePurchasesOutcome.error);
      expect(result.userMessage, RestorePurchasesCopy.restoreError);
    });

    test('restore timeout maps to billing unavailable copy', () async {
      store = _FakeStoreBilling(
        restoreError: BillingOperationException(
          'Billing operation timed out (restorePurchases)',
        ),
      );
      final harness = await _openBillingHarness(store);
      tempDir = harness.dir;
      flow = RestorePurchasesFlow(
        billing: harness.billing,
        isBillingConfigured: () => store.configured,
      );

      final result = await flow.restore();

      expect(result.outcome, RestorePurchasesOutcome.unavailable);
      expect(result.userMessage, RestorePurchasesCopy.billingUnavailable);
      expect(
        result.userMessage,
        'We could not check purchases right now. Please try again.',
      );
      expect(result.userMessage, isNot(contains('Plans are not available')));
    });

    test('restore outcomes never use plans unavailable copy', () async {
      expect(
        RestorePurchasesCopy.billingUnavailable,
        isNot(contains('Plans are not available yet')),
      );
      expect(
        RestorePurchasesCopy.restoreError,
        isNot(contains('Plans are not available yet')),
      );
    });

    test(
      'missing RevenueCat API key shows unavailable without crashing',
      () async {
        store = _FakeStoreBilling(configured: false);
        flow = RestorePurchasesFlow(
          billing: billing,
          isBillingConfigured: () => store.configured,
        );

        final result = await flow.restore();

        expect(result.outcome, RestorePurchasesOutcome.unavailable);
        expect(store.restoreCalls, 0);
        expect(result.userMessage, RestorePurchasesCopy.restoreError);
      },
    );

    test('restore button cannot be double tapped while loading', () async {
      store = _FakeStoreBilling(
        restoreResult: _proEntitlements(),
        restoreDelay: const Duration(milliseconds: 50),
      );
      final harness = await _openBillingHarness(store);
      tempDir = harness.dir;
      flow = RestorePurchasesFlow(
        billing: harness.billing,
        isBillingConfigured: () => store.configured,
      );

      final first = flow.restore();
      expect(flow.isBusy, isTrue);

      final second = await flow.restore();
      expect(second.outcome, RestorePurchasesOutcome.skippedBusy);
      expect(store.restoreCalls, 1);

      await first;
      expect(flow.isBusy, isFalse);
    });
  });

  group('BillingService.restoreNative', () {
    late Directory tempDir;
    late EntitlementCache cache;
    late _FakeStoreBilling store;
    late BillingService billing;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('billing_restore_test');
      cache = await EntitlementCache.open('${tempDir.path}/entitlements.json');
      store = _FakeStoreBilling();
      billing = createBillingServiceWithTestOverrides(
        cache: cache,
        revenueCat: store,
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('restore success persists Pro to entitlement cache', () async {
      store = _FakeStoreBilling(
        restoreResult: _proEntitlements(),
        refreshResult: _proEntitlements(),
      );
      billing = createBillingServiceWithTestOverrides(
        cache: cache,
        revenueCat: store,
      );

      final ent = await billing.restoreNative();

      expect(ent.isPro, isTrue);
      expect((await cache.load())?.isPro, isTrue);
      expect(store.restoreCalls, 1);
      expect(store.refreshCalls, greaterThanOrEqualTo(1));
    });

    test('restore with no purchase clears stale Pro cache', () async {
      await cache.save(_proEntitlements());
      store = _FakeStoreBilling(
        restoreResult: PremiumEntitlements.free(),
        refreshResult: PremiumEntitlements.free(),
      );
      billing = createBillingServiceWithTestOverrides(
        cache: cache,
        revenueCat: store,
      );

      final ent = await billing.restoreNative();

      expect(ent.isPro, isFalse);
      expect(await cache.load(), isNull);
    });
  });

  test('missing RevenueCat key does not crash initialize', () async {
    final rc = RevenueCatService.instance;
    await rc.initialize();
    expect(rc.isConfigured, isFalse);
  });

  group('RestorePurchasesFeedback', () {
    test('timeout outcome surfaces restore-specific copy', () {
      const result = RestorePurchasesResult(
        outcome: RestorePurchasesOutcome.unavailable,
      );
      expect(
        RestorePurchasesFeedback.messageFor(result),
        RestorePurchasesCopy.billingUnavailable,
      );
      expect(
        RestorePurchasesFeedback.messageFor(result),
        isNot(contains('Plans are not available yet')),
      );
    });

    test('skipped busy is the only silent outcome', () {
      const result = RestorePurchasesResult(
        outcome: RestorePurchasesOutcome.skippedBusy,
      );
      expect(RestorePurchasesFeedback.messageFor(result), isNull);
    });
  });
}