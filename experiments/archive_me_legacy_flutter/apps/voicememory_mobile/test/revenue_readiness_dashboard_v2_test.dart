import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:voicememory_mobile/features/revenue_lift_experiment_v2/revenue_lift_experiment_v2_copy.dart';
import 'package:voicememory_mobile/features/revenue_lift_experiment_v2/revenue_lift_experiment_v2_engine.dart';
import 'package:voicememory_mobile/features/revenue_readiness/revenue_readiness_dashboard_v2_copy.dart';
import 'package:voicememory_mobile/features/revenue_readiness/revenue_readiness_dashboard_v2_engine.dart';
import 'package:voicememory_mobile/features/revenue_readiness/revenue_readiness_dashboard_v2_model.dart';
import 'package:voicememory_mobile/screens/testing_archiveme_screen.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/beta/revenue_readiness_dashboard_v2_card.dart';

const _privateTranscript =
    'I had no capacity but I said yes again to the extra meeting today.';

RevenueReadinessDashboardV2Dashboard _dashboardFrom(
  RevenueReadinessDashboardV2Input input,
) => RevenueReadinessDashboardV2Engine.buildFromInput(input);

RevenueReadinessDashboardV2Section _section(
  RevenueReadinessDashboardV2Dashboard dashboard,
  RevenueReadinessDashboardV2SectionId id,
) => dashboard.sections.firstWhere((section) => section.id == id);

RevenueReadinessDashboardV2MetricRow _metric(
  RevenueReadinessDashboardV2Dashboard dashboard,
  RevenueReadinessDashboardV2MetricId id,
) => dashboard.allRows.firstWhere((row) => row.id == id);

bool _hasDiagnosis(
  RevenueReadinessDashboardV2Dashboard dashboard,
  RevenueReadinessDashboardV2DiagnosisId id,
) => dashboard.diagnoses.any((diagnosis) => diagnosis.id == id);

