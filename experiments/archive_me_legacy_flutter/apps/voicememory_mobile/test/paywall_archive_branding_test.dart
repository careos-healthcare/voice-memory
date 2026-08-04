import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/billing/archive_paywall_plans.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/screens/paywall_screen.dart';
import 'package:voicememory_mobile/billing/paywall_unavailable_state.dart';
import 'package:voicememory_mobile/widgets/archive_paywall/paywall_unavailable_fallback.dart';

void main() {
  test('paywall primary CTA uses proof-trail language', () {
    expect(ConsumerUiCopy.paywallPrimaryCta, 'Keep the longer trail');
  });

  test('empty offerings fallback copy is consumer-safe', () {
    expect(
      ConsumerUiCopy.paywallSetupUnavailableBody,
      'Purchases are not available right now.',
    );
    expect(PaywallUnavailableFallback.benefits.length, 3);
    expect(PaywallUnavailableFallback.benefits.first, 'Ongoing comparisons');
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

      expect(find.text(ConsumerUiCopy.paywallHeadline), findsOneWidget);
      expect(find.textContaining('VoiceMemory Pro'), findsNothing);
      expect(find.textContaining('VoiceMemory'), findsNothing);
      expect(find.byKey(const Key('paywall_unavailable_body')), findsOneWidget);
      final unavailableBody = tester
          .widget<Text>(find.byKey(const Key('paywall_unavailable_body')))
          .data!;
      expect(
        unavailableBody,
        contains('Purchases are not available right now'),
      );
      expect(
        unavailableBody,
        contains(
          'Monthly and yearly plans will appear when App Store products finish loading',
        ),
      );
      expect(find.text('Longer evidence history'), findsNothing);
      expect(find.text('Private monthly reports'), findsNothing);
      expect(find.text(ConsumerUiCopy.restorePurchases), findsOneWidget);
      expect(
        find.text(PaywallUnavailableState.continueWithoutProLabel),
        findsOneWidget,
      );
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
