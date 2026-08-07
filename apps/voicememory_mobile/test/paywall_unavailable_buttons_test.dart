import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'helpers/test_billing_service.dart';
import 'package:voicememory_mobile/billing/billing_service.dart';
import 'package:voicememory_mobile/billing/paywall_rejection_reason.dart';
import 'package:voicememory_mobile/billing/paywall_unavailable_state.dart';
import 'package:voicememory_mobile/billing/restore_purchases_flow.dart';
import 'package:voicememory_mobile/billing/revenuecat_service.dart';
import 'package:voicememory_mobile/billing/subscription_copy.dart';
import 'package:voicememory_mobile/billing/store_billing_port.dart';
import 'package:voicememory_mobile/features/paywall/archive_loop_entitlements.dart';
import 'package:voicememory_mobile/features/pro_packaging/pro_value_copy.dart';
import 'package:voicememory_mobile/models/entitlement.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/screens/paywall_screen.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/storage/entitlement_cache.dart';
import 'package:voicememory_mobile/widgets/archive_paywall/paywall_unavailable_fallback.dart';

class _FakeStoreBilling implements StoreBillingPort {
  _FakeStoreBilling({
    this.configured = true,
    PremiumEntitlements? restoreResult,
  }) : _restoreResult = restoreResult ?? PremiumEntitlements.free();

  final bool configured;
  final PremiumEntitlements _restoreResult;

  int restoreCalls = 0;
  int purchaseCalls = 0;

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
  Future<PremiumEntitlements> purchasePackage(Package package) async {
    purchaseCalls++;
    return _restoreResult;
  }
}

