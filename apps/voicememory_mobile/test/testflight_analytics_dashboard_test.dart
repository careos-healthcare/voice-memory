import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/archive_loop_entitlement_ids.dart';
import 'package:voicememory_mobile/billing/revenuecat_service.dart';
import 'package:voicememory_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:voicememory_mobile/features/revenue_metrics/revenue_funnel_analytics.dart';
import 'package:voicememory_mobile/features/testflight_metrics/testflight_metrics_analytics.dart';
import 'package:voicememory_mobile/features/testflight_metrics/testflight_metrics_copy.dart';
import 'package:voicememory_mobile/features/testflight_metrics/testflight_metrics_engine.dart';
import 'package:voicememory_mobile/features/testflight_metrics/testflight_metrics_model.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/beta/testflight_metrics_dashboard_card.dart';

TestFlightMetricsDashboard _sampleDashboard() {
  return TestFlightMetricsEngine.buildFromInput(
    const TestFlightMetricsInput(
      firstMomentSaved: 1,
      secondMomentSaved: 1,
      thirdMomentSaved: 1,
      firstProofReached: 1,
      timelineProofSeen: true,
      usefulCount: 1,
      tooVagueCount: 1,
      alreadyKnewCount: 1,
      notRelevantCount: 1,
      purchaseTapped: 1,
      returnedAfterFirstProof: 1,
      skippedThenReturned: 1,
    ),
  );
}

void main() {
  setUp(() {
    ArchiveBetaMissionGate.resetForTest();
    TestFlightMetricsAnalytics.resetForTest();
    RevenueFunnelAnalytics.resetForTest();
  });

  tearDown(() {
    ArchiveBetaMissionGate.resetForTest();
    TestFlightMetricsAnalytics.resetForTest();
    RevenueFunnelAnalytics.resetForTest();
  });

  group('TestFlightMetricsEngine', () {
    test('hidden when beta/debug flag is false', () {
      expect(
        TestFlightMetricsEngine.shouldShow(betaMissionEnabled: false),
        isFalse,
      );
    });

    test('visible when beta flag is true', () {
      expect(
        TestFlightMetricsEngine.shouldShow(betaMissionEnabled: true),
        isTrue,
      );
    });

    test('buildFromInput includes all 10 core metrics', () {
      final dashboard = _sampleDashboard();
      expect(dashboard.coreMetrics, hasLength(10));
      expect(
        dashboard.coreMetrics.map((row) => row.label),
        TestFlightMetricsCopy.coreMetricLabels,
      );
    });

    test('marks paywall intent from session funnel event', () {
      RevenueFunnelAnalytics.paywallPurchaseCtaTapped(
        source: 'general_pro',
        isPro: false,
      );
      final dashboard = TestFlightMetricsEngine.buildFromInput(
        const TestFlightMetricsInput(sessionPaywallIntent: true),
      );
      final paywallRow = dashboard.coreMetrics.firstWhere(
        (row) => row.id == TestFlightMetricId.paywallIntent,
      );
      expect(paywallRow.seen, isTrue);
    });
  });

  group('TestFlightMetricsDashboardCard', () {
    testWidgets('hidden when beta flag false', (tester) async {
      ArchiveBetaMissionGate.enabledOverride = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: TestFlightMetricsDashboardCard(
              dashboardOverride: _sampleDashboard(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('testflight_metrics_dashboard_hidden')), findsOneWidget);
      expect(find.text('TestFlight beta metrics'), findsNothing);
    });

    testWidgets('visible when beta flag true and renders all metrics', (
      tester,
    ) async {
      ArchiveBetaMissionGate.enabledOverride = true;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: TestFlightMetricsDashboardCard(
              dashboardOverride: _sampleDashboard(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('testflight_metrics_dashboard_card')), findsOneWidget);
      expect(find.text('TestFlight beta metrics'), findsOneWidget);
      expect(
        find.text('Track whether users reach the ArchiveMe proof moment.'),
        findsOneWidget,
      );
      for (final label in TestFlightMetricsCopy.coreMetricLabels) {
        expect(find.text(label), findsOneWidget);
      }
      for (final label in TestFlightMetricsCopy.retentionMetricLabels) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('does not render transcript-like private text', (tester) async {
      ArchiveBetaMissionGate.enabledOverride = true;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: TestFlightMetricsDashboardCard(
              dashboardOverride: _sampleDashboard(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('I had no capacity'), findsNothing);
      expect(find.textContaining('entry_id'), findsNothing);
      expect(find.textContaining('@'), findsNothing);
    });

    testWidgets('avoids medical claims in dashboard copy', (tester) async {
      ArchiveBetaMissionGate.enabledOverride = true;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: TestFlightMetricsDashboardCard(
              dashboardOverride: _sampleDashboard(),
            ),
          ),
        ),
      );
      await tester.pump();

      final blob = TestFlightMetricsCopy.coreMetricLabels.join(' ').toLowerCase();
      expect(blob, isNot(contains('therapy')));
      expect(blob, isNot(contains('diagnosis')));
      expect(blob, isNot(contains('medical')));
    });

    test('seen analytics emits metadata only', () {
      Map<String, Object>? captured;
      TestFlightMetricsAnalytics.captureForTest = (event, props) {
        captured = props;
      };

      TestFlightMetricsAnalytics.seen(
        source: 'settings',
        surface: 'settings',
        metricCount: 10,
      );

      expect(captured, isNotNull);
      expect(captured!.keys.toSet(), {'source', 'surface', 'metric_count'});
      expect(captured!['metric_count'], 10);
    });
  });

  group('Protected billing areas', () {
    test('entitlement IDs unchanged', () {
      expect(ArchiveLoopEntitlementIds.archiveLoopPro, 'archive_loop_pro');
      expect(ArchiveLoopEntitlementIds.revenueCatLegacyPro, 'pro');
      expect(RevenueCatService.proEntitlementId, 'pro');
    });

    test('dashboard module does not touch billing constants', () {
      final engineSource =
          File('lib/features/testflight_metrics/testflight_metrics_engine.dart')
              .readAsStringSync();
      final widgetSource =
          File('lib/widgets/beta/testflight_metrics_dashboard_card.dart')
              .readAsStringSync();
      expect(engineSource, isNot(contains('proEntitlementId')));
      expect(widgetSource, isNot(contains('RevenueCat')));
    });
  });
}