Future<void> _pumpCard(
  WidgetTester tester, {
  required RevenueReadinessDashboardV2Dashboard dashboard,
}) async {
  ArchiveBetaMissionGate.enabledOverride = true;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: RevenueReadinessDashboardV2Card(dashboardOverride: dashboard),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(ArchiveBetaMissionGate.resetForTest);
  tearDown(ArchiveBetaMissionGate.resetForTest);

  group('RevenueReadinessDashboardV2Engine', () {
    test('hidden when beta/debug flag is false', () {
      expect(
        RevenueReadinessDashboardV2Engine.shouldShow(betaMissionEnabled: false),
        isFalse,
      );
    });

    test('renders all funnel sections', () {
      final dashboard = _dashboardFrom(
        const RevenueReadinessDashboardV2Input(),
      );
      expect(dashboard.sections.map((section) => section.title), [
        RevenueReadinessDashboardV2Copy.sectionCapture,
        RevenueReadinessDashboardV2Copy.sectionProof,
        RevenueReadinessDashboardV2Copy.sectionReturn,
        RevenueReadinessDashboardV2Copy.sectionRevenue,
      ]);
      expect(
        _section(
          dashboard,
          RevenueReadinessDashboardV2SectionId.capture,
        ).rows.length,
        3,
      );
      expect(
        _section(
          dashboard,
          RevenueReadinessDashboardV2SectionId.proof,
        ).rows.length,
        6,
      );
      expect(
        _section(
          dashboard,
          RevenueReadinessDashboardV2SectionId.returnFunnel,
        ).rows.length,
        3,
      );
      expect(
        _section(
          dashboard,
          RevenueReadinessDashboardV2SectionId.revenue,
        ).rows.length,
        8,
      );
    });

    test('handles no data', () {
      final dashboard = _dashboardFrom(
        const RevenueReadinessDashboardV2Input(),
      );
      expect(dashboard.hasDiagnoses, isFalse);
      expect(
        _metric(
          dashboard,
          RevenueReadinessDashboardV2MetricId.firstSave,
        ).valueLabel,
        RevenueReadinessDashboardV2Copy.notEnoughData,
      );
      expect(
        _metric(
          dashboard,
          RevenueReadinessDashboardV2MetricId.useful,
        ).valueLabel,
        RevenueReadinessDashboardV2Copy.notEnoughData,
      );
    });

    test('diagnoses low first save', () {
      final dashboard = _dashboardFrom(
        const RevenueReadinessDashboardV2Input(
          recordScreenSeen: 10,
          firstMomentSaved: 2,
        ),
      );
      expect(
        _hasDiagnosis(
          dashboard,
          RevenueReadinessDashboardV2DiagnosisId.lowFirstSave,
        ),
        isTrue,
      );
      expect(
        dashboard.diagnoses
            .singleWhere(
              (item) =>
                  item.id ==
                  RevenueReadinessDashboardV2DiagnosisId.lowFirstSave,
            )
            .nextActionLabel,
        RevenueReadinessDashboardV2Copy.actionFixFirstCapture,
      );
    });

    test('diagnoses low useful proof', () {
      final dashboard = _dashboardFrom(
        const RevenueReadinessDashboardV2Input(
          usefulCount: 1,
          tooVagueCount: 2,
          alreadyKnewCount: 1,
          notRelevantCount: 1,
        ),
      );
      expect(
        _hasDiagnosis(
          dashboard,
          RevenueReadinessDashboardV2DiagnosisId.lowUsefulProof,
        ),
        isTrue,
      );
      expect(
        dashboard.diagnoses
            .singleWhere(
              (item) =>
                  item.id ==
                  RevenueReadinessDashboardV2DiagnosisId.lowUsefulProof,
            )
            .nextActionLabel,
        RevenueReadinessDashboardV2Copy.actionFixProofWeak,
      );
    });

    test('diagnoses negative feedback above useful', () {
      final dashboard = _dashboardFrom(
        const RevenueReadinessDashboardV2Input(
          usefulCount: 1,
          tooVagueCount: 2,
          alreadyKnewCount: 1,
        ),
      );
      expect(
        _hasDiagnosis(
          dashboard,
          RevenueReadinessDashboardV2DiagnosisId.negativeAboveUseful,
        ),
        isTrue,
      );
      expect(
        dashboard.diagnoses
            .singleWhere(
              (item) =>
                  item.id ==
                  RevenueReadinessDashboardV2DiagnosisId.negativeAboveUseful,
            )
            .nextActionLabel,
        RevenueReadinessDashboardV2Copy.actionFixAnchorCalibration,
      );
    });

    test('diagnoses low return after proof', () {
      final dashboard = _dashboardFrom(
        const RevenueReadinessDashboardV2Input(
          confirmedRepeatSeen: 10,
          returnedAfterFirstProof: 1,
        ),
      );
      expect(
        _hasDiagnosis(
          dashboard,
          RevenueReadinessDashboardV2DiagnosisId.lowReturnAfterProof,
        ),
        isTrue,
      );
      expect(
        dashboard.diagnoses
            .singleWhere(
              (item) =>
                  item.id ==
                  RevenueReadinessDashboardV2DiagnosisId.lowReturnAfterProof,
            )
            .nextActionLabel,
        RevenueReadinessDashboardV2Copy.actionFixReturnLoop,
      );
    });

    test('diagnoses low paywall seen', () {
      final dashboard = _dashboardFrom(
        const RevenueReadinessDashboardV2Input(
          confirmedRepeatSeen: 10,
          paywallSeen: 2,
        ),
      );
      expect(
        _hasDiagnosis(
          dashboard,
          RevenueReadinessDashboardV2DiagnosisId.lowPaywallSeen,
        ),
        isTrue,
      );
      expect(
        dashboard.diagnoses
            .singleWhere(
              (item) =>
                  item.id ==
                  RevenueReadinessDashboardV2DiagnosisId.lowPaywallSeen,
            )
            .nextActionLabel,
        RevenueReadinessDashboardV2Copy.actionFixProBridgeHidden,
      );
    });

    test('diagnoses weak CTA tap', () {
      final dashboard = _dashboardFrom(
        const RevenueReadinessDashboardV2Input(
          paywallSeen: 20,
          paywallCtaTapped: 0,
        ),
      );
      expect(
        _hasDiagnosis(
          dashboard,
          RevenueReadinessDashboardV2DiagnosisId.weakCtaTap,
        ),
        isTrue,
      );
      expect(
        dashboard.diagnoses
            .singleWhere(
              (item) =>
                  item.id == RevenueReadinessDashboardV2DiagnosisId.weakCtaTap,
            )
            .nextActionLabel,
        RevenueReadinessDashboardV2Copy.actionFixPaywallValue,
      );
    });

    test('diagnoses purchase completion issue', () {
      final dashboard = _dashboardFrom(
        const RevenueReadinessDashboardV2Input(
          purchaseStarted: 2,
          purchaseCompleted: 0,
        ),
      );
      expect(
        _hasDiagnosis(
          dashboard,
          RevenueReadinessDashboardV2DiagnosisId.purchaseCompletionIssue,
        ),
        isTrue,
      );
      expect(
        dashboard.diagnoses
            .singleWhere(
              (item) =>
                  item.id ==
                  RevenueReadinessDashboardV2DiagnosisId
                      .purchaseCompletionIssue,
            )
            .nextActionLabel,
        RevenueReadinessDashboardV2Copy.actionFixBillingConfidence,
      );
    });

    test('diagnoses restore failures', () {
      final dashboard = _dashboardFrom(
        const RevenueReadinessDashboardV2Input(
          restoreAttempted: 2,
          restoreCompleted: 0,
        ),
      );
      expect(
        _hasDiagnosis(
          dashboard,
          RevenueReadinessDashboardV2DiagnosisId.restoreFailure,
        ),
        isTrue,
      );
      expect(
        dashboard.diagnoses
            .singleWhere(
              (item) =>
                  item.id ==
                  RevenueReadinessDashboardV2DiagnosisId.restoreFailure,
            )
            .nextActionLabel,
        RevenueReadinessDashboardV2Copy.actionFixRestoreFlow,
      );
    });

    test('does not expose private text or entry IDs', () {
      final dashboard = _dashboardFrom(
        const RevenueReadinessDashboardV2Input(
          recordScreenSeen: 1,
          firstMomentSaved: 1,
        ),
      );
      final blob = dashboard.allDisplayedText
          .where(
            (line) => line != RevenueReadinessDashboardV2Copy.localCountsNote,
          )
          .join(' ')
          .toLowerCase();
      expect(
        blob.split('\n').where((line) => line.contains(' said ')),
        isEmpty,
      );
      expect(blob, isNot(contains(_privateTranscript)));
      expect(blob, isNot(contains('entry_id')));
      expect(blob, isNot(contains('entry id')));
    });

    test('metadata only copy passes medical guard', () {
      for (final line in RevenueReadinessDashboardV2Copy.allVisibleStrings()) {
        expect(ProofSurfaceAdviceGuard.passes(line), isTrue, reason: line);
      }
    });

    test('chooses paywall_cta lift focus when CTA tap is 4%', () {
      final dashboard = _dashboardFrom(
        const RevenueReadinessDashboardV2Input(
          paywallSeen: 25,
          paywallCtaTapped: 1,
        ),
      );
      expect(
        dashboard.liftFocus.focus,
        RevenueLiftExperimentV2Focus.paywallCta,
      );
      expect(
        dashboard.liftFocus.label,
        RevenueLiftExperimentV2Copy.liftFocusPaywallCta,
      );
    });

    test('resolveLiftFocus matches dashboard lift focus', () {
      final input = const RevenueReadinessDashboardV2Input(
        recordScreenSeen: 10,
        firstMomentSaved: 5,
      );
      expect(
        RevenueLiftExperimentV2Engine.resolveLiftFocus(input).focus,
        RevenueLiftExperimentV2Focus.firstSave,
      );
    });
  });

  group('RevenueReadinessDashboardV2Card', () {
    testWidgets('renders all funnel sections', (tester) async {
      await _pumpCard(
        tester,
        dashboard: _dashboardFrom(
          const RevenueReadinessDashboardV2Input(
            firstMomentSaved: 1,
            usefulCount: 1,
            returnedAfterFirstProof: 1,
            paywallSeen: 1,
          ),
        ),
      );

      expect(
        find.byKey(const Key('revenue_readiness_dashboard_v2_card')),
        findsOneWidget,
      );
      expect(
        find.text(RevenueReadinessDashboardV2Copy.sectionCapture),
        findsOneWidget,
      );
      expect(
        find.text(RevenueReadinessDashboardV2Copy.sectionProof),
        findsOneWidget,
      );
      expect(
        find.text(RevenueReadinessDashboardV2Copy.sectionReturn),
        findsOneWidget,
      );
      expect(
        find.text(RevenueReadinessDashboardV2Copy.sectionRevenue),
        findsOneWidget,
      );
      expect(
        find.text(RevenueReadinessDashboardV2Copy.sectionDiagnosis),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('revenue_readiness_dashboard_v2_lift_focus')),
        findsOneWidget,
      );
      expect(
        find.text(RevenueLiftExperimentV2Copy.liftFocusSectionTitle),
        findsOneWidget,
      );
    });

    testWidgets('hidden when beta/debug flag is false', (tester) async {
      ArchiveBetaMissionGate.enabledOverride = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RevenueReadinessDashboardV2Card(
              dashboardOverride: _dashboardFrom(
                const RevenueReadinessDashboardV2Input(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('revenue_readiness_dashboard_v2_hidden')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('revenue_readiness_dashboard_v2_card')),
        findsNothing,
      );
    });
  });

  group('TestingArchiveMeScreen', () {
    setUp(() async {
      await AppServices.resetForTest(
        journalPath:
            'test/tmp/revenue_readiness_v2/${DateTime.now().microsecondsSinceEpoch}_journal.json',
        prefsPath:
            'test/tmp/revenue_readiness_v2/${DateTime.now().microsecondsSinceEpoch}_prefs.json',
        skipRevenueCat: true,
      );
    });

    testWidgets('testing screen includes the card', (tester) async {
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

      expect(find.byType(RevenueReadinessDashboardV2Card), findsOneWidget);
    });
  });
}
