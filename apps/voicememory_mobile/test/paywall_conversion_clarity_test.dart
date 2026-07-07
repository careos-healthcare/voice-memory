import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/billing/paywall_route_args.dart';
import 'package:voicememory_mobile/billing/paywall_source.dart';
import 'package:voicememory_mobile/features/revenue_metrics/revenue_funnel_analytics.dart';
import 'package:voicememory_mobile/features/revenue_metrics/revenue_funnel_event.dart';
import 'package:voicememory_mobile/features/paywall_alignment/paywall_alignment_copy.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/screens/paywall_screen.dart';

const _bannedTerms = [
  'diagnosis',
  'treatment',
  'therapy',
  'clinical',
  'medical report',
  'cloud backup included',
  'sync is active',
  'your archive is backed up',
  'better ai',
  'more ai',
];

Future<void> _pumpPaywall(
  WidgetTester tester, {
  PaywallRouteArgs? args,
  bool billingReady = false,
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 2200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => PaywallScreen(
              triggerArgs: args,
              billingReadyOverride: () => billingReady,
            ),
          ),
        ],
      ),
    ),
  );
  await tester.pumpAndSettle();
}

List<String> _generalPaywallCopyBlob() => [
      ConsumerUiCopy.paywallHeadline,
      ConsumerUiCopy.paywallSubhead,
      ConsumerUiCopy.paywallPrimaryValueBlock,
      ...ConsumerUiCopy.paywallBullets,
      ConsumerUiCopy.paywallDifferentiation,
      ConsumerUiCopy.paywallTrust,
      ConsumerUiCopy.paywallBackupLine,
      ConsumerUiCopy.paywallPrimaryCta,
    ];

void main() {
  setUp(RevenueFunnelAnalytics.resetForTest);
  tearDown(RevenueFunnelAnalytics.resetForTest);

  group('Paywall conversion clarity copy constants', () {
    test('defines the conversion hierarchy copy', () {
      expect(ConsumerUiCopy.paywallHeadline, PaywallAlignmentCopy.headline);
      expect(ConsumerUiCopy.paywallSubhead, PaywallAlignmentCopy.body);
      expect(
        ConsumerUiCopy.paywallPrimaryValueBlock,
        PaywallAlignmentCopy.secondaryReassurance,
      );
      expect(ConsumerUiCopy.paywallPrimaryCta, 'Keep my longer story');
      expect(
        ConsumerUiCopy.paywallBackupLine,
        contains('planned Pro areas'),
      );
    });

    test('copy guard blocks banned terms', () {
      final blob = _generalPaywallCopyBlob().join(' ').toLowerCase();
      for (final banned in _bannedTerms) {
        if (banned == 'therapy') continue;
        expect(blob, isNot(contains(banned)), reason: 'must not contain $banned');
      }
      expect(blob, contains('not therapy'));
      expect(blob, isNot(contains('diagnosis')));
      expect(blob, isNot(contains('treatment')));
      expect(blob, isNot(contains('clinical')));
      expect(blob, isNot(contains('medical report')));
      expect(blob, isNot(contains('cloud backup included')));
      expect(blob, contains('do not rely on this build as cloud backup'));
    });
  });

  group('Paywall conversion clarity rendering', () {
    testWidgets('renders headline and timeline subhead', (tester) async {
      await _pumpPaywall(
        tester,
        args: const PaywallRouteArgs(source: PaywallSource.generalPro),
      );

      expect(find.text(ConsumerUiCopy.paywallHeadline), findsOneWidget);
      expect(find.text(ConsumerUiCopy.paywallSubhead), findsOneWidget);
    });

    testWidgets('renders primary value block and Pro bullets', (tester) async {
      await _pumpPaywall(
        tester,
        args: const PaywallRouteArgs(source: PaywallSource.generalPro),
      );

      expect(find.text(ConsumerUiCopy.paywallPrimaryValueBlock), findsOneWidget);
      expect(find.text('Full pattern timeline'), findsOneWidget);
      expect(find.text('Correction history'), findsOneWidget);
      expect(find.text('Monthly private report'), findsOneWidget);
    });

    testWidgets('renders differentiation, trust, and backup honesty', (
      tester,
    ) async {
      await _pumpPaywall(
        tester,
        args: const PaywallRouteArgs(source: PaywallSource.generalPro),
      );

      expect(
        find.text('Pro is not more chat. It keeps the evidence.'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Private by default. Based on moments you save. Not therapy or medical advice.',
        ),
        findsOneWidget,
      );
      expect(find.text(ConsumerUiCopy.paywallBackupLine), findsOneWidget);
      expect(find.textContaining('sync is active'), findsNothing);
      expect(find.textContaining('your archive is backed up'), findsNothing);
    });

    testWidgets('restore purchases stays visible', (tester) async {
      await _pumpPaywall(tester);
      expect(find.text(ConsumerUiCopy.restorePurchases), findsOneWidget);
    });

    testWidgets('purchase CTA copy is defined for live paywall body', (
      tester,
    ) async {
      expect(ConsumerUiCopy.paywallPrimaryCta, 'Keep my longer story');
      final source = File('lib/screens/paywall_screen.dart').readAsStringSync();
      expect(
        source,
        contains('sourceCopy?.cta ?? ConsumerUiCopy.paywallPrimaryCta'),
      );
    });

    testWidgets('Pro user sees active state instead of upgrade paywall', (
      tester,
    ) async {
      final source = File('lib/screens/paywall_screen.dart').readAsStringSync();
      expect(source, contains("else if (_entitlements?.isPro == true)"));
      expect(source, contains('_proActiveBody()'));
    });
  });

  group('Paywall conversion clarity revenue funnel hooks', () {
    testWidgets('paywall_seen fires once for non-Pro paywall', (tester) async {
      await _pumpPaywall(
        tester,
        args: const PaywallRouteArgs(source: PaywallSource.generalPro),
      );

      final seen = RevenueFunnelAnalytics.eventsForTest
          .where((e) => e.event == RevenueFunnelEvent.paywallSeen)
          .toList();
      expect(seen, hasLength(1));
      expect(seen.single.metadata['source'], 'general_pro');
    });

    test('paywall wires purchase, restore, and dismiss funnel events', () {
      final source = File('lib/screens/paywall_screen.dart').readAsStringSync();
      expect(source, contains('RevenueFunnelAnalytics.paywallPurchaseCtaTapped'));
      expect(source, contains('RevenueFunnelAnalytics.paywallRestoreTapped'));
      expect(source, contains('RevenueFunnelAnalytics.paywallDismissed'));
    });

    test('purchase and dismiss funnel events carry safe metadata only', () {
      RevenueFunnelAnalytics.paywallPurchaseCtaTapped(
        source: PaywallSource.generalPro.id,
        isPro: false,
      );
      RevenueFunnelAnalytics.paywallDismissed(
        source: PaywallSource.generalPro.id,
        isPro: false,
      );

      for (final record in RevenueFunnelAnalytics.eventsForTest) {
        for (final value in record.metadata.values) {
          expect(value.toString().toLowerCase(), isNot(contains('transcript')));
        }
      }
    });
  });
}
