import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/billing/archive_paywall_copy.dart';
import 'package:voicememory_mobile/billing/paywall_route_args.dart';
import 'package:voicememory_mobile/billing/paywall_source.dart';
import 'package:voicememory_mobile/features/purchase_confidence/purchase_confidence_copy.dart';
import 'package:voicememory_mobile/features/paywall_alignment/paywall_alignment_copy.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/screens/paywall_screen.dart';

Future<void> _pumpPaywall(WidgetTester tester, {PaywallRouteArgs? args}) async {
  await tester.binding.setSurfaceSize(const Size(390, 2200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => PaywallScreen(triggerArgs: args),
          ),
        ],
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Paywall copy alignment v1', () {
    test('headline uses Keep the longer proof trail', () {
      expect(ConsumerUiCopy.paywallHeadline, PaywallAlignmentCopy.headline);
      expect(ArchivePaywallCopy.headline, ConsumerUiCopy.paywallHeadline);
      expect(
        PaywallSourceCopy.generalPro.headline,
        ConsumerUiCopy.paywallHeadline,
      );
    });

    test('subhead sells the proof trail value', () {
      expect(ConsumerUiCopy.paywallSubhead, PaywallAlignmentCopy.body);
      expect(
        PaywallSourceCopy.generalPro.subheadline,
        ConsumerUiCopy.paywallSubhead,
      );
    });

    test('bullets cover proof trail, corrections, returns, and continuity', () {
      final bullets = ConsumerUiCopy.paywallBullets;
      expect(bullets, PaywallAlignmentCopy.benefitBullets);
      expect(bullets, contains('Longer proof trail'));
      expect(bullets, contains('Correction history'));
      expect(bullets, contains('Current vs fading signals'));
      expect(bullets, contains('Longer evidence trail'));
      expect(bullets, contains('What returned over time'));
      expect(bullets, contains('Trail continuity over weeks'));
      expect(PaywallSourceCopy.generalPro.bullets, bullets);
    });

    test('differentiation says not more chat and trust avoids medical claims', () {
      expect(
        ConsumerUiCopy.paywallDifferentiation,
        'The value is not more chat. It is the longer evidence trail.',
      );
      expect(
        ConsumerUiCopy.paywallTrust,
        'Private by default. Based on moments you save. Not therapy or medical advice.',
      );

      final blob = [
        ConsumerUiCopy.paywallHeadline,
        ConsumerUiCopy.paywallSubhead,
        ConsumerUiCopy.paywallPrimaryValueBlock,
        ...ConsumerUiCopy.paywallBullets,
        ConsumerUiCopy.paywallDifferentiation,
        ConsumerUiCopy.paywallTrust,
        ConsumerUiCopy.paywallBackupLine,
      ].join(' ').toLowerCase();

      expect(blob, contains('not more chat'));
      expect(blob, isNot(contains('more ai')));
      expect(blob, isNot(contains('better chat')));
      expect(blob, isNot(contains('sync is active')));
      expect(blob, isNot(contains('cloud backup included')));
      expect(blob, isNot(contains('your archive is backed up')));
      expect(blob, contains('do not rely on this build as cloud backup'));
      expect(blob, contains('not therapy'));
      expect(blob, isNot(contains('diagnosis')));
      expect(blob, isNot(contains('treatment')));
    });

    testWidgets('general Pro paywall renders aligned copy with CTAs', (
      tester,
    ) async {
      await _pumpPaywall(
        tester,
        args: const PaywallRouteArgs(source: PaywallSource.generalPro),
      );

      expect(find.text(ConsumerUiCopy.paywallHeadline), findsOneWidget);
      expect(find.byKey(const Key('paywall_unavailable_body')), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('paywall_unavailable_body')))
            .data,
        contains(ConsumerUiCopy.paywallSetupUnavailableBody),
      );
      expect(find.text(ConsumerUiCopy.paywallPrimaryValueBlock), findsNothing);
      expect(find.text(ConsumerUiCopy.paywallDifferentiation), findsNothing);
      expect(find.text(PurchaseConfidenceCopy.cardTitle), findsNothing);
      expect(find.byKey(const Key('paywall_subscription_details')), findsOneWidget);
      expect(find.text(ConsumerUiCopy.restorePurchases), findsOneWidget);
    });

    testWidgets('default paywall still renders restore and unavailable dismiss', (
      tester,
    ) async {
      await _pumpPaywall(tester);

      expect(find.text(ConsumerUiCopy.restorePurchases), findsOneWidget);
      expect(find.text('Continue without Pro'), findsOneWidget);
      expect(find.text(ConsumerUiCopy.paywallDifferentiation), findsNothing);
      expect(find.text(PurchaseConfidenceCopy.cardTitle), findsNothing);
    });
  });
}
