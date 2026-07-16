import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/billing/archive_loop_entitlement_ids.dart';
import 'package:voicememory_mobile/billing/archive_paywall_copy.dart';
import 'package:voicememory_mobile/billing/paywall_route_args.dart';
import 'package:voicememory_mobile/billing/paywall_source.dart';
import 'package:voicememory_mobile/billing/revenuecat_service.dart';
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
  group('PaywallAlignmentCopy', () {
    test('defines canonical headline and body', () {
      expect(PaywallAlignmentCopy.headline, 'Keep the longer proof trail.');
      expect(
        PaywallAlignmentCopy.body,
        contains('returned, changed, faded, or corrected'),
      );
      expect(
        PaywallAlignmentCopy.secondaryReassurance,
        'You stay in control. You can delete entries and correct what you saved.',
      );
    });

    test('defines six benefit bullets', () {
      expect(PaywallAlignmentCopy.benefitBullets, hasLength(6));
      expect(PaywallAlignmentCopy.benefitBullets, contains('Longer proof trail'));
      expect(PaywallAlignmentCopy.benefitBullets, contains('Correction history'));
      expect(
        PaywallAlignmentCopy.benefitBullets,
        contains('Current vs fading signals'),
      );
      expect(
        PaywallAlignmentCopy.benefitBullets,
        contains('Longer evidence trail'),
      );
      expect(
        PaywallAlignmentCopy.benefitBullets,
        contains('What returned over time'),
      );
      expect(
        PaywallAlignmentCopy.benefitBullets,
        contains('Trail continuity over weeks'),
      );
    });
  });

  group('ConsumerUiCopy paywall alignment', () {
    test('delegates paywall strings to alignment copy', () {
      expect(ConsumerUiCopy.paywallHeadline, PaywallAlignmentCopy.headline);
      expect(ConsumerUiCopy.paywallSubhead, PaywallAlignmentCopy.body);
      expect(
        ConsumerUiCopy.paywallPrimaryValueBlock,
        PaywallAlignmentCopy.secondaryReassurance,
      );
      expect(ConsumerUiCopy.paywallBullets, PaywallAlignmentCopy.benefitBullets);
      expect(
        PaywallSourceCopy.generalPro.headline,
        PaywallAlignmentCopy.headline,
      );
      expect(
        PaywallSourceCopy.generalPro.subheadline,
        PaywallAlignmentCopy.body,
      );
      expect(
        PaywallSourceCopy.generalPro.bullets,
        PaywallAlignmentCopy.benefitBullets,
      );
    });

    test('avoids generic AI chat and medical positioning', () {
      final blob = PaywallAlignmentCopy.allPaywallStrings().join(' ').toLowerCase();
      expect(blob, isNot(contains('more ai')));
      expect(blob, isNot(contains('better chat')));
      expect(blob, isNot(contains('therapy')));
      expect(blob, isNot(contains('diagnosis')));
      expect(blob, isNot(contains('treatment')));
      expect(blob, isNot(contains('unlimited journaling')));
    });
  });

  group('PaywallScreen alignment rendering', () {
    testWidgets('renders compact headline and subscription details', (
      tester,
    ) async {
      await _pumpPaywall(
        tester,
        args: const PaywallRouteArgs(source: PaywallSource.generalPro),
      );

      expect(find.text(PaywallAlignmentCopy.headline), findsOneWidget);
      expect(find.byKey(const Key('paywall_unavailable_body')), findsOneWidget);
      expect(find.byKey(const Key('paywall_subscription_details')), findsOneWidget);
      expect(
        find.text(PaywallAlignmentCopy.secondaryReassurance),
        findsNothing,
      );
      for (final bullet in PaywallAlignmentCopy.benefitBullets) {
        expect(find.text(bullet), findsNothing);
      }
    });

    testWidgets('still renders restore purchases on paywall', (tester) async {
      await _pumpPaywall(tester);

      expect(find.text(ConsumerUiCopy.restorePurchases), findsOneWidget);
    });

    test('purchase CTA constant remains wired for billing-ready paywall', () {
      expect(ConsumerUiCopy.paywallPrimaryCta, 'Keep the longer trail');
      expect(ArchivePaywallCopy.primaryCta, ConsumerUiCopy.paywallPrimaryCta);
    });
  });

  group('Protected billing areas', () {
    test('entitlement and product IDs unchanged', () {
      expect(ArchiveLoopEntitlementIds.archiveLoopPro, 'archive_loop_pro');
      expect(ArchiveLoopEntitlementIds.revenueCatLegacyPro, 'pro');
      expect(RevenueCatService.proEntitlementId, 'pro');
    });

    test('paywall purchase wiring unchanged', () {
      final source = File('lib/screens/paywall_screen.dart').readAsStringSync();
      expect(source, contains('ArchivePaywallCopy.checkingProAccess'));
      expect(source, contains('ArchivePaywallCopy.purchaseStarting'));
      expect(source, contains('ArchivePaywallCopy.restoreChecking'));
      expect(source, contains('_PaywallBusyKind.purchase'));
      expect(source, contains('_PaywallBusyKind.restore'));
    });

    test('archive paywall confidence strings unchanged', () {
      expect(ArchivePaywallCopy.primaryCta, 'Keep the longer trail');
      expect(
        ArchivePaywallCopy.purchaseSuccess,
        'Pro is active. ArchiveMe keeps the longer proof trail over time.',
      );
      expect(
        ArchivePaywallCopy.restoreSuccess,
        'Purchase restored. Pro is active.',
      );
    });
  });
}
