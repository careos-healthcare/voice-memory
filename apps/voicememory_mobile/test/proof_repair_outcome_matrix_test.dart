import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/proof_protection/proof_repair_outcome_copy.dart';
import 'package:voicememory_mobile/features/proof_protection/proof_repair_outcome_matrix.dart';

ProofRepairOutcomeSummary _summary({
  int totalTesters = 30,
  int firstSessionSaveCount = 20,
  int usefulProofCount = 10,
  int tooVagueOrNotRelevantCount = 2,
  int sawProCount = 6,
  int understandsProCount = 6,
  int evidenceTrailClearCount = 5,
  int paywallCtaTapCount = 2,
  int wouldPayYesMaybeCount = 4,
}) =>
    ProofRepairOutcomeSummary(
      totalTesters: totalTesters,
      firstSessionSaveCount: firstSessionSaveCount,
      usefulProofCount: usefulProofCount,
      tooVagueOrNotRelevantCount: tooVagueOrNotRelevantCount,
      sawProCount: sawProCount,
      understandsProCount: understandsProCount,
      evidenceTrailClearCount: evidenceTrailClearCount,
      paywallCtaTapCount: paywallCtaTapCount,
      wouldPayYesMaybeCount: wouldPayYesMaybeCount,
    );

ProofRepairOutcomeSummary _productionPassingSummary({
  int totalTesters = 30,
}) =>
    _summary(
      totalTesters: totalTesters,
      usefulProofCount: totalTesters == 20 ? 5 : 7,
      tooVagueOrNotRelevantCount: totalTesters == 20 ? 3 : 5,
      understandsProCount: totalTesters == 20 ? 3 : 4,
      evidenceTrailClearCount: totalTesters == 20 ? 3 : 4,
      paywallCtaTapCount: 1,
      wouldPayYesMaybeCount: totalTesters == 20 ? 2 : 3,
    );

