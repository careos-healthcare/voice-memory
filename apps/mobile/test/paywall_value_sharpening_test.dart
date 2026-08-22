import 'dart:io';

import 'package:archiveme_mobile/billing/archive_loop_entitlement_ids.dart';
import 'package:archiveme_mobile/billing/archive_paywall_copy.dart';
import 'package:archiveme_mobile/billing/paywall_route_args.dart';
import 'package:archiveme_mobile/billing/paywall_source.dart';
import 'package:archiveme_mobile/billing/revenuecat_service.dart';
import 'package:archiveme_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:archiveme_mobile/features/paywall_alignment/paywall_alignment_copy.dart';
import 'package:archiveme_mobile/features/paywall_value_sharpening/paywall_value_sharpening_analytics.dart';
import 'package:archiveme_mobile/features/paywall_value_sharpening/paywall_value_sharpening_copy.dart';
import 'package:archiveme_mobile/features/pro_value/pro_value_copy.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/screens/paywall_screen.dart';
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
  setUp(PaywallValueSharpeningAnalytics.resetForTest);

  group('PaywallValueSharpeningCopy', () {
    test('proof source uses proof-first trail headline', () {
      expect(
        PaywallValueSharpeningCopy.headlineFor(PaywallSource.valueMoment),
        ProValueCopy.headline,
      );
      expect(
        PaywallSourceCopy.forSource(PaywallSource.valueMoment).headline,
        PaywallValueSharpeningCopy.proofConnectedHeadline,
      );
    });

    test('generic source uses proof-first trail headline', () {
      expect(
        PaywallValueSharpeningCopy.headlineFor(PaywallSource.generalPro),
        ProValueCopy.headline,
      );
      expect(
        PaywallSourceCopy.forSource(PaywallSource.generalPro).headline,
        PaywallAlignmentCopy.headline,
      );
    });

    test('defines trail-focused body and differentiation line', () {
      expect(PaywallValueSharpeningCopy.body, ProValueCopy.headline);
      expect(
        PaywallValueSharpeningCopy.proofConnectedLine,
        ProValueCopy.subheadline,
      );
      expect(
        PaywallValueSharpeningCopy.proofConnectedLine,
        isNot(contains('more chat')),
      );
      expect(PaywallValueSharpeningCopy.cta, 'Keep the longer trail');
    });

    test('defines trail benefit bullets only', () {
      expect(PaywallValueSharpeningCopy.benefitBullets, hasLength(3));
      expect(
        PaywallValueSharpeningCopy.benefitBullets,
        contains('Longer evidence history'),
      );
      expect(
        PaywallValueSharpeningCopy.benefitBullets,
        contains('Weekly archive reviews'),
      );
      expect(
        PaywallValueSharpeningCopy.benefitBullets,
        contains('Timeline views over time'),
      );
    });

    test('avoids fake testimonials and medical claims', () {
      final blob = PaywallValueSharpeningCopy.allPaywallStrings()
          .join(' ')
          .toLowerCase();
      for (final banned in PaywallValueSharpeningCopy.bannedFakeClaims) {
        expect(blob, isNot(contains(banned)));
      }
      for (final line in PaywallValueSharpeningCopy.allPaywallStrings()) {
        expect(ProofSurfaceAdviceGuard.passes(line), isTrue, reason: line);
      }
      expect(blob, isNot(contains('therapy')));
      expect(blob, isNot(contains('diagnosis')));
      expect(blob, isNot(contains('treatment')));
      expect(blob, isNot(contains('more ai')));
    });
  });

  group('PaywallValueSharpeningAnalytics', () {
    test('metadata-only analytics', () {
      final events = <String, Map<String, Object>>{};
      PaywallValueSharpeningAnalytics.captureForTest = (event, props) {
        events[event] = props;
      };

      PaywallValueSharpeningAnalytics.seen(
        source: 'value_moment',
        surface: 'paywall_screen',
        proofConnected: true,
        entryCount: 3,
      );

      expect(events.keys, contains(PaywallValueSharpeningAnalytics.seenEvent));
      final props = events[PaywallValueSharpeningAnalytics.seenEvent]!;
      expect(props.keys, containsAll(['source', 'surface', 'proof_connected']));
      expect(props['source'], 'value_moment');
      expect(props['surface'], 'paywall_screen');
      expect(props['proof_connected'], 1);
      expect(props['entry_count'], 3);
      expect(props.keys, isNot(contains('transcript')));
    });
  });

  group('PaywallScreen sharpening rendering', () {
    testWidgets('proof source renders proof-first headline and copy', (
      tester,
    ) async {
      await _pumpPaywall(
        tester,
        args: const PaywallRouteArgs(source: PaywallSource.valueMoment),
      );

      expect(
        find.text(PaywallValueSharpeningCopy.proofConnectedHeadline),
        findsOneWidget,
      );
      expect(find.byKey(const Key('paywall_unavailable_body')), findsOneWidget);
      expect(find.text(PaywallValueSharpeningCopy.body), findsOneWidget);
      expect(
        find.text(PaywallValueSharpeningCopy.proofConnectedLine),
        findsNothing,
      );
    });

    testWidgets('generic source renders compact unavailable paywall copy', (
      tester,
    ) async {
      await _pumpPaywall(
        tester,
        args: const PaywallRouteArgs(source: PaywallSource.generalPro),
      );

      expect(find.text(PaywallAlignmentCopy.headline), findsOneWidget);
      expect(find.byKey(const Key('paywall_unavailable_body')), findsOneWidget);
      expect(
        find.text(PaywallAlignmentCopy.secondaryReassurance),
        findsNothing,
      );
      expect(
        find.text(PaywallValueSharpeningCopy.proofConnectedLine),
        findsNothing,
      );
      for (final bullet in PaywallAlignmentCopy.benefitBullets) {
        expect(find.text(bullet), findsNothing);
      }
    });

    testWidgets('restore purchases remains visible', (tester) async {
      await _pumpPaywall(tester);

      expect(find.text(ConsumerUiCopy.restorePurchases), findsOneWidget);
    });
  });

  group('Protected billing areas', () {
    test('entitlement and product IDs unchanged', () {
      expect(ArchiveLoopEntitlementIds.archiveLoopPro, 'archive_loop_pro');
      expect(ArchiveLoopEntitlementIds.revenueCatLegacyPro, 'pro');
      expect(RevenueCatService.proEntitlementId, 'pro');
    });

    test('purchase buttons unchanged', () {
      final source = File('lib/screens/paywall_screen.dart').readAsStringSync();
      expect(source, contains('_PaywallBusyKind.purchase'));
      expect(source, contains('_PaywallBusyKind.restore'));
      expect(source, contains('ArchivePaywallCopy.purchaseStarting'));
      expect(source, contains('ArchivePaywallCopy.restoreChecking'));
      expect(
        source,
        contains('sourceCopy?.cta ?? ConsumerUiCopy.paywallPrimaryCta'),
      );
    });

    test('RevenueCat purchase copy constants unchanged', () {
      expect(
        ArchivePaywallCopy.restoreSuccess,
        'Purchase restored. Pro is active.',
      );
      expect(
        ArchivePaywallCopy.restoreEmpty,
        'No previous Pro purchase was found on this Apple ID.',
      );
    });
  });
}