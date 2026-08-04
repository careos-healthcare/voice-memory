import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/screens/paywall_screen.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/subscriptions/domain/subscription_models.dart';

import 'subscriptions/fake_subscription_repository.dart';
import 'support/widget_test_pump.dart';

const _offers = [
  SubscriptionOffer(
    id: 'monthly-offer',
    productIdentifier: 'com.voicememory.app.pro.monthly',
    price: r'$4.99 monthly',
    period: SubscriptionPeriod.monthly,
  ),
  SubscriptionOffer(
    id: 'yearly-offer',
    productIdentifier: 'com.voicememory.app.pro.annual',
    price: r'$39.99 yearly',
    period: SubscriptionPeriod.annual,
    hasFreeTrial: true,
    introductoryPrice: r'$0.00',
    introductoryPeriod: 'P7D',
    introductoryCycles: 1,
  ),
  SubscriptionOffer(
    id: 'legacy-lifetime',
    productIdentifier: 'legacy.lifetime',
    price: r'$99.99',
    period: SubscriptionPeriod.lifetime,
  ),
];

const _pro = SubscriptionState(
  tier: SubscriptionTier.pro,
  entitlementIds: ['archive_loop_pro'],
  billingConnected: true,
  origin: SubscriptionStateOrigin.store,
  verification: SubscriptionVerification.verified,
);

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('paywall_purchase_test');
    await AppServices.resetForTest(
      journalPath: '${tempDir.path}/journal.json',
      skipRevenueCat: true,
    );
  });

  tearDownAll(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Future<void> pumpPaywall(
    WidgetTester tester,
    FakeSubscriptionRepository repository,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 3000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => PaywallScreen(
                billingReadyOverride: () => true,
                delayedPaywallProofGateOverride: () => true,
                subscriptionRepository: repository,
                entitlementLoader: () async => SubscriptionState.free(),
              ),
            ),
          ],
        ),
      ),
    );
    await pumpUntilFound(tester, find.text('Continue'));
  }

  testWidgets('yearly purchase uses the validated yearly offer', (
    tester,
  ) async {
    final repository = FakeSubscriptionRepository(
      offers: _offers,
      purchaseResult: _pro,
    );
    await pumpPaywall(tester, repository);

    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await pumpUntil(tester, () => repository.purchaseCalls == 1);

    expect(repository.purchasedOfferIds, ['yearly-offer']);
    expect(repository.state.isPro, isTrue);
  });

  testWidgets(
    'shows localized prices and real intro terms but hides lifetime',
    (tester) async {
      final repository = FakeSubscriptionRepository(offers: _offers);
      await pumpPaywall(tester, repository);

      expect(find.text(r'$39.99 yearly'), findsOneWidget);
      expect(find.text(r'$4.99 monthly'), findsOneWidget);
      expect(find.text('Free for P7D'), findsOneWidget);
      expect(find.text(r'$99.99'), findsNothing);

      final semantics = tester.getSemantics(find.text(r'$39.99 yearly'));
      expect(semantics.label, contains(r'$39.99 yearly'));
      expect(semantics.label, contains('Free for P7D'));
    },
  );

  testWidgets('monthly purchase uses the validated monthly offer', (
    tester,
  ) async {
    final repository = FakeSubscriptionRepository(
      offers: _offers,
      purchaseResult: _pro,
    );
    await pumpPaywall(tester, repository);

    await tester.ensureVisible(find.text(r'$4.99 monthly'));
    await tester.tap(find.text(r'$4.99 monthly'));
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await pumpUntil(tester, () => repository.purchaseCalls == 1);

    expect(repository.purchasedOfferIds, ['monthly-offer']);
  });

  testWidgets('cancelled purchase does not grant Pro', (tester) async {
    final repository = FakeSubscriptionRepository(
      offers: _offers,
      purchaseError: const SubscriptionPurchaseException(
        SubscriptionPurchaseFailureKind.cancelled,
        cause: 'cancelled',
      ),
    );
    await pumpPaywall(tester, repository);

    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await pumpUntil(tester, () => repository.purchaseCalls == 1);

    expect(repository.state.isPro, isFalse);
  });

  testWidgets('temporary purchase failure leaves purchase recoverable', (
    tester,
  ) async {
    final repository = FakeSubscriptionRepository(
      offers: _offers,
      purchaseError: const SubscriptionPurchaseException(
        SubscriptionPurchaseFailureKind.temporary,
        cause: 'network',
      ),
    );
    await pumpPaywall(tester, repository);

    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await pumpUntil(tester, () => repository.purchaseCalls == 1);
    await tester.pump();

    expect(repository.state.isPro, isFalse);
    expect(
      find.text(
        'The store is temporarily unreachable. Check your connection and try again.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('restore reports no active subscription', (tester) async {
    final repository = FakeSubscriptionRepository(offers: _offers);
    await pumpPaywall(tester, repository);

    await tester.ensureVisible(find.text('Restore purchases'));
    await tester.tap(find.text('Restore purchases'));
    await pumpUntil(tester, () => repository.restoreCalls == 1);

    expect(
      find.text('No previous Pro purchase was found on this Apple ID.'),
      findsOneWidget,
    );
  });

  testWidgets('restore remains available when packages are unavailable', (
    tester,
  ) async {
    final repository = FakeSubscriptionRepository(
      availability: SubscriptionAvailability.notConfigured,
      offers: const [],
    );
    await pumpPaywall(tester, repository);

    await tester.ensureVisible(find.text('Restore purchases'));
    await tester.tap(find.text('Restore purchases'));
    await pumpUntil(tester, () => repository.restoreCalls == 1);

    expect(repository.restoreCalls, 1);
  });

  testWidgets('backend unavailable restore gives an actionable error', (
    tester,
  ) async {
    final repository = FakeSubscriptionRepository(
      offers: _offers,
      restoreError: const SubscriptionRestoreException(cause: 'offline'),
    );
    await pumpPaywall(tester, repository);

    await tester.ensureVisible(find.text('Restore purchases'));
    await tester.tap(find.text('Restore purchases'));
    await pumpUntil(tester, () => repository.restoreCalls == 1);
    await tester.pump();

    expect(
      find.text('We could not check purchases right now. Please try again.'),
      findsOneWidget,
    );
  });
}
