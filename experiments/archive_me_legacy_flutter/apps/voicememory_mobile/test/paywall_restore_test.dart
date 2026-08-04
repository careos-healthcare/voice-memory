import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/billing/archive_paywall_copy.dart';
import 'package:voicememory_mobile/billing/restore_purchases_flow.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/screens/paywall_screen.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/subscriptions/domain/subscription_models.dart';

import 'subscriptions/fake_subscription_repository.dart';
import 'support/widget_test_pump.dart';

void main() {
  group('Paywall restore purchases', () {
    late Directory tempDir;
    late FakeSubscriptionRepository repository;
    late RestorePurchasesFlow restoreFlow;

    setUpAll(() async {
      tempDir = await Directory.systemTemp.createTemp('paywall_restore_test');
      await AppServices.resetForTest(
        journalPath: '${tempDir.path}/journal.json',
        skipRevenueCat: true,
      );
    });

    setUp(() {
      repository = FakeSubscriptionRepository();
      restoreFlow = RestorePurchasesFlow(
        repository: repository,
        isBillingConfigured: () => true,
      );
    });

    tearDownAll(() async {
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
                  subscriptionRepository: repository,
                  entitlementLoader: () async => repository.state,
                ),
              ),
            ],
          ),
        ),
      );
      await pumpUntilFound(tester, find.text(ConsumerUiCopy.paywallHeadline));
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
        await pumpUntil(
          tester,
          () => repository.restoreCalls == 1,
          reason: 'restore request to complete',
        );

        expect(repository.restoreCalls, 1);
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
      expect(repository.restoreCalls, 1);
    });

    testWidgets('purchase unavailable copy still shows when products missing', (
      tester,
    ) async {
      await pumpPaywall(tester);

      expect(find.byKey(const Key('paywall_unavailable_body')), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('paywall_unavailable_body')))
            .data,
        contains(ConsumerUiCopy.paywallSetupUnavailableBody),
      );
      expect(find.text('Continue with ArchiveMe Pro'), findsNothing);
    });

    testWidgets('restored entitlement updates paywall to active Pro', (
      tester,
    ) async {
      repository = FakeSubscriptionRepository(
        restoreResult: const SubscriptionState(
          tier: SubscriptionTier.pro,
          entitlementIds: ['archive_loop_pro'],
          billingConnected: true,
          origin: SubscriptionStateOrigin.store,
          verification: SubscriptionVerification.verified,
        ),
      );
      restoreFlow = RestorePurchasesFlow(
        repository: repository,
        isBillingConfigured: () => true,
      );
      await pumpPaywall(tester);

      await tester.ensureVisible(find.text(ConsumerUiCopy.restorePurchases));
      await tester.tap(find.text(ConsumerUiCopy.restorePurchases));
      await pumpUntilFound(
        tester,
        find.text(ArchivePaywallCopy.proActiveTitle),
      );

      expect(repository.restoreCalls, 1);
      expect(repository.state.isPro, isTrue);
    });
  });
}
