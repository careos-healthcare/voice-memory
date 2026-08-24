import 'package:archiveme_mobile/billing/archive_paywall_copy.dart';
import 'package:archiveme_mobile/billing/paywall_route_args.dart';
import 'package:archiveme_mobile/billing/paywall_source.dart';
import 'package:archiveme_mobile/features/paywall_alignment/paywall_alignment_copy.dart';
import 'package:archiveme_mobile/features/purchase_confidence/purchase_confidence_copy.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/billing/screens/paywall_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

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
      expect(
        ConsumerUiCopy.paywallHeadline,
        'You saw the first useful repeat.',
      );
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
        'Free shows the first useful proof. Pro keeps the longer trail.',
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
        const bullets = ConsumerUiCopy.paywallBullets;
        expect(bullets, PaywallAlignmentCopy.benefitBullets);
        expect(bullets, contains('Longer evidence history on this device'));
        expect(bullets, contains('More archived moments over weeks and months'));
        expect(bullets, contains('Continuity when patterns return or change'));
        expect(PaywallSourceCopy.generalPro.bullets, bullets);
      },
    );

    test(
      'differentiation focuses on trail continuity and trust avoids medical claims',
      () {
        expect(
          ConsumerUiCopy.paywallDifferentiation,
          'ArchiveMe is not trying to answer better than ChatGPT. It is trying to remember differently.',
        );
        expect(
          ConsumerUiCopy.paywallTrust,
          'Your saves stay free. Manage or cancel anytime in the App Store.',
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
        expect(blob, contains('longer trail'));
        expect(blob, contains('chatgpt'));
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
      expect(find.text(ConsumerUiCopy.paywallSubhead), findsNothing);
      expect(find.text(ConsumerUiCopy.paywallPrimaryValueBlock), findsNothing);
      expect(find.text(ConsumerUiCopy.paywallDifferentiation), findsNothing);
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
        expect(find.text(ConsumerUiCopy.paywallSubhead), findsNothing);
        expect(find.text(ConsumerUiCopy.restorePurchases), findsOneWidget);
        expect(find.text('Continue without Pro'), findsOneWidget);
        expect(find.text(ConsumerUiCopy.paywallDifferentiation), findsNothing);
        expect(find.text(PurchaseConfidenceCopy.cardTitle), findsOneWidget);
      },
    );
  });
}