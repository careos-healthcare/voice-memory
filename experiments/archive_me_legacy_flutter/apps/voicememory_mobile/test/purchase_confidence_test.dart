import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/billing/archive_loop_entitlement_ids.dart';
import 'package:voicememory_mobile/billing/archive_paywall_copy.dart';
import 'package:voicememory_mobile/billing/paywall_objection_follow_up.dart';
import 'package:voicememory_mobile/billing/paywall_route_args.dart';
import 'package:voicememory_mobile/billing/paywall_source.dart';
import 'package:voicememory_mobile/billing/revenuecat_service.dart';
import 'package:voicememory_mobile/features/purchase_confidence/purchase_confidence_analytics.dart';
import 'package:voicememory_mobile/features/purchase_confidence/purchase_confidence_copy.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/screens/paywall_screen.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/paywall/purchase_confidence_card.dart';
import 'package:voicememory_mobile/widgets/pro/pro_lock_moment_card.dart';

Future<void> _pumpPaywall(WidgetTester tester, {PaywallRouteArgs? args}) async {
  await tester.binding.setSurfaceSize(const Size(390, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => PaywallScreen(
              triggerArgs: args,
              delayedPaywallProofGateOverride: () => true,
            ),
          ),
        ],
      ),
    ),
  );
  await tester.pump();
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (find
            .byKey(const Key('purchase_confidence_card'))
            .evaluate()
            .isNotEmpty ||
        find
            .byKey(const Key('paywall_unavailable_body'))
            .evaluate()
            .isNotEmpty) {
      break;
    }
  }
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    PurchaseConfidenceAnalytics.resetForTest();
    PaywallObjectionFollowUp.resetSessionForTest();
    final tmp = Directory.systemTemp.createTempSync('vm_purchase_conf_');
    await AppServices.resetForTest(
      journalPath: '${tmp.path}/journal.json',
      skipRevenueCat: true,
    );
  });

  group('PurchaseConfidenceCopy', () {
    test('defines card title, body, bullets, and footer', () {
      expect(PurchaseConfidenceCopy.cardTitle, 'Private by default');
      expect(
        PurchaseConfidenceCopy.body,
        'Your saved moments stay yours. You can delete entries, correct ArchiveMe, and restore purchases if needed.',
      );
      expect(PurchaseConfidenceCopy.trustBullets, hasLength(5));
      expect(
        PurchaseConfidenceCopy.footer,
        'Pro does not make medical, therapy, or diagnostic claims.',
      );
    });

    test('avoids therapy positioning beyond safety disclaimer', () {
      final blob = PurchaseConfidenceCopy.allCardStrings()
          .join(' ')
          .toLowerCase();
      expect(blob, contains('does not make medical'));
      expect(blob, isNot(contains('therapy session')));
      expect(blob, isNot(contains('diagnosis')));
      expect(blob, isNot(contains('more ai')));
      expect(blob, isNot(contains('better chat')));
    });
  });

  group('PurchaseConfidenceCard widget', () {
    testWidgets('renders title, body, and all trust bullets', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: PurchaseConfidenceCard(
              source: 'general_pro',
              surface: 'paywall_screen',
              entryCount: 3,
            ),
          ),
        ),
      );

      expect(find.text('Private by default'), findsOneWidget);
      expect(
        find.text(
          'Your saved moments stay yours. You can delete entries, correct ArchiveMe, and restore purchases if needed.',
        ),
        findsOneWidget,
      );
      for (final bullet in PurchaseConfidenceCopy.trustBullets) {
        expect(find.text(bullet), findsOneWidget);
      }
      expect(
        find.text('Pro does not make medical, therapy, or diagnostic claims.'),
        findsOneWidget,
      );
    });

    testWidgets('seen analytics emits metadata only', (tester) async {
      Map<String, Object>? captured;

      PurchaseConfidenceAnalytics.captureForTest = (event, props) {
        captured = props;
      };

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: PurchaseConfidenceCard(
              source: 'general_pro',
              surface: 'paywall_screen',
              entryCount: 4,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(captured, isNotNull);
      expect(captured!['source'], 'general_pro');
      expect(captured!['surface'], 'paywall_screen');
      expect(captured!['entry_count'], 4);
      expect(captured!.keys.toSet(), {'source', 'surface', 'entry_count'});
    });
  });

  group('Paywall placement', () {
    testWidgets('paywall renders purchase confidence card once', (
      tester,
    ) async {
      await _pumpPaywall(
        tester,
        args: const PaywallRouteArgs(source: PaywallSource.generalPro),
      );

      expect(find.byKey(const Key('purchase_confidence_card')), findsOneWidget);
      expect(find.text('Private by default'), findsOneWidget);
      expect(find.text(ConsumerUiCopy.restorePurchases), findsOneWidget);
      expect(find.text(ConsumerUiCopy.paywallPrimaryCta), findsNothing);
      expect(ConsumerUiCopy.paywallPrimaryCta, 'Keep the longer trail');
    });

    testWidgets('paywall does not duplicate private-by-default trust line', (
      tester,
    ) async {
      await _pumpPaywall(
        tester,
        args: const PaywallRouteArgs(source: PaywallSource.generalPro),
      );

      expect(find.text('Private by default'), findsOneWidget);
      expect(find.text(ConsumerUiCopy.paywallTrust), findsNothing);
    });
  });

  group('Pro bridge compact trust', () {
    testWidgets('pro lock bridge shows compact trust line not full card', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ProLockMomentCard(
              entryCount: 3,
              hasFirstProof: true,
              hasConfirmedRepeat: true,
              onSeePro: () {},
              onDismiss: () {},
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('purchase_confidence_compact_trust')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('purchase_confidence_card')), findsNothing);
      expect(
        find.text(PurchaseConfidenceCopy.compactTrustLine),
        findsOneWidget,
      );
    });
  });

  group('Protected billing areas', () {
    test('entitlement IDs unchanged', () {
      expect(ArchiveLoopEntitlementIds.archiveLoopPro, 'archive_loop_pro');
      expect(ArchiveLoopEntitlementIds.revenueCatLegacyPro, 'pro');
      expect(RevenueCatService.proEntitlementId, 'archive_loop_pro');
    });

    test('paywall purchase wiring unchanged', () {
      final source = File('lib/screens/paywall_screen.dart').readAsStringSync();
      expect(source, contains('ArchivePaywallCopy.purchaseStarting'));
      expect(source, contains('ArchivePaywallCopy.restoreChecking'));
      expect(source, contains('_PaywallBusyKind.restore'));
      expect(source, isNot(contains('proEntitlementId = ')));
    });

    test('restore and purchase copy constants unchanged', () {
      expect(ArchivePaywallCopy.primaryCta, 'Keep the longer trail');
      expect(
        ArchivePaywallCopy.restoreSuccess,
        'Purchase restored. Pro is active.',
      );
    });
  });
}
