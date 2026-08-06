import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/proof_protection/anchor_outcome_copy.dart';
import 'package:voicememory_mobile/features/proof_protection/anchor_outcome_matrix.dart';

AnchorOutcomeSummary _summary({
  int totalTesters = 30,
  int firstSessionSaveCount = 20,
  int usefulProofCount = 10,
  int tooVagueOrNotRelevantCount = 2,
  int specificProofExampleRememberedCount = 5,
  int sawProCount = 6,
  int understandsProCount = 6,
  int paywallCtaTapCount = 2,
  int wouldPayYesMaybeCount = 4,
}) => AnchorOutcomeSummary(
  totalTesters: totalTesters,
  firstSessionSaveCount: firstSessionSaveCount,
  usefulProofCount: usefulProofCount,
  tooVagueOrNotRelevantCount: tooVagueOrNotRelevantCount,
  specificProofExampleRememberedCount: specificProofExampleRememberedCount,
  sawProCount: sawProCount,
  understandsProCount: understandsProCount,
  paywallCtaTapCount: paywallCtaTapCount,
  wouldPayYesMaybeCount: wouldPayYesMaybeCount,
);

AnchorOutcomeSummary _productionPassingSummary({int totalTesters = 30}) =>
    _summary(
      totalTesters: totalTesters,
      usefulProofCount: totalTesters == 20 ? 5 : 7,
      tooVagueOrNotRelevantCount: totalTesters == 20 ? 3 : 5,
      specificProofExampleRememberedCount: totalTesters == 20 ? 4 : 5,
      understandsProCount: totalTesters == 20 ? 3 : 4,
      paywallCtaTapCount: 1,
      wouldPayYesMaybeCount: totalTesters == 20 ? 2 : 3,
    );

