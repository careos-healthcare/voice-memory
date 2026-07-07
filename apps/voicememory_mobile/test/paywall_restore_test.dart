import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:voicememory_mobile/api/api_client.dart';
import 'package:voicememory_mobile/billing/billing_service.dart';
import 'package:voicememory_mobile/billing/restore_purchases_copy.dart';
import 'package:voicememory_mobile/billing/restore_purchases_flow.dart';
import 'package:voicememory_mobile/billing/store_billing_port.dart';
import 'package:voicememory_mobile/models/entitlement.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/screens/paywall_screen.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/storage/entitlement_cache.dart';

class _FakeStoreBilling implements StoreBillingPort {
  _FakeStoreBilling({
    this.configured = true,
    PremiumEntitlements? restoreResult,
  }) : _restoreResult = restoreResult ?? PremiumEntitlements.free();

  final bool configured;
  final PremiumEntitlements _restoreResult;

  int restoreCalls = 0;

  @override
  bool get isConfigured => configured;

  @override
  Stream<PremiumEntitlements> get entitlementStream => const Stream.empty();

  @override
  Future<PremiumEntitlements> restorePurchases() async {
    restoreCalls++;
    return _restoreResult;
  }

  @override
  Future<PremiumEntitlements> refreshEntitlements() async => _restoreResult;

  @override
  Future<PremiumEntitlements> purchasePackage(Package package) async =>
      _restoreResult;
}

void main() {
  group('Paywall restore purchases', () {
    late Directory tempDir;
    late _FakeStoreBilling store;
    late RestorePurchasesFlow restoreFlow;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('paywall_restore_test');
      store = _FakeStoreBilling(configured: true);
      final cache = await EntitlementCache.open(
        '${tempDir.path}/entitlements.json',
      );
      final billing = BillingService(
        ApiClient(baseUrl: 'http://test.invalid'),
        cache,
        store,
      );
      restoreFlow = RestorePurchasesFlow(
        billing: billing,
        isBillingConfigured: () => true,
      );
      await AppServices.resetForTest(
        journalPath: '${tempDir.path}/journal.json',
        skipRevenueCat: true,
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    Future<void> pumpPaywall(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => PaywallScreen(
                  restoreFlow: restoreFlow,
                  billingConfiguredForRestore: () => true,
                  billingReadyOverride: () => true,
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'restore calls RestorePurchasesFlow when offerings are unavailable',
      (tester) async {
        await pumpPaywall(tester);

      expect(find.text(ConsumerUiCopy.paywallHeadline), findsOneWidget);
      expect(
        find.textContaining('Purchases are not available right now'),
        findsOneWidget,
      );

        await tester.ensureVisible(find.text(ConsumerUiCopy.restorePurchases));
        await tester.tap(find.text(ConsumerUiCopy.restorePurchases));
        await tester.pumpAndSettle();

        expect(store.restoreCalls, 1);
      },
    );

    testWidgets('restore does not show plans unavailable copy', (tester) async {
      await pumpPaywall(tester);

      await tester.ensureVisible(find.text(ConsumerUiCopy.restorePurchases));
      await tester.tap(find.text(ConsumerUiCopy.restorePurchases));
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text('Plans are not available yet.'), findsNothing);
      expect(store.restoreCalls, 1);
    });

    testWidgets('purchase unavailable copy still shows when products missing', (
      tester,
    ) async {
      await pumpPaywall(tester);

      expect(
        find.text(ConsumerUiCopy.paywallSetupUnavailableBody),
        findsOneWidget,
      );
      expect(find.text('Continue with ArchiveMe Pro'), findsNothing);
    });
  });
}
