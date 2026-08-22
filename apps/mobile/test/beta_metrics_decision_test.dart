import 'package:archiveme_mobile/config/developer_settings_gate.dart';
import 'package:archiveme_mobile/features/beta/beta_metrics_decision_copy.dart';
import 'package:archiveme_mobile/features/beta/beta_metrics_decision_engine.dart';
import 'package:archiveme_mobile/features/beta/beta_metrics_decision_model.dart';
import 'package:archiveme_mobile/widgets/debug/beta_metrics_decision_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

BetaMetricsDecisionInput _input({
  int totalTesters = 10,
  int firstMomentSaved = 0,
  int secondMomentSaved = 0,
  int firstProofReached = 0,
  int? proofFeltSpecific,
  int? proofUsefulCount,
  int? wouldKeepUsing,
  int? wouldPay,
}) => BetaMetricsDecisionInput(
  totalTesters: totalTesters,
  firstMomentSaved: firstMomentSaved,
  secondMomentSaved: secondMomentSaved,
  firstProofReached: firstProofReached,
  proofFeltSpecific: proofFeltSpecific,
  proofUsefulCount: proofUsefulCount,
  wouldKeepUsing: wouldKeepUsing,
  wouldPay: wouldPay,
);

void main() {
  tearDown(DeveloperSettingsGate.resetForTest);

  group('BetaMetricsDecisionEngine', () {
    test('not enough tester data shows summary', () {
      final report = BetaMetricsDecisionEngine.build(
        input: _input(totalTesters: 0),
      );
      expect(report.summary, BetaMetricsDecisionCopy.summaryNotEnoughData);
      expect(
        report.primaryBottleneck,
        BetaMetricsDecisionBottleneck.notEnoughData,
      );
    });

    test('first save below 7/10 diagnoses first screen problem', () {
      final report = BetaMetricsDecisionEngine.build(
        input: _input(firstMomentSaved: 6),
      );
      expect(report.summary, BetaMetricsDecisionCopy.summaryFirstScreen);
      final row = report.rows.firstWhere(
        (item) => item.id == BetaMetricsDecisionRowId.firstSave,
      );
      expect(row.status, BetaMetricsDecisionRowStatus.belowTarget);
      expect(row.currentValue, '6 / 10');
      expect(row.targetValue, '7 / 10');
      expect(row.fixArea, BetaMetricsDecisionCopy.fixFirstUse);
      expect(row.problemLabel, BetaMetricsDecisionCopy.problemFirstScreen);
    });

    test('second save below 5/10 diagnoses return problem', () {
      final report = BetaMetricsDecisionEngine.build(
        input: _input(firstMomentSaved: 8, secondMomentSaved: 4),
      );
      expect(report.summary, BetaMetricsDecisionCopy.summaryReturnLoop);
      final row = report.rows.firstWhere(
        (item) => item.id == BetaMetricsDecisionRowId.secondSave,
      );
      expect(row.status, BetaMetricsDecisionRowStatus.belowTarget);
      expect(row.fixArea, BetaMetricsDecisionCopy.fixReturnHandoff);
    });

    test('first proof below 3/10 diagnoses activation problem', () {
      final report = BetaMetricsDecisionEngine.build(
        input: _input(
          firstMomentSaved: 8,
          secondMomentSaved: 6,
          firstProofReached: 2,
        ),
      );
      expect(report.summary, BetaMetricsDecisionCopy.summaryFirstProof);
      final row = report.rows.firstWhere(
        (item) => item.id == BetaMetricsDecisionRowId.firstProof,
      );
      expect(row.status, BetaMetricsDecisionRowStatus.belowTarget);
      expect(row.fixArea, BetaMetricsDecisionCopy.fixActivationJourney);
    });

    test('3+ first proof but low specificity diagnoses evidence problem', () {
      final report = BetaMetricsDecisionEngine.build(
        input: _input(
          firstMomentSaved: 8,
          secondMomentSaved: 6,
          firstProofReached: 4,
          proofFeltSpecific: 1,
        ),
      );
      expect(report.summary, BetaMetricsDecisionCopy.summaryEvidence);
      final row = report.rows.firstWhere(
        (item) => item.id == BetaMetricsDecisionRowId.specificProof,
      );
      expect(row.status, BetaMetricsDecisionRowStatus.belowTarget);
      expect(row.fixArea, BetaMetricsDecisionCopy.fixEvidence);
    });

    test(
      'useful proof but no keep-using signal diagnoses retention problem',
      () {
        final report = BetaMetricsDecisionEngine.build(
          input: _input(
            firstMomentSaved: 8,
            secondMomentSaved: 6,
            firstProofReached: 4,
            proofFeltSpecific: 3,
            proofUsefulCount: 3,
            wouldKeepUsing: 0,
          ),
        );
        expect(report.summary, BetaMetricsDecisionCopy.summaryRetention);
        final row = report.rows.firstWhere(
          (item) => item.id == BetaMetricsDecisionRowId.wouldContinue,
        );
        expect(row.status, BetaMetricsDecisionRowStatus.belowTarget);
        expect(row.fixArea, BetaMetricsDecisionCopy.fixRetention);
      },
    );

    test('useful proof but no pay signal diagnoses monetisation problem', () {
      final report = BetaMetricsDecisionEngine.build(
        input: _input(
          firstMomentSaved: 8,
          secondMomentSaved: 6,
          firstProofReached: 4,
          proofFeltSpecific: 3,
          proofUsefulCount: 3,
          wouldKeepUsing: 2,
          wouldPay: 0,
        ),
      );
      expect(report.summary, BetaMetricsDecisionCopy.summaryMonetisation);
      final row = report.rows.firstWhere(
        (item) => item.id == BetaMetricsDecisionRowId.wouldPay,
      );
      expect(row.status, BetaMetricsDecisionRowStatus.belowTarget);
      expect(row.fixArea, BetaMetricsDecisionCopy.fixMonetisation);
    });

    test('monetisation is not diagnosed before activation works', () {
      final report = BetaMetricsDecisionEngine.build(
        input: _input(
          firstMomentSaved: 6,
          secondMomentSaved: 6,
          firstProofReached: 4,
          proofFeltSpecific: 0,
          proofUsefulCount: 3,
          wouldKeepUsing: 0,
          wouldPay: 0,
        ),
      );
      expect(
        report.primaryBottleneck,
        isNot(BetaMetricsDecisionBottleneck.monetisation),
      );
      expect(
        report.summary,
        isNot(BetaMetricsDecisionCopy.summaryMonetisation),
      );
    });

    test('monetisation is not diagnosed before evidence works', () {
      final report = BetaMetricsDecisionEngine.build(
        input: _input(
          firstMomentSaved: 8,
          secondMomentSaved: 6,
          firstProofReached: 4,
          proofFeltSpecific: 1,
          proofUsefulCount: 3,
          wouldKeepUsing: 2,
          wouldPay: 0,
        ),
      );
      expect(
        report.primaryBottleneck,
        BetaMetricsDecisionBottleneck.evidenceSpecificity,
      );
      expect(
        report.summary,
        isNot(BetaMetricsDecisionCopy.summaryMonetisation),
      );
    });

    test('healthy signal when targets are met', () {
      final report = BetaMetricsDecisionEngine.build(
        input: _input(
          firstMomentSaved: 8,
          secondMomentSaved: 6,
          firstProofReached: 4,
          proofFeltSpecific: 3,
          proofUsefulCount: 3,
          wouldKeepUsing: 2,
          wouldPay: 2,
        ),
      );
      expect(report.summary, BetaMetricsDecisionCopy.summaryHealthy);
      expect(report.primaryBottleneck, BetaMetricsDecisionBottleneck.healthy);
    });

    test('qualitative fields without values show check manually', () {
      final report = BetaMetricsDecisionEngine.build(
        input: _input(
          firstMomentSaved: 8,
          secondMomentSaved: 6,
          firstProofReached: 4,
        ),
      );
      final specific = report.rows.firstWhere(
        (item) => item.id == BetaMetricsDecisionRowId.specificProof,
      );
      expect(specific.status, BetaMetricsDecisionRowStatus.checkManually);
      final keep = report.rows.firstWhere(
        (item) => item.id == BetaMetricsDecisionRowId.wouldContinue,
      );
      expect(keep.status, BetaMetricsDecisionRowStatus.checkManually);
    });

    test('rows show current value target status and fix area', () {
      final report = BetaMetricsDecisionEngine.build(
        input: _input(firstMomentSaved: 6),
      );
      for (final row in report.rows) {
        expect(row.metricName, isNotEmpty);
        expect(row.currentValue, isNotEmpty);
        expect(row.targetValue, isNotEmpty);
        expect(row.status.label, isNotEmpty);
        expect(row.fixArea, isNotEmpty);
      }
    });

    test('visible copy avoids transcript user entry and phrase text', () {
      final joined = BetaMetricsDecisionEngine.build(
        input: _input(
          firstMomentSaved: 8,
          secondMomentSaved: 6,
          firstProofReached: 4,
        ),
      ).visibleCopyBlocks.join('\n').toLowerCase();
      expect(joined, isNot(contains('transcript')));
      expect(joined, isNot(contains('said yes')));
      expect(joined, isNot(contains('journal entry')));
    });
  });

  group('BetaMetricsDecisionCard', () {
    testWidgets('hidden when developer diagnostics locked', (tester) async {
      DeveloperSettingsGate.applyLoadedUnlock(false);
      DeveloperSettingsGate.suppressDebugBuildForTests = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BetaMetricsDecisionCard(
              report: BetaMetricsDecisionEngine.build(
                input: _input(firstMomentSaved: 6),
              ),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('beta_metrics_decision_hidden')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('beta_metrics_decision_card')), findsNothing);
    });

    testWidgets('visible when developer diagnostics unlocked', (tester) async {
      DeveloperSettingsGate.applyLoadedUnlock(true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BetaMetricsDecisionCard(
                report: BetaMetricsDecisionEngine.build(
                  input: _input(firstMomentSaved: 6),
                ),
              ),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('beta_metrics_decision_card')),
        findsOneWidget,
      );
      expect(find.text(BetaMetricsDecisionCopy.cardTitle), findsOneWidget);
      expect(
        find.text(BetaMetricsDecisionCopy.summaryFirstScreen),
        findsOneWidget,
      );
    });
  });
}