void main() {
  group('AnchorOutcomeMatrix thresholds', () {
    test('30 tester exact targets', () {
      expect(AnchorOutcomeMatrix.usefulProofTargetFor(30), 7);
      expect(AnchorOutcomeMatrix.tooVagueHighTargetFor(30), 6);
      expect(
        AnchorOutcomeMatrix.specificProofExampleRememberedTargetFor(30),
        5,
      );
      expect(AnchorOutcomeMatrix.understandsProTargetFor(30), 4);
      expect(AnchorOutcomeMatrix.paywallCtaTapTargetFor(30), 1);
      expect(AnchorOutcomeMatrix.wouldPayTargetFor(30), 3);
    });

    test('20 tester scaled targets', () {
      expect(AnchorOutcomeMatrix.usefulProofTargetFor(20), 5);
      expect(AnchorOutcomeMatrix.tooVagueHighTargetFor(20), 4);
      expect(
        AnchorOutcomeMatrix.specificProofExampleRememberedTargetFor(20),
        4,
      );
      expect(AnchorOutcomeMatrix.understandsProTargetFor(20), 3);
      expect(AnchorOutcomeMatrix.paywallCtaTapTargetFor(20), 1);
      expect(AnchorOutcomeMatrix.wouldPayTargetFor(20), 2);
    });
  });

  group('AnchorOutcomeMatrix.resolve', () {
    test('under 20 testers returns insufficientData', () {
      expect(
        AnchorOutcomeMatrix.resolve(_summary(totalTesters: 19)),
        AnchorOutcomeDecision.insufficientData,
      );
    });

    test('too vague or not relevant 6+/30 returns anchorsStillTooLoose', () {
      expect(
        AnchorOutcomeMatrix.resolve(
          _summary(totalTesters: 30, tooVagueOrNotRelevantCount: 6),
        ),
        AnchorOutcomeDecision.anchorsStillTooLoose,
      );
    });

    test('useful proof below 7/30 returns anchorsTooStrict', () {
      expect(
        AnchorOutcomeMatrix.resolve(
          _summary(totalTesters: 30, usefulProofCount: 6),
        ),
        AnchorOutcomeDecision.anchorsTooStrict,
      );
    });

    test(
      'useful proof passes and vague low returns proofStableReturnToEvidenceTrail',
      () {
        expect(
          AnchorOutcomeMatrix.resolve(
            _summary(
              usefulProofCount: 8,
              tooVagueOrNotRelevantCount: 5,
              specificProofExampleRememberedCount: 3,
            ),
          ),
          AnchorOutcomeDecision.proofStableReturnToEvidenceTrail,
        );
      },
    );

    test('all proof and value targets pass returns productionCandidate', () {
      expect(
        AnchorOutcomeMatrix.resolve(_productionPassingSummary()),
        AnchorOutcomeDecision.productionCandidate,
      );
      expect(
        AnchorOutcomeMatrix.resolve(
          _productionPassingSummary(totalTesters: 20),
        ),
        AnchorOutcomeDecision.productionCandidate,
      );
    });

    test('vague high beats useful proof pro and value signals', () {
      expect(
        AnchorOutcomeMatrix.resolve(
          _summary(
            usefulProofCount: 10,
            tooVagueOrNotRelevantCount: 7,
            specificProofExampleRememberedCount: 5,
            understandsProCount: 6,
            wouldPayYesMaybeCount: 4,
          ),
        ),
        AnchorOutcomeDecision.anchorsStillTooLoose,
      );
    });

    test('useful proof low beats pro and value signals', () {
      expect(
        AnchorOutcomeMatrix.resolve(
          _summary(
            usefulProofCount: 6,
            tooVagueOrNotRelevantCount: 2,
            specificProofExampleRememberedCount: 5,
            understandsProCount: 6,
            wouldPayYesMaybeCount: 4,
          ),
        ),
        AnchorOutcomeDecision.anchorsTooStrict,
      );
    });

    test('proof stable beats pricing work when production targets fail', () {
      expect(
        AnchorOutcomeMatrix.resolve(
          _summary(
            usefulProofCount: 8,
            tooVagueOrNotRelevantCount: 2,
            specificProofExampleRememberedCount: 5,
            understandsProCount: 5,
            paywallCtaTapCount: 2,
            wouldPayYesMaybeCount: 1,
          ),
        ),
        AnchorOutcomeDecision.proofStableReturnToEvidenceTrail,
      );
    });

    test('conservative fallback returns anchorsTooStrict', () {
      expect(
        AnchorOutcomeMatrix.resolve(
          _summary(
            totalTesters: 20,
            usefulProofCount: 4,
            tooVagueOrNotRelevantCount: 2,
          ),
        ),
        AnchorOutcomeDecision.anchorsTooStrict,
      );
    });
  });

  group('AnchorOutcomeCopy.report', () {
    test('returns correct nextAction and guardrail for each decision', () {
      final cases = <(AnchorOutcomeSummary, String)>[
        (
          _summary(totalTesters: 19),
          'Keep testing Build 64 until at least 20 testers complete the flow.',
        ),
        (
          _summary(totalTesters: 30, tooVagueOrNotRelevantCount: 6),
          'Tighten anchors again. Reduce vague or unsupported proof.',
        ),
        (
          _summary(totalTesters: 30, usefulProofCount: 6),
          'Repair proof usefulness without loosening vague anchors.',
        ),
        (
          _summary(
            usefulProofCount: 8,
            tooVagueOrNotRelevantCount: 5,
            specificProofExampleRememberedCount: 3,
          ),
          'Return to evidence-trail clarity and Pro understanding test.',
        ),
        (
          _productionPassingSummary(),
          'Stop product development and finish App Store readiness.',
        ),
      ];

      for (final (summary, expectedNextAction) in cases) {
        final decision = AnchorOutcomeMatrix.resolve(summary);
        final report = AnchorOutcomeCopy.report(summary, decision);
        expect(report.nextAction, expectedNextAction);
        expect(report.guardrail, AnchorOutcomeCopy.guardrail);
        expect(report.title, AnchorOutcomeCopy.titleFor(decision));
        expect(report.body, AnchorOutcomeCopy.bodyFor(decision));
      }
    });

    test('passes metadata-safe guard', () {
      for (final text in AnchorOutcomeCopy.allVisibleStrings()) {
        expect(ProofSurfaceAdviceGuard.passes(text), isTrue, reason: text);
      }
    });
  });

  group('Protected areas', () {
    test('no protected pricing purchase or UI files touched', () {
      for (final path in [
        'lib/features/proof_protection/anchor_outcome_matrix.dart',
        'lib/features/proof_protection/anchor_outcome_copy.dart',
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
