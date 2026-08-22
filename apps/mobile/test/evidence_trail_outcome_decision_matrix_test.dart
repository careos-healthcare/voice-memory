import 'dart:io';

import 'package:archiveme_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:archiveme_mobile/features/evidence_trail_clarity/evidence_trail_outcome_decision_copy.dart';
import 'package:archiveme_mobile/features/evidence_trail_clarity/evidence_trail_outcome_decision_matrix.dart';
import 'package:flutter_test/flutter_test.dart';

EvidenceTrailOutcomeSummary _summary({
  int totalTesters = 30,
  int usefulProofCount = 10,
  int tooVagueOrNotRelevantCount = 2,
  int sawProCount = 6,
  int understandsProCount = 6,
  int paywallCtaTapCount = 2,
  int wouldPayYesMaybeCount = 4,
  int evidenceTrailClearCount = 5,
}) => EvidenceTrailOutcomeSummary(
  totalTesters: totalTesters,
  usefulProofCount: usefulProofCount,
  tooVagueOrNotRelevantCount: tooVagueOrNotRelevantCount,
  sawProCount: sawProCount,
  understandsProCount: understandsProCount,
  paywallCtaTapCount: paywallCtaTapCount,
  wouldPayYesMaybeCount: wouldPayYesMaybeCount,
  evidenceTrailClearCount: evidenceTrailClearCount,
);

EvidenceTrailOutcomeSummary _productionPassingSummary({
  int totalTesters = 30,
}) => _summary(
  totalTesters: totalTesters,
  usefulProofCount: totalTesters == 20 ? 5 : 7,
  tooVagueOrNotRelevantCount: totalTesters == 20 ? 4 : 6,
  sawProCount: totalTesters == 20 ? 3 : 4,
  understandsProCount: totalTesters == 20 ? 3 : 4,
  paywallCtaTapCount: 1,
  wouldPayYesMaybeCount: totalTesters == 20 ? 2 : 3,
  evidenceTrailClearCount: totalTesters == 20 ? 3 : 4,
);

