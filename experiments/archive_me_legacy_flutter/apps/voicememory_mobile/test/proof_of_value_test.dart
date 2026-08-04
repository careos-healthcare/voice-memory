import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/config/developer_settings_gate.dart';
import 'package:voicememory_mobile/features/beta/core_value_feedback_copy.dart';
import 'package:voicememory_mobile/features/beta/proof_of_value_copy.dart';
import 'package:voicememory_mobile/features/beta/proof_of_value_engine.dart';
import 'package:voicememory_mobile/features/beta/proof_of_value_model.dart';
import 'package:voicememory_mobile/widgets/debug/proof_of_value_card.dart';

ProofOfValueInput _input({
  int totalTesters = 10,
  int appOpened = 10,
  int firstMomentSaved = 0,
  int secondMomentSaved = 0,
  int firstProofReached = 0,
  int returnCheckAnswered = 0,
  int proTapped = 0,
  int? coreValueYes,
  int? coreValueNotYet,
  int? coreValueGeneric,
  String? localCoreValueAnswerLabel,
  int? proofFeltSpecific,
  int? proofUsefulCount,
  int? wouldKeepUsing,
  int? wouldPay,
}) => ProofOfValueInput(
  totalTesters: totalTesters,
  appOpened: appOpened,
  firstMomentSaved: firstMomentSaved,
  secondMomentSaved: secondMomentSaved,
  firstProofReached: firstProofReached,
  returnCheckAnswered: returnCheckAnswered,
  proTapped: proTapped,
  coreValueYes: coreValueYes,
  coreValueNotYet: coreValueNotYet,
  coreValueGeneric: coreValueGeneric,
  localCoreValueAnswerLabel: localCoreValueAnswerLabel,
  proofFeltSpecific: proofFeltSpecific,
  proofUsefulCount: proofUsefulCount,
  wouldKeepUsing: wouldKeepUsing,
  wouldPay: wouldPay,
);

