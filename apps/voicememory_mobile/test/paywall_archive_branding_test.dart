import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/billing/archive_paywall_plans.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/screens/paywall_screen.dart';
import 'package:voicememory_mobile/widgets/archive_paywall/paywall_unavailable_fallback.dart';

void main() {
  test('paywall title constant is ArchiveMe Pro', () {
    expect(ConsumerUiCopy.paywallPrimaryCta, contains('ArchiveMe Pro'));
  });

  test('empty offerings fallback copy is consumer-safe', () {
    expect(
      ConsumerUiCopy.paywallSetupUnavailableBody,
      'Purchases are not available right now.',
    );
    expect(PaywallUnavailableFallback.benefits.length, 5);
      expect(
        PaywallUnavailableFallback.benefits.first,
        'Longer archive history',
      );
  });

  test('annual appears before monthly when both present', () {
    final plans = orderedPaywallPlans(hasAnnual: true, hasMonthly: true);
    expect(plans.first, PaywallPlanKind.annual);
  });

  testWidgets(
    'paywall screen shows ArchiveMe fallback when billing unavailable',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const PaywallScreen(),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ArchiveMe Pro'), findsOneWidget);
      expect(find.text(ConsumerUiCopy.paywallHeadline), findsOneWidget);
      expect(find.textContaining('VoiceMemory Pro'), findsNothing);
      expect(find.textContaining('VoiceMemory'), findsNothing);
      expect(
        find.textContaining('Purchases are not available right now'),
        findsOneWidget,
      );
      expect(
        find.text('Longer archive history'),
        findsOneWidget,
      );
      expect(find.text('Private monthly reports'), findsOneWidget);
      expect(find.text(ConsumerUiCopy.restorePurchases), findsOneWidget);
      expect(find.text('Done'), findsAtLeast(1));
    },
  );

  testWidgets('restore tap does not crash on unavailable paywall', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const PaywallScreen(),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text(ConsumerUiCopy.restorePurchases));
    await tester.tap(
      find.text(ConsumerUiCopy.restorePurchases),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
