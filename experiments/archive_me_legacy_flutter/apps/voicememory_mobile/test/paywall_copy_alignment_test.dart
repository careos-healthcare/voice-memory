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
    test('headline uses proof-first trail promise', () {
      expect(ConsumerUiCopy.paywallHeadline, 'Keep following what changes.');
      expect(ConsumerUiCopy.paywallHeadline, PaywallAlignmentCopy.headline);
      expect(ArchivePaywallCopy.headline, ConsumerUiCopy.paywallHeadline);
      expect(
        PaywallSourceCopy.generalPro.headline,
        ConsumerUiCopy.paywallHeadline,
      );
    });

    test('subhead sells the proof trail value', () {
      expect(
        ConsumerUiCopy.paywallSubhead,
        'Your recordings stay yours. Pro unlocks ongoing comparisons and deeper archive analysis.',
      );
      expect(ConsumerUiCopy.paywallSubhead, PaywallAlignmentCopy.body);
      expect(
        PaywallSourceCopy.generalPro.subheadline,
        ConsumerUiCopy.paywallSubhead,
      );
    });

    test(
      'bullets cover evidence history, weekly reviews, and timeline views',
      () {
        final bullets = ConsumerUiCopy.paywallBullets;
        expect(bullets, PaywallAlignmentCopy.benefitBullets);
        expect(bullets, contains('Ongoing comparisons'));
        expect(bullets, contains('Deeper archive analysis'));
        expect(bullets, contains('Additional configured remote transcription'));
        expect(PaywallSourceCopy.generalPro.bullets, bullets);
      },
    );

    test(
      'differentiation focuses on trail continuity and trust avoids medical claims',
      () {
        expect(
          ConsumerUiCopy.paywallDifferentiation,
          'Your recordings stay yours. Pro unlocks ongoing comparisons and deeper archive analysis.',
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

        expect(blob, isNot(contains('more ai')));
        expect(blob, isNot(contains('better chat')));
        expect(blob, isNot(contains('sync is active')));
        expect(blob, isNot(contains('cloud backup included')));
        expect(blob, isNot(contains('your archive is backed up')));
        expect(blob, contains('do not rely on this build as cloud backup'));
        expect(blob, contains('not therapy'));
        expect(blob, isNot(contains('diagnosis')));
        expect(blob, isNot(contains('treatment')));
      },
    );

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
      expect(find.text(ConsumerUiCopy.paywallSubhead), findsOneWidget);
      expect(
        find.text(ConsumerUiCopy.paywallPrimaryValueBlock),
        findsOneWidget,
      );
      expect(find.text(ConsumerUiCopy.paywallDifferentiation), findsOneWidget);
      expect(find.text(PurchaseConfidenceCopy.cardTitle), findsOneWidget);
      expect(
        find.byKey(const Key('paywall_subscription_details')),
        findsOneWidget,
      );
      expect(find.text(ConsumerUiCopy.restorePurchases), findsOneWidget);
    });

    testWidgets(
      'default paywall still renders restore and unavailable dismiss',
      (tester) async {
        await _pumpPaywall(tester);

        expect(find.text(ConsumerUiCopy.paywallHeadline), findsOneWidget);
        expect(find.text(ConsumerUiCopy.paywallSubhead), findsOneWidget);
        expect(find.text(ConsumerUiCopy.restorePurchases), findsOneWidget);
        expect(find.text('Continue without Pro'), findsOneWidget);
        expect(
          find.text(ConsumerUiCopy.paywallDifferentiation),
          findsOneWidget,
        );
        expect(find.text(PurchaseConfidenceCopy.cardTitle), findsOneWidget);
      },
    );
  });
}