void main() {
  tearDown(DeveloperSettingsGate.resetForTest);

  group('ProofOfValueEngine', () {
    test('rows render in exact order', () {
      final report = ProofOfValueEngine.build(
        input: _input(
          firstMomentSaved: 8,
          secondMomentSaved: 6,
          firstProofReached: 4,
        ),
      );
      expect(report.rows, hasLength(8));
      expect(report.rows.map((row) => row.label).toList(), [
        ProofOfValueCopy.rowFirstSave,
        ProofOfValueCopy.rowSecondSave,
        ProofOfValueCopy.rowFirstProof,
        ProofOfValueCopy.rowCoreValueYes,
        ProofOfValueCopy.rowFeltGeneric,
        ProofOfValueCopy.rowWouldKeepUsing,
        ProofOfValueCopy.rowWouldPay,
        ProofOfValueCopy.rowReturnCheck,
      ]);
    });

    test('not enough testers recommends Run more testers', () {
      final report = ProofOfValueEngine.build(
        input: _input(totalTesters: 3, appOpened: 3),
      );
      expect(report.summary, ProofOfValueCopy.summaryNotEnoughEvidence);
      expect(
        report.recommendation,
        ProofOfValueCopy.recommendationRunMoreTesters,
      );
    });

    test('low first save recommends first-use clarity', () {
      final report = ProofOfValueEngine.build(
        input: _input(firstMomentSaved: 6),
      );
      expect(report.summary, ProofOfValueCopy.summaryActivationNotProven);
      expect(report.recommendation, ProofOfValueCopy.recommendationFixFirstUse);
    });

    test('low second save recommends return loop', () {
      final report = ProofOfValueEngine.build(
        input: _input(firstMomentSaved: 8, secondMomentSaved: 4),
      );
      expect(report.summary, ProofOfValueCopy.summaryActivationNotProven);
      expect(
        report.recommendation,
        ProofOfValueCopy.recommendationFixReturnLoop,
      );
    });

    test('low first proof recommends activation', () {
      final report = ProofOfValueEngine.build(
        input: _input(
          firstMomentSaved: 8,
          secondMomentSaved: 6,
          firstProofReached: 2,
        ),
      );
      expect(report.summary, ProofOfValueCopy.summaryFirstProofNotProven);
      expect(
        report.recommendation,
        ProofOfValueCopy.recommendationFixFirstProof,
      );
    });

    test('generic proof recommends evidence specificity', () {
      final report = ProofOfValueEngine.build(
        input: _input(
          firstMomentSaved: 8,
          secondMomentSaved: 6,
          firstProofReached: 4,
          coreValueYes: 1,
          coreValueGeneric: 2,
        ),
      );
      expect(report.summary, ProofOfValueCopy.summarySpecificityNotProven);
      expect(report.recommendation, ProofOfValueCopy.recommendationFixEvidence);
    });

    test('core value yes can satisfy specificity value signal', () {
      final report = ProofOfValueEngine.build(
        input: _input(
          firstMomentSaved: 8,
          secondMomentSaved: 6,
          firstProofReached: 4,
          coreValueYes: 2,
        ),
      );
      final row = report.rows.firstWhere(
        (item) => item.id == ProofOfValueRowId.coreValueYes,
      );
      expect(row.status, ProofOfValueRowStatus.proven);
      expect(
        report.recommendation,
        isNot(ProofOfValueCopy.recommendationFixEvidence),
      );
    });

    test('generic answer creates warning', () {
      final report = ProofOfValueEngine.build(
        input: _input(
          firstMomentSaved: 8,
          secondMomentSaved: 6,
          firstProofReached: 3,
          coreValueGeneric: 1,
          coreValueYes: 0,
        ),
      );
      final row = report.rows.firstWhere(
        (item) => item.id == ProofOfValueRowId.feltGeneric,
      );
      expect(row.status, ProofOfValueRowStatus.warning);
    });

    test('useful proof but no keep-using recommends retention value', () {
      final report = ProofOfValueEngine.build(
        input: _input(
          firstMomentSaved: 8,
          secondMomentSaved: 6,
          firstProofReached: 4,
          coreValueYes: 3,
          proofUsefulCount: 3,
          wouldKeepUsing: 0,
        ),
      );
      expect(report.summary, ProofOfValueCopy.summaryRetentionNotProven);
      expect(
        report.recommendation,
        ProofOfValueCopy.recommendationStrengthenRetention,
      );
    });

    test('useful proof but no pay or pro tap recommends Pro value', () {
      final report = ProofOfValueEngine.build(
        input: _input(
          firstMomentSaved: 8,
          secondMomentSaved: 6,
          firstProofReached: 4,
          coreValueYes: 3,
          wouldKeepUsing: 3,
          wouldPay: 0,
          proTapped: 0,
        ),
      );
      expect(report.summary, ProofOfValueCopy.summaryPaymentNotProven);
      expect(
        report.recommendation,
        ProofOfValueCopy.recommendationStrengthenPro,
      );
    });

    test('all thresholds pass recommends widen beta', () {
      final report = ProofOfValueEngine.build(
        input: _input(
          firstMomentSaved: 8,
          secondMomentSaved: 6,
          firstProofReached: 4,
          coreValueYes: 3,
          wouldKeepUsing: 3,
          wouldPay: 1,
          returnCheckAnswered: 3,
        ),
      );
      expect(report.summary, ProofOfValueCopy.summaryStrong);
      expect(report.recommendation, ProofOfValueCopy.recommendationWidenBeta);
    });

    test('pro tap satisfies payment signal', () {
      final report = ProofOfValueEngine.build(
        input: _input(
          firstMomentSaved: 8,
          secondMomentSaved: 6,
          firstProofReached: 4,
          coreValueYes: 3,
          wouldKeepUsing: 3,
          proTapped: 1,
        ),
      );
      expect(report.recommendation, ProofOfValueCopy.recommendationWidenBeta);
    });

    test('visible copy avoids transcript phrase and user content', () {
      final joined = ProofOfValueEngine.build(
        input: _input(
          firstMomentSaved: 8,
          coreValueYes: 2,
          localCoreValueAnswerLabel: CoreValueFeedbackCopy.answerYes,
        ),
      ).visibleCopyBlocks.join('\n').toLowerCase();
      expect(joined, isNot(contains('transcript')));
      expect(joined, isNot(contains('said yes again')));
      expect(joined, isNot(contains('journal entry')));
      expect(joined, isNot(contains('phrase text')));
    });

    test('no secrets displayed', () {
      final joined = ProofOfValueEngine.build(
        input: _input(firstMomentSaved: 8),
      ).visibleCopyBlocks.join('\n');
      expect(joined, isNot(contains('REVENUECAT_')));
      expect(joined, isNot(contains('http://')));
      expect(joined, isNot(contains('https://')));
      expect(joined, isNot(contains('sk_')));
    });
  });

  group('ProofOfValueCard', () {
    testWidgets('hidden when developer diagnostics locked', (tester) async {
      DeveloperSettingsGate.applyLoadedUnlock(false);
      DeveloperSettingsGate.suppressDebugBuildForTests = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProofOfValueCard(
              report: ProofOfValueEngine.build(input: _input()),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('proof_of_value_hidden')), findsOneWidget);
      expect(find.byKey(const Key('proof_of_value_card')), findsNothing);
    });

    testWidgets('visible when unlocked', (tester) async {
      DeveloperSettingsGate.applyLoadedUnlock(true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ProofOfValueCard(
                report: ProofOfValueEngine.build(
                  input: _input(firstMomentSaved: 8),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('proof_of_value_card')), findsOneWidget);
      expect(find.text(ProofOfValueCopy.cardTitle), findsOneWidget);
      expect(find.text(ProofOfValueCopy.primaryQuestion), findsOneWidget);
    });
  });
}