void main() {
  group('PaywallUnavailableState', () {
    test(
      'primary dismiss label is Continue without Pro when benefits hidden',
      () {
        expect(
          PaywallUnavailableState.primaryDismissLabel(hideBenefits: true),
          PaywallUnavailableState.continueWithoutProLabel,
        );
        expect(
          PaywallUnavailableState.primaryDismissLabel(hideBenefits: false),
          PaywallUnavailableState.doneLabel,
        );
      },
    );
  });

  group('PaywallUnavailableFallback widget', () {
    testWidgets('Continue without Pro dismisses without purchase', (
      tester,
    ) async {
      var dismissed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PaywallUnavailableFallback(
              body: ConsumerUiCopy.paywallSetupUnavailableBody,
              hideBenefits: true,
              onDismiss: () => dismissed = true,
            ),
          ),
        ),
      );

      expect(
        find.text(PaywallUnavailableState.continueWithoutProLabel),
        findsOneWidget,
      );
      expect(find.text('Continue'), findsNothing);
      await tester.tap(
        find.byKey(const Key('paywall_unavailable_continue_without_pro')),
      );
      await tester.pump();
      expect(dismissed, isTrue);
    });

    testWidgets('Done dismisses when benefits are shown', (tester) async {
      var dismissed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PaywallUnavailableFallback(
              body: ConsumerUiCopy.paywallSetupUnavailableBody,
              onDismiss: () => dismissed = true,
            ),
          ),
        ),
      );

      expect(find.text('Done'), findsOneWidget);
      await tester.tap(find.byKey(const Key('paywall_unavailable_done')));
      await tester.pump();
      expect(dismissed, isTrue);
    });

    testWidgets('Try again calls retry handler', (tester) async {
      var retried = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PaywallUnavailableFallback(
              body: ConsumerUiCopy.paywallSetupUnavailableBody,
              hideBenefits: true,
              showRetry: true,
              onRetry: () => retried = true,
              onDismiss: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('paywall_unavailable_try_again')));
      await tester.pump();
      expect(retried, isTrue);
    });

    testWidgets('Try again shows inline spinner while retrying', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PaywallUnavailableFallback(
              body: ConsumerUiCopy.paywallSetupUnavailableBody,
              hideBenefits: true,
              showRetry: true,
              retrying: true,
              onRetry: () {},
              onDismiss: () {},
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(ConsumerUiCopy.restorePurchases), findsOneWidget);
    });

    testWidgets('restore purchases remains visible', (tester) async {
      var restored = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PaywallUnavailableFallback(
              body: ConsumerUiCopy.paywallSetupUnavailableBody,
              hideBenefits: true,
              onRestore: () => restored = true,
              onDismiss: () {},
            ),
          ),
        ),
      );

      expect(find.text(ConsumerUiCopy.restorePurchases), findsOneWidget);
      await tester.tap(find.byKey(const Key('paywall_unavailable_restore')));
      await tester.pump();
      expect(restored, isTrue);
    });
  });

  group('PaywallScreen unavailable purchases', () {
    late Directory tempDir;
    late _FakeStoreBilling store;
    late RestorePurchasesFlow restoreFlow;

    setUp(() async {
      PaywallRejectionCapture.resetSessionForTest();
      PaywallRejectionCapture.promptShownThisSession = true;
      RevenueCatService.fetchOfferingsOverrideForTest = () async => null;
      tempDir = await Directory.systemTemp.createTemp(
        'paywall_unavailable_btns',
      );
      store = _FakeStoreBilling(configured: true);
      restoreFlow = RestorePurchasesFlow(
        billing: createBillingServiceWithTestOverrides(
          cache: await EntitlementCache.open(
            '${tempDir.path}/entitlements.json',
          ),
          revenueCat: store,
        ),
        isBillingConfigured: () => true,
      );
      await AppServices.resetForTest(
        journalPath: '${tempDir.path}/journal.json',
        skipRevenueCat: true,
      );
    });

    tearDown(() async {
      PaywallRejectionCapture.resetSessionForTest();
      RevenueCatService.fetchOfferingsOverrideForTest = null;
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    Future<void> pumpUnavailablePaywall(
      WidgetTester tester, {
      required bool billingReady,
      String initialLocation = '/paywall',
    }) async {
      await tester.binding.setSurfaceSize(const Size(390, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final router = GoRouter(
        initialLocation: initialLocation,
        routes: [
          GoRoute(
            path: '/record',
            builder: (context, state) =>
                const Scaffold(body: Text('Record fallback')),
          ),
          GoRoute(
            path: '/paywall',
            builder: (context, state) => PaywallScreen(
              restoreFlow: restoreFlow,
              billingConfiguredForRestore: () => true,
              billingReadyOverride: () => billingReady,
            ),
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump();
      for (var i = 0; i < 300; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        final loading = find
            .byType(CircularProgressIndicator)
            .evaluate()
            .isNotEmpty;
        final unavailable =
            find
                .byKey(const Key('paywall_unavailable_body'))
                .evaluate()
                .isNotEmpty ||
            find
                .text(ConsumerUiCopy.paywallBillingNotConfigured)
                .evaluate()
                .isNotEmpty ||
            find
                .text(PaywallUnavailableState.continueWithoutProLabel)
                .evaluate()
                .isNotEmpty;
        if (!loading && unavailable) {
          break;
        }
      }
    }

    testWidgets(
      'unavailable state shows honest copy and Continue without Pro label',
      (tester) async {
        await pumpUnavailablePaywall(tester, billingReady: true);

        expect(
          find.byKey(const Key('paywall_unavailable_body')),
          findsOneWidget,
        );
        final unavailableBody = tester
            .widget<Text>(find.byKey(const Key('paywall_unavailable_body')))
            .data!;
        expect(unavailableBody, contains(SubscriptionCopy.paywallNoOfferings));
        expect(
          unavailableBody,
          contains(ConsumerUiCopy.paywallUnavailablePlansLoading),
        );
        expect(
          find.text(PaywallUnavailableState.continueWithoutProLabel),
          findsOneWidget,
        );
        expect(find.text(ConsumerUiCopy.paywallPrimaryCta), findsNothing);
        expect(find.text(ConsumerUiCopy.restorePurchases), findsOneWidget);
      },
    );

    testWidgets('Continue without Pro dismisses to previous route safely', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: '/record',
        routes: [
          GoRoute(
            path: '/record',
            builder: (context, state) => Scaffold(
              body: TextButton(
                onPressed: () => context.push('/paywall'),
                child: const Text('Open paywall'),
              ),
            ),
          ),
          GoRoute(
            path: '/paywall',
            builder: (context, state) => PaywallScreen(
              restoreFlow: restoreFlow,
              billingConfiguredForRestore: () => true,
              billingReadyOverride: () => true,
            ),
          ),
        ],
      );
      await tester.binding.setSurfaceSize(const Size(390, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump();
      await tester.tap(find.text('Open paywall'));
      await tester.pump();
      for (var i = 0; i < 300; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        if (find
            .text(PaywallUnavailableState.continueWithoutProLabel)
            .evaluate()
            .isNotEmpty) {
          break;
        }
      }
      expect(
        find.text(PaywallUnavailableState.continueWithoutProLabel),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('paywall_unavailable_continue_without_pro')),
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      expect(find.text('Open paywall'), findsOneWidget);
      expect(store.purchaseCalls, 0);
    });

    testWidgets('Continue without Pro falls back to Record when no pop route', (
      tester,
    ) async {
      await pumpUnavailablePaywall(
        tester,
        billingReady: true,
        initialLocation: '/paywall',
      );

      await tester.tap(
        find.byKey(const Key('paywall_unavailable_continue_without_pro')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Record fallback'), findsOneWidget);
      expect(store.purchaseCalls, 0);
    });

    testWidgets('Try again reloads offerings without purchasing', (
      tester,
    ) async {
      RevenueCatService.fetchOfferingsOverrideForTest = () async => null;
      await pumpUnavailablePaywall(tester, billingReady: true);

      expect(
        find.byKey(const Key('paywall_unavailable_try_again')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('paywall_unavailable_try_again')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 25));

      expect(store.purchaseCalls, 0);
      expect(
        find.text(PaywallUnavailableState.continueWithoutProLabel),
        findsOneWidget,
      );
    });

    testWidgets('restore purchases remains available and does not purchase', (
      tester,
    ) async {
      await pumpUnavailablePaywall(tester, billingReady: true);

      await tester.ensureVisible(find.text(ConsumerUiCopy.restorePurchases));
      await tester.tap(find.text(ConsumerUiCopy.restorePurchases));
      await tester.pump();
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(store.restoreCalls, 1);
      expect(store.purchaseCalls, 0);
    });

    testWidgets('billing not configured still uses Continue without Pro', (
      tester,
    ) async {
      await pumpUnavailablePaywall(tester, billingReady: false);

      expect(find.byKey(const Key('paywall_unavailable_body')), findsOneWidget);
      final unavailableBody = tester
          .widget<Text>(find.byKey(const Key('paywall_unavailable_body')))
          .data!;
      expect(
        unavailableBody,
        contains(ConsumerUiCopy.paywallBillingNotConfigured),
      );
      expect(
        unavailableBody,
        contains(ConsumerUiCopy.paywallUnavailablePlansLoading),
      );
      expect(
        find.text(PaywallUnavailableState.continueWithoutProLabel),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('paywall_unavailable_try_again')),
        findsNothing,
      );
    });

    test('ProPackagingCopy exposes continue without Pro label', () {
      expect(
        ProPackagingCopy.continueWithoutProCta,
        PaywallUnavailableState.continueWithoutProLabel,
      );
    });

    testWidgets('unavailable paywall shows subscription Terms and Privacy', (
      tester,
    ) async {
      await pumpUnavailablePaywall(tester, billingReady: false);

      expect(
        find.byKey(const Key('paywall_subscription_details')),
        findsOneWidget,
      );
      expect(find.text(ArchiveLoopPaywallCopy.eulaLabel), findsOneWidget);
      expect(
        find.text(ArchiveLoopPaywallCopy.privacyPolicyLabel),
        findsOneWidget,
      );
      expect(
        find.text(ArchiveLoopPaywallCopy.subscriptionPlansUnavailable),
        findsOneWidget,
      );
    });
  });
}
