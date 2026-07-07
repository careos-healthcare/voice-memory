import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/billing/archive_paywall_copy.dart';
import 'package:voicememory_mobile/billing/paywall_route_args.dart';
import 'package:voicememory_mobile/billing/paywall_source.dart';
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
    test('headline uses Keep the longer story', () {
      expect(ConsumerUiCopy.paywallHeadline, 'Keep the longer story.');
      expect(ArchivePaywallCopy.headline, ConsumerUiCopy.paywallHeadline);
      expect(
        PaywallSourceCopy.generalPro.headline,
        ConsumerUiCopy.paywallHeadline,
      );
    });

    test('subhead compares moments over time', () {
      expect(
        ConsumerUiCopy.paywallSubhead,
        'ArchiveMe is most useful when it can compare moments over time.',
      );
      expect(
        PaywallSourceCopy.generalPro.subheadline,
        ConsumerUiCopy.paywallSubhead,
      );
    });

    test('bullets cover longer history, reports, and evidence', () {
      final bullets = ConsumerUiCopy.paywallBullets;
      expect(bullets, contains('Longer archive history'));
      expect(bullets, contains('Private monthly reports'));
      expect(bullets, contains('Pattern and change evidence over time'));
      expect(bullets, contains('Export/private reports when available'));
      expect(
        bullets,
        contains('Built around preserving your archive'),
      );
      expect(PaywallSourceCopy.generalPro.bullets, bullets);
    });

    test('differentiation says not more chat and trust avoids medical claims', () {
      expect(
        ConsumerUiCopy.paywallDifferentiation,
        'Pro is not more chat. It keeps the evidence.',
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
      expect(find.text(ConsumerUiCopy.paywallSubhead), findsOneWidget);
      expect(find.text(ConsumerUiCopy.paywallPrimaryValueBlock), findsOneWidget);
      expect(find.text(ConsumerUiCopy.paywallDifferentiation), findsOneWidget);
      expect(find.text(ConsumerUiCopy.paywallTrust), findsOneWidget);
      expect(find.text(ConsumerUiCopy.paywallBackupLine), findsOneWidget);
      expect(find.text(ConsumerUiCopy.restorePurchases), findsOneWidget);
    });

    testWidgets('default paywall still renders restore and packaging CTAs', (
      tester,
    ) async {
      await _pumpPaywall(tester);

      expect(find.text(ConsumerUiCopy.restorePurchases), findsOneWidget);
      expect(find.text('Done'), findsAtLeast(1));
      expect(find.text(ConsumerUiCopy.paywallDifferentiation), findsOneWidget);
      expect(find.text(ConsumerUiCopy.paywallTrust), findsOneWidget);
    });
  });
}
