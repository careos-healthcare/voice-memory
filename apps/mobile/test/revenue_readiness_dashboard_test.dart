import 'package:archiveme_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:archiveme_mobile/features/revenue_metrics/revenue_funnel_analytics.dart';
import 'package:archiveme_mobile/features/revenue_metrics/revenue_readiness_engine.dart';
import 'package:archiveme_mobile/features/revenue_metrics/revenue_readiness_model.dart';
import 'package:archiveme_mobile/widgets/debug/revenue_readiness_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _userTranscript =
    'I had no capacity but I said yes again to the extra meeting today.';

RevenueReadinessRow _row(
  RevenueReadinessDashboard dashboard,
  RevenueReadinessRowId id,
) => dashboard.rows.firstWhere((row) => row.id == id);

void main() {
  setUp(() {
    ArchiveBetaMissionGate.resetForTest();
    RevenueFunnelAnalytics.resetForTest();
  });

  tearDown(() {
    ArchiveBetaMissionGate.resetForTest();
    RevenueFunnelAnalytics.resetForTest();
  });

  group('RevenueReadinessEngine', () {
    test('hidden when beta/debug flag is false', () {
      ArchiveBetaMissionGate.enabledOverride = false;
      expect(
        RevenueReadinessEngine.shouldShow(betaMissionEnabled: false),
        isFalse,
      );
    });

    test('visible when beta/debug flag is true', () {
      ArchiveBetaMissionGate.enabledOverride = true;
      expect(
        RevenueReadinessEngine.shouldShow(betaMissionEnabled: true),
        isTrue,
      );
    });

    test('shows proof seen when first_proof_seen exists', () {
      RevenueFunnelAnalytics.firstProofSeen(entryCount: 2, source: 'record');
      final dashboard = RevenueReadinessEngine.build();
      expect(
        _row(dashboard, RevenueReadinessRowId.proofSeen).status,
        RevenueReadinessStatus.seen,
      );
    });

    test('shows Pro interest when a Pro CTA event exists', () {
      RevenueFunnelAnalytics.proLockCtaTapped(
        source: 'record_post_save_first_proof',
        entryCount: 3,
        hasConfirmedRepeat: true,
      );
      final dashboard = RevenueReadinessEngine.build();
      expect(
        _row(dashboard, RevenueReadinessRowId.proInterest).status,
        isNot(RevenueReadinessStatus.missing),
      );
    });

    test('shows paywall reached when paywall_seen exists', () {
      RevenueFunnelAnalytics.paywallSeen(source: 'general_pro', isPro: false);
      final dashboard = RevenueReadinessEngine.build();
      expect(
        _row(dashboard, RevenueReadinessRowId.paywallReached).status,
        RevenueReadinessStatus.seen,
      );
    });

    test('shows purchase intent when paywall_purchase_cta_tapped exists', () {
      RevenueFunnelAnalytics.paywallPurchaseCtaTapped(
        source: 'general_pro',
        isPro: false,
      );
      final dashboard = RevenueReadinessEngine.build();
      expect(
        _row(dashboard, RevenueReadinessRowId.purchaseIntent).status,
        RevenueReadinessStatus.strong,
      );
    });

    test('shows restore checked when paywall_restore_tapped exists', () {
      RevenueFunnelAnalytics.paywallRestoreTapped(
        source: 'general_pro',
        isPro: false,
      );
      final dashboard = RevenueReadinessEngine.build();
      expect(
        _row(dashboard, RevenueReadinessRowId.restoreChecked).status,
        isNot(RevenueReadinessStatus.missing),
      );
    });

    test('shows dismissed when paywall_dismissed exists', () {
      RevenueFunnelAnalytics.paywallDismissed(
        source: 'general_pro',
        isPro: false,
      );
      final dashboard = RevenueReadinessEngine.build();
      expect(
        _row(dashboard, RevenueReadinessRowId.dismissed).status,
        RevenueReadinessStatus.seen,
      );
    });

    test('shows no personal content captured', () {
      RevenueFunnelAnalytics.firstProofSeen(entryCount: 1, source: 'record');
      final dashboard = RevenueReadinessEngine.build();
      expect(dashboard.noPersonalContentCaptured, isTrue);
      expect(
        _row(dashboard, RevenueReadinessRowId.noContentCaptured).status,
        RevenueReadinessStatus.strong,
      );
    });

    test('does not expose transcript/body text', () {
      RevenueFunnelAnalytics.firstProofSeen(entryCount: 1, source: 'record');
      RevenueFunnelAnalytics.paywallSeen(source: 'general_pro', isPro: false);
      final dashboard = RevenueReadinessEngine.build();
      final blob = dashboard.allDisplayedText.join(' ').toLowerCase();
      expect(blob, isNot(contains('transcript')));
      expect(blob, isNot(contains(_userTranscript)));
    });

    test('resetForTest clears dashboard state', () {
      RevenueFunnelAnalytics.paywallSeen(source: 'general_pro', isPro: false);
      RevenueFunnelAnalytics.resetForTest();
      final dashboard = RevenueReadinessEngine.build();
      expect(
        _row(dashboard, RevenueReadinessRowId.paywallReached).status,
        RevenueReadinessStatus.missing,
      );
    });
  });

  group('RevenueReadinessCard', () {
    testWidgets('hidden when beta/debug flag is false', (tester) async {
      ArchiveBetaMissionGate.enabledOverride = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RevenueReadinessCard(
              dashboard: RevenueReadinessEngine.build(),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('revenue_readiness_hidden')), findsOneWidget);
      expect(find.byKey(const Key('revenue_readiness_card')), findsNothing);
    });

    testWidgets('visible when beta/debug flag is true', (tester) async {
      ArchiveBetaMissionGate.enabledOverride = true;
      RevenueFunnelAnalytics.firstProofSeen(entryCount: 1, source: 'record');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RevenueReadinessCard(
              dashboard: RevenueReadinessEngine.build(),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('revenue_readiness_card')), findsOneWidget);
      expect(find.text(RevenueReadinessCopy.title), findsOneWidget);
      expect(find.text(RevenueReadinessCopy.proofSeen), findsOneWidget);
    });
  });
}