void main() {
  group('ProofRepairOutcomeMatrix thresholds', () {
    test('30 tester exact targets', () {
      expect(ProofRepairOutcomeMatrix.usefulProofTargetFor(30), 7);
      expect(ProofRepairOutcomeMatrix.tooVagueHighTargetFor(30), 6);
      expect(ProofRepairOutcomeMatrix.evidenceTrailClearTargetFor(30), 4);
      expect(ProofRepairOutcomeMatrix.understandsProTargetFor(30), 4);
      expect(ProofRepairOutcomeMatrix.paywallCtaTapTargetFor(30), 1);
      expect(ProofRepairOutcomeMatrix.wouldPayTargetFor(30), 3);
    });

    test('20 tester scaled targets', () {
      expect(ProofRepairOutcomeMatrix.usefulProofTargetFor(20), 5);
      expect(ProofRepairOutcomeMatrix.tooVagueHighTargetFor(20), 4);
      expect(ProofRepairOutcomeMatrix.evidenceTrailClearTargetFor(20), 3);
      expect(ProofRepairOutcomeMatrix.understandsProTargetFor(20), 3);
      expect(ProofRepairOutcomeMatrix.paywallCtaTapTargetFor(20), 1);
      expect(ProofRepairOutcomeMatrix.wouldPayTargetFor(20), 2);
    });
  });

  group('ProofRepairOutcomeMatrix.resolve', () {
    test('under 20 testers returns insufficientData', () {
      expect(
        ProofRepairOutcomeMatrix.resolve(_summary(totalTesters: 19)),
        ProofRepairOutcomeDecision.insufficientData,
      );
    });

    test('useful proof below 7/30 returns repairProofAgain', () {
      expect(
        ProofRepairOutcomeMatrix.resolve(
          _summary(totalTesters: 30, usefulProofCount: 6),
        ),
        ProofRepairOutcomeDecision.repairProofAgain,
      );
    });

    test('too vague or not relevant 6+/30 returns tightenAnchorsAgain', () {
      expect(
        ProofRepairOutcomeMatrix.resolve(
          _summary(totalTesters: 30, tooVagueOrNotRelevantCount: 6),
        ),
        ProofRepairOutcomeDecision.tightenAnchorsAgain,
      );
    });

    test('useful proof passes and vague low returns proofStableReturnToEvidenceTrail',
        () {
      expect(
        ProofRepairOutcomeMatrix.resolve(
          _summary(
            usefulProofCount: 8,
            tooVagueOrNotRelevantCount: 5,
            evidenceTrailClearCount: 3,
          ),
        ),
        ProofRepairOutcomeDecision.proofStableReturnToEvidenceTrail,
      );
    });

    test('all proof evidence pro value targets pass returns productionCandidate',
        () {
      expect(
        ProofRepairOutcomeMatrix.resolve(_productionPassingSummary()),
        ProofRepairOutcomeDecision.productionCandidate,
      );
      expect(
        ProofRepairOutcomeMatrix.resolve(
          _productionPassingSummary(totalTesters: 20),
        ),
        ProofRepairOutcomeDecision.productionCandidate,
      );
    });

    test('useful proof failure beats vague pro and evidence signals', () {
      expect(
        ProofRepairOutcomeMatrix.resolve(
          _summary(
            usefulProofCount: 6,
            tooVagueOrNotRelevantCount: 10,
            evidenceTrailClearCount: 5,
            understandsProCount: 6,
            wouldPayYesMaybeCount: 4,
          ),
        ),
        ProofRepairOutcomeDecision.repairProofAgain,
      );
    });

    test('vague high beats evidence pro and value signals', () {
      expect(
        ProofRepairOutcomeMatrix.resolve(
          _summary(
            usefulProofCount: 10,
            tooVagueOrNotRelevantCount: 7,
            evidenceTrailClearCount: 1,
            understandsProCount: 1,
            wouldPayYesMaybeCount: 1,
          ),
        ),
        ProofRepairOutcomeDecision.tightenAnchorsAgain,
      );
    });

    test('proof stable beats pricing work when production targets fail', () {
      expect(
        ProofRepairOutcomeMatrix.resolve(
          _summary(
            usefulProofCount: 8,
            tooVagueOrNotRelevantCount: 2,
            evidenceTrailClearCount: 5,
            understandsProCount: 5,
            paywallCtaTapCount: 2,
            wouldPayYesMaybeCount: 1,
          ),
        ),
        ProofRepairOutcomeDecision.proofStableReturnToEvidenceTrail,
      );
    });

    test('conservative fallback returns repairProofAgain', () {
      expect(
        ProofRepairOutcomeMatrix.resolve(
          _summary(
            totalTesters: 20,
            usefulProofCount: 4,
            tooVagueOrNotRelevantCount: 2,
          ),
        ),
        ProofRepairOutcomeDecision.repairProofAgain,
      );
    });
  });

  group('ProofRepairOutcomeCopy.report', () {
    test('returns correct nextAction and guardrail for each decision', () {
      final cases = <(ProofRepairOutcomeSummary, String)>[
        (
          _summary(totalTesters: 19),
          'Keep testing Build 63 until at least 20 testers complete the flow.',
        ),
        (
          _summary(totalTesters: 30, usefulProofCount: 6),
          'Repair proof again. Do not work on Pro, pricing, or timeline.',
        ),
        (
          _summary(totalTesters: 30, tooVagueOrNotRelevantCount: 6),
          'Tighten anchors again. Reduce vague or unsupported proof.',
        ),
        (
          _summary(
            usefulProofCount: 8,
            tooVagueOrNotRelevantCount: 5,
            evidenceTrailClearCount: 3,
          ),
          'Return to evidence-trail clarity and Pro understanding test.',
        ),
        (
          _productionPassingSummary(),
          'Stop product development and finish App Store readiness.',
        ),
      ];

      for (final (summary, expectedNextAction) in cases) {
        final decision = ProofRepairOutcomeMatrix.resolve(summary);
        final report = ProofRepairOutcomeCopy.report(summary, decision);
        expect(report.nextAction, expectedNextAction);
        expect(report.guardrail, ProofRepairOutcomeCopy.guardrail);
        expect(report.title, ProofRepairOutcomeCopy.titleFor(decision));
        expect(report.body, ProofRepairOutcomeCopy.bodyFor(decision));
      }
    });

    test('passes metadata-safe guard', () {
      for (final text in ProofRepairOutcomeCopy.allVisibleStrings()) {
        expect(ProofSurfaceAdviceGuard.passes(text), isTrue, reason: text);
      }
    });
  });

  group('Protected areas', () {
    test('no protected pricing purchase or UI files touched', () {
      for (final path in [
        'lib/features/proof_protection/proof_repair_outcome_matrix.dart',
        'lib/features/proof_protection/proof_repair_outcome_copy.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source.contains('PaywallSource'), isFalse);
        expect(source.contains('RevenueCat'), isFalse);
        expect(source.contains('restorePurchases'), isFalse);
        expect(source.contains('billing/'), isFalse);
        expect(source.contains('record_screen'), isFalse);
      }
    });
  });
}
