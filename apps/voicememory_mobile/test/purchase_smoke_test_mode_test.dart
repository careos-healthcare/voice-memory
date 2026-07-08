import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/archive_loop_entitlement_ids.dart';
import 'package:voicememory_mobile/billing/revenuecat_service.dart';
import 'package:voicememory_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:voicememory_mobile/features/purchase_smoke_test/purchase_smoke_test_copy.dart';
import 'package:voicememory_mobile/features/purchase_smoke_test/purchase_smoke_test_engine.dart';
import 'package:voicememory_mobile/features/purchase_smoke_test/purchase_smoke_test_model.dart';
import 'package:voicememory_mobile/screens/testing_archiveme_screen.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/beta/purchase_smoke_test_card.dart';

PurchaseSmokeTestSnapshot _snapshotFrom(PurchaseSmokeTestInput input) =>
    PurchaseSmokeTestEngine.buildFromInput(input);

PurchaseSmokeTestCheck _check(
  PurchaseSmokeTestSnapshot snapshot,
  PurchaseSmokeTestCheckId id,
) =>
    snapshot.checks.firstWhere((check) => check.id == id);

Future<void> _pumpCard(
  WidgetTester tester, {
  required PurchaseSmokeTestSnapshot snapshot,
  PurchaseSmokeTestOpenPaywallCallback? onOpenPaywall,
}) async {
  ArchiveBetaMissionGate.enabledOverride = true;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: PurchaseSmokeTestCard(
            snapshotOverride: snapshot,
            onOpenPaywall: onOpenPaywall,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  final analyticsEvents = <({String event, Map<String, Object> props})>[];

  setUp(() async {
    PurchaseSmokeTestAnalytics.resetForTest();
    PurchaseSmokeTestAnalytics.captureForTest = (event, props) {
      analyticsEvents.add((event: event, props: props));
    };
    ArchiveBetaMissionGate.resetForTest();
    await AppServices.resetForTest(
      journalPath:
          'test/tmp/purchase_smoke_test/${DateTime.now().microsecondsSinceEpoch}_journal.json',
      prefsPath:
          'test/tmp/purchase_smoke_test/${DateTime.now().microsecondsSinceEpoch}_prefs.json',
      skipRevenueCat: true,
    );
  });

  tearDown(() {
    PurchaseSmokeTestAnalytics.resetForTest();
    ArchiveBetaMissionGate.resetForTest();
    analyticsEvents.clear();
  });

  group('PurchaseSmokeTestEngine', () {
    test('hidden when beta/debug flag is false', () {
      expect(
        PurchaseSmokeTestEngine.shouldShow(betaMissionEnabled: false),
        isFalse,
      );
    });

    test('renders all checks', () {
      final snapshot = _snapshotFrom(
        const PurchaseSmokeTestInput(
          billingConfigured: true,
          revenueCatInitialized: true,
          offeringsLoaded: true,
          currentOfferingExists: true,
          hasMonthlyPackage: true,
          hasAnnualPackage: true,
          entitlementReadable: true,
          isPro: false,
        ),
      );

      expect(snapshot.checks.length, 12);
      expect(
        snapshot.checks.map((check) => check.id),
        PurchaseSmokeTestCheckId.values,
      );
    });

    test('missing offerings shows blocked', () {
      final snapshot = _snapshotFrom(
        const PurchaseSmokeTestInput(
          billingConfigured: true,
          revenueCatInitialized: true,
          offeringsLoaded: false,
        ),
      );

      expect(
        _check(snapshot, PurchaseSmokeTestCheckId.offeringsLoaded).status,
        PurchaseSmokeTestStatus.blocked,
      );
      expect(
        _check(snapshot, PurchaseSmokeTestCheckId.currentOfferingExists).status,
        PurchaseSmokeTestStatus.unknown,
      );
    });

    test('missing monthly package shows warning or blocked on purchase CTA', () {
      final snapshot = _snapshotFrom(
        const PurchaseSmokeTestInput(
          billingConfigured: true,
          revenueCatInitialized: true,
          offeringsLoaded: true,
          currentOfferingExists: true,
          hasMonthlyPackage: false,
        ),
      );

      expect(
        _check(snapshot, PurchaseSmokeTestCheckId.monthlyPackageFound).status,
        PurchaseSmokeTestStatus.blocked,
      );
      expect(
        _check(snapshot, PurchaseSmokeTestCheckId.purchaseCtaVisible).status,
        PurchaseSmokeTestStatus.warning,
      );
    });

    test('restore visible check exists', () {
      final snapshot = _snapshotFrom(
        const PurchaseSmokeTestInput(
          billingConfigured: true,
          revenueCatInitialized: true,
        ),
      );

      final restoreCheck =
          _check(snapshot, PurchaseSmokeTestCheckId.restoreVisible);
      expect(restoreCheck.label, PurchaseSmokeTestCopy.checkRestoreVisible);
      expect(restoreCheck.status, PurchaseSmokeTestStatus.ready);
    });

    test('does not expose API keys or secrets', () {
      final snapshot = _snapshotFrom(
        PurchaseSmokeTestInput(
          billingConfigured: true,
          revenueCatInitialized: true,
          entitlementReadable: true,
          lastErrorSafe: PurchaseSmokeTestEngine.sanitizeDebugText(
            'configure failed sk_live_secret_key revenuecat_api_key=abc',
          ),
        ),
      );

      final blob = snapshot.allDisplayedText.join(' ').toLowerCase();
      expect(blob, isNot(contains('sk_live')));
      expect(blob, isNot(contains('api_key=abc')));
      expect(blob, contains('[redacted]'));
    });

    test('does not fake purchase success', () {
      final snapshot = _snapshotFrom(
        const PurchaseSmokeTestInput(
          billingConfigured: true,
          revenueCatInitialized: true,
          entitlementReadable: true,
          isPro: false,
        ),
      );

      expect(
        _check(snapshot, PurchaseSmokeTestCheckId.proUnlockReadable).detailLabel,
        PurchaseSmokeTestCopy.entitlementFree,
      );
      expect(snapshot.allDisplayedText.join(' '), isNot(contains('Purchase complete')));
    });

    test('entitlement IDs unchanged', () {
      expect(RevenueCatService.proEntitlementId, 'pro');
      expect(ArchiveLoopEntitlementIds.archiveLoopPro, 'archive_loop_pro');
    });

    test('metadata-only analytics on open', () {
      PurchaseSmokeTestAnalytics.opened(
        source: 'test',
        billingConfigured: true,
        offeringsLoaded: false,
        entitlementKnown: true,
      );

      final event = analyticsEvents.single;
      expect(event.event, PurchaseSmokeTestAnalytics.openedEvent);
      expect(
        event.props.keys.toSet(),
        {
          'source',
          'billing_configured',
          'offerings_loaded',
          'entitlement_known',
        },
      );
      expect(event.props['source'], 'test');
    });
  });

  group('PurchaseSmokeTestCard', () {
    testWidgets('paywall CTA uses existing paywall callback', (tester) async {
      var opened = false;

      await _pumpCard(
        tester,
        snapshot: _snapshotFrom(
          const PurchaseSmokeTestInput(
            billingConfigured: true,
            revenueCatInitialized: true,
            offeringsLoaded: true,
            currentOfferingExists: true,
            hasMonthlyPackage: true,
            entitlementReadable: true,
          ),
        ),
        onOpenPaywall: (_) => opened = true,
      );

      await tester.scrollUntilVisible(
        find.byKey(const Key('purchase_smoke_test_open_paywall')),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('purchase_smoke_test_open_paywall')));
      await tester.pump();

      expect(opened, isTrue);
      expect(
        analyticsEvents.any(
          (event) => event.event == PurchaseSmokeTestAnalytics.paywallOpenedEvent,
        ),
        isTrue,
      );
    });

    testWidgets('hidden when beta/debug flag is false', (tester) async {
      ArchiveBetaMissionGate.enabledOverride = false;
      await tester.pumpWidget(
        MaterialApp(
          home: PurchaseSmokeTestCard(
            snapshotOverride: _snapshotFrom(const PurchaseSmokeTestInput()),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('purchase_smoke_test_hidden')), findsOneWidget);
      expect(find.byKey(const Key('purchase_smoke_test_card')), findsNothing);
    });
  });

  group('TestingArchiveMeScreen', () {
    testWidgets('testing screen includes card', (tester) async {
      ArchiveBetaMissionGate.enabledOverride = true;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const TestingArchiveMeScreen(),
        ),
      );
      await tester.pump();
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.byType(PurchaseSmokeTestCard), findsOneWidget);
    });
  });
}