void main() {
  group('EvidenceTrailOutcomeDecisionMatrix thresholds', () {
    test('30 tester exact targets', () {
      expect(EvidenceTrailOutcomeDecisionMatrix.usefulProofTargetFor(30), 7);
      expect(
        EvidenceTrailOutcomeDecisionMatrix.evidenceTrailClearTargetFor(30),
        4,
      );
      expect(EvidenceTrailOutcomeDecisionMatrix.sawProTargetFor(30), 4);
      expect(EvidenceTrailOutcomeDecisionMatrix.understandsProTargetFor(30), 4);
      expect(EvidenceTrailOutcomeDecisionMatrix.paywallCtaTapTargetFor(30), 1);
      expect(EvidenceTrailOutcomeDecisionMatrix.wouldPayTargetFor(30), 3);
    });

    test('20 tester scaled targets', () {
      expect(EvidenceTrailOutcomeDecisionMatrix.usefulProofTargetFor(20), 5);
      expect(
        EvidenceTrailOutcomeDecisionMatrix.evidenceTrailClearTargetFor(20),
        3,
      );
      expect(EvidenceTrailOutcomeDecisionMatrix.sawProTargetFor(20), 3);
      expect(EvidenceTrailOutcomeDecisionMatrix.understandsProTargetFor(20), 3);
      expect(EvidenceTrailOutcomeDecisionMatrix.paywallCtaTapTargetFor(20), 1);
      expect(EvidenceTrailOutcomeDecisionMatrix.wouldPayTargetFor(20), 2);
    });
  });

  group('EvidenceTrailOutcomeDecisionMatrix.resolve', () {
    test('under 20 testers returns insufficientData', () {
      expect(
        EvidenceTrailOutcomeDecisionMatrix.resolve(_summary(totalTesters: 19)),
        EvidenceTrailOutcomeDecision.insufficientData,
      );
    });

    test('useful proof below target returns protectProof', () {
      expect(
        EvidenceTrailOutcomeDecisionMatrix.resolve(
          _summary(usefulProofCount: 6),
        ),
        EvidenceTrailOutcomeDecision.protectProof,
      );
    });

    test('too vague or not relevant high returns protectProof', () {
      expect(
        EvidenceTrailOutcomeDecisionMatrix.resolve(
          _summary(tooVagueOrNotRelevantCount: 7),
        ),
        EvidenceTrailOutcomeDecision.protectProof,
      );
    });

    test(
      'evidence trail clear under target returns improveTimelineExplanation',
      () {
        expect(
          EvidenceTrailOutcomeDecisionMatrix.resolve(
            _summary(evidenceTrailClearCount: 3),
          ),
          EvidenceTrailOutcomeDecision.improveTimelineExplanation,
        );
      },
    );

    test('sawPro under target returns proTooHidden', () {
      expect(
        EvidenceTrailOutcomeDecisionMatrix.resolve(
          _summary(sawProCount: 3),
        ),
        EvidenceTrailOutcomeDecision.proTooHidden,
      );
    });

    test(
      'evidence trail clear passes but wouldPay weak returns pricingValidation',
      () {
        expect(
          EvidenceTrailOutcomeDecisionMatrix.resolve(
            _summary(
              sawProCount: 5,
              understandsProCount: 5,
              wouldPayYesMaybeCount: 2,
            ),
          ),
          EvidenceTrailOutcomeDecision.pricingValidation,
        );
      },
    );

    test('all targets pass returns productionCandidate', () {
      expect(
        EvidenceTrailOutcomeDecisionMatrix.resolve(_productionPassingSummary()),
        EvidenceTrailOutcomeDecision.productionCandidate,
      );
      expect(
        EvidenceTrailOutcomeDecisionMatrix.resolve(
          _productionPassingSummary(totalTesters: 20),
        ),
        EvidenceTrailOutcomeDecision.productionCandidate,
      );
    });

    test('proof problems beat Pro problems', () {
      expect(
        EvidenceTrailOutcomeDecisionMatrix.resolve(
          _summary(usefulProofCount: 6, sawProCount: 1),
        ),
        EvidenceTrailOutcomeDecision.protectProof,
      );
    });

    test('clarity problem beats pricing problem', () {
      expect(
        EvidenceTrailOutcomeDecisionMatrix.resolve(
          _summary(
            evidenceTrailClearCount: 3,
            wouldPayYesMaybeCount: 1,
            sawProCount: 5,
          ),
        ),
        EvidenceTrailOutcomeDecision.improveTimelineExplanation,
      );
    });

    test('Pro hidden beats pricing problem', () {
      expect(
        EvidenceTrailOutcomeDecisionMatrix.resolve(
          _summary(
            sawProCount: 3,
            wouldPayYesMaybeCount: 1,
          ),
        ),
        EvidenceTrailOutcomeDecision.proTooHidden,
      );
    });

    test('all marginal passing values still return productionCandidate', () {
      expect(
        EvidenceTrailOutcomeDecisionMatrix.resolve(
          _summary(
            sawProCount: 5,
            understandsProCount: 5,
          ),
        ),
        EvidenceTrailOutcomeDecision.productionCandidate,
      );
    });

    test('conservative fallback returns improveTimelineExplanation', () {
      expect(
        EvidenceTrailOutcomeDecisionMatrix.resolve(
          _summary(
            sawProCount: 5,
            understandsProCount: 2,
          ),
        ),
        EvidenceTrailOutcomeDecision.improveTimelineExplanation,
      );
    });
  });

  group('EvidenceTrailOutcomeDecisionCopy.report', () {
    test('returns correct title and nextAction', () {
      final summary = _summary(evidenceTrailClearCount: 3);
      final decision = EvidenceTrailOutcomeDecisionMatrix.resolve(summary);
      final report = EvidenceTrailOutcomeDecisionCopy.report(summary, decision);

      expect(decision, EvidenceTrailOutcomeDecision.improveTimelineExplanation);
      expect(report.title, 'Timeline is still unclear');
      expect(
        report.nextAction,
        'Improve the evidence trail wording and timeline explanation. Do not change price.',
      );
      expect(report.body, EvidenceTrailOutcomeDecisionCopy.bodyFor(decision));
      expect(report.guardrail, EvidenceTrailOutcomeDecisionCopy.guardrail);
    });

    test('passes metadata-safe guard', () {
      for (final text in EvidenceTrailOutcomeDecisionCopy.allVisibleStrings()) {
        expect(ProofSurfaceAdviceGuard.passes(text), isTrue, reason: text);
      }
    });
  });

  group('Protected areas', () {
    test('no protected pricing purchase or UI files touched', () {
      for (final path in [
        'lib/features/evidence_trail_clarity/evidence_trail_outcome_decision_matrix.dart',
        'lib/features/evidence_trail_clarity/evidence_trail_outcome_decision_copy.dart',
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