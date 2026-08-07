import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/proof_relevance_repair/proof_relevance_outcome_copy.dart';
import 'package:voicememory_mobile/features/proof_relevance_repair/proof_relevance_outcome_matrix.dart';

ProofRelevanceOutcomeSummary _summary({
  int totalTesters = 30,
  int usefulProofCount = 10,
  int tooVagueOrNotRelevantCount = 2,
  int understoodWhatItNoticedCount = 8,
  int couldTellIfRightCount = 8,
  int didNotFeelLikeVagueAiCount = 8,
  int specificProofExampleRememberedCount = 5,
  int wouldPayYesMaybeCount = 4,
}) => ProofRelevanceOutcomeSummary(
  totalTesters: totalTesters,
  usefulProofCount: usefulProofCount,
  tooVagueOrNotRelevantCount: tooVagueOrNotRelevantCount,
  understoodWhatItNoticedCount: understoodWhatItNoticedCount,
  couldTellIfRightCount: couldTellIfRightCount,
  didNotFeelLikeVagueAiCount: didNotFeelLikeVagueAiCount,
  specificProofExampleRememberedCount: specificProofExampleRememberedCount,
  wouldPayYesMaybeCount: wouldPayYesMaybeCount,
);

ProofRelevanceOutcomeSummary _stableSummary({int totalTesters = 30}) =>
    _summary(
      totalTesters: totalTesters,
      usefulProofCount: totalTesters == 20 ? 5 : 7,
      tooVagueOrNotRelevantCount: totalTesters == 20 ? 3 : 5,
      understoodWhatItNoticedCount: totalTesters == 20 ? 4 : 6,
      couldTellIfRightCount: totalTesters == 20 ? 4 : 6,
      didNotFeelLikeVagueAiCount: totalTesters == 20 ? 4 : 6,
    );

ProofRelevanceOutcomeSummary _productionPassingSummary({
  int totalTesters = 30,
}) => _stableSummary(totalTesters: totalTesters).copyWith(
  specificProofExampleRememberedCount: totalTesters == 20 ? 4 : 5,
  wouldPayYesMaybeCount: totalTesters == 20 ? 2 : 3,
);

extension on ProofRelevanceOutcomeSummary {
  ProofRelevanceOutcomeSummary copyWith({
    int? usefulProofCount,
    int? tooVagueOrNotRelevantCount,
    int? understoodWhatItNoticedCount,
    int? couldTellIfRightCount,
    int? didNotFeelLikeVagueAiCount,
    int? specificProofExampleRememberedCount,
    int? wouldPayYesMaybeCount,
  }) => ProofRelevanceOutcomeSummary(
    totalTesters: totalTesters,
    usefulProofCount: usefulProofCount ?? this.usefulProofCount,
    tooVagueOrNotRelevantCount:
        tooVagueOrNotRelevantCount ?? this.tooVagueOrNotRelevantCount,
    understoodWhatItNoticedCount:
        understoodWhatItNoticedCount ?? this.understoodWhatItNoticedCount,
    couldTellIfRightCount: couldTellIfRightCount ?? this.couldTellIfRightCount,
    didNotFeelLikeVagueAiCount:
        didNotFeelLikeVagueAiCount ?? this.didNotFeelLikeVagueAiCount,
    specificProofExampleRememberedCount:
        specificProofExampleRememberedCount ??
        this.specificProofExampleRememberedCount,
    wouldPayYesMaybeCount: wouldPayYesMaybeCount ?? this.wouldPayYesMaybeCount,
  );
}

void main() {
  group('ProofRelevanceOutcomeMatrix thresholds', () {
    test('30 tester exact targets', () {
      expect(ProofRelevanceOutcomeMatrix.usefulProofTargetFor(30), 7);
      expect(ProofRelevanceOutcomeMatrix.tooVagueHighTargetFor(30), 6);
      expect(
        ProofRelevanceOutcomeMatrix.understoodWhatItNoticedTargetFor(30),
        6,
      );
      expect(ProofRelevanceOutcomeMatrix.couldTellIfRightTargetFor(30), 6);
      expect(ProofRelevanceOutcomeMatrix.didNotFeelLikeVagueAiTargetFor(30), 6);
      expect(
        ProofRelevanceOutcomeMatrix.specificProofExampleRememberedTargetFor(30),
        5,
      );
      expect(ProofRelevanceOutcomeMatrix.wouldPayTargetFor(30), 3);
    });

    test('20 tester scaled targets', () {
      expect(ProofRelevanceOutcomeMatrix.usefulProofTargetFor(20), 5);
      expect(ProofRelevanceOutcomeMatrix.tooVagueHighTargetFor(20), 4);
      expect(
        ProofRelevanceOutcomeMatrix.understoodWhatItNoticedTargetFor(20),
        4,
      );
      expect(ProofRelevanceOutcomeMatrix.couldTellIfRightTargetFor(20), 4);
      expect(ProofRelevanceOutcomeMatrix.didNotFeelLikeVagueAiTargetFor(20), 4);
      expect(
        ProofRelevanceOutcomeMatrix.specificProofExampleRememberedTargetFor(20),
        4,
      );
      expect(ProofRelevanceOutcomeMatrix.wouldPayTargetFor(20), 2);
    });
  });

  group('ProofRelevanceOutcomeMatrix.resolve', () {
    test('under 20 testers returns insufficientData', () {
      expect(
        ProofRelevanceOutcomeMatrix.resolve(_summary(totalTesters: 19)),
        ProofRelevanceOutcomeDecision.insufficientData,
      );
    });

    test('high vague or not relevant returns proofStillTooVague', () {
      expect(
        ProofRelevanceOutcomeMatrix.resolve(
          _summary(totalTesters: 30, tooVagueOrNotRelevantCount: 6),
        ),
        ProofRelevanceOutcomeDecision.proofStillTooVague,
      );
    });

    test('low understoodWhatItNoticed returns proofNotUnderstood', () {
      expect(
        ProofRelevanceOutcomeMatrix.resolve(
          _summary(totalTesters: 30, understoodWhatItNoticedCount: 5),
        ),
        ProofRelevanceOutcomeDecision.proofNotUnderstood,
      );
    });

    test('low couldTellIfRight returns proofNotUnderstood', () {
      expect(
        ProofRelevanceOutcomeMatrix.resolve(
          _summary(totalTesters: 30, couldTellIfRightCount: 5),
        ),
        ProofRelevanceOutcomeDecision.proofNotUnderstood,
      );
    });

    test('proof stable returns proofStableReturnToEvidenceTrail', () {
      expect(
        ProofRelevanceOutcomeMatrix.resolve(
          _stableSummary().copyWith(
            specificProofExampleRememberedCount: 3,
            wouldPayYesMaybeCount: 1,
          ),
        ),
        ProofRelevanceOutcomeDecision.proofStableReturnToEvidenceTrail,
      );
    });

    test('proof stable plus value signals returns productionCandidate', () {
      expect(
        ProofRelevanceOutcomeMatrix.resolve(_productionPassingSummary()),
        ProofRelevanceOutcomeDecision.productionCandidate,
      );
      expect(
        ProofRelevanceOutcomeMatrix.resolve(
          _productionPassingSummary(totalTesters: 20),
        ),
        ProofRelevanceOutcomeDecision.productionCandidate,
      );
    });

    test('high vague beats understanding and value signals', () {
      expect(
        ProofRelevanceOutcomeMatrix.resolve(
          _summary(
            usefulProofCount: 10,
            tooVagueOrNotRelevantCount: 7,
            understoodWhatItNoticedCount: 8,
            couldTellIfRightCount: 8,
            didNotFeelLikeVagueAiCount: 8,
            specificProofExampleRememberedCount: 5,
            wouldPayYesMaybeCount: 4,
          ),
        ),
        ProofRelevanceOutcomeDecision.proofStillTooVague,
      );
    });

    test('poor understanding beats value signals', () {
      expect(
        ProofRelevanceOutcomeMatrix.resolve(
          _summary(
            usefulProofCount: 10,
            tooVagueOrNotRelevantCount: 2,
            understoodWhatItNoticedCount: 4,
            couldTellIfRightCount: 8,
            didNotFeelLikeVagueAiCount: 8,
            specificProofExampleRememberedCount: 5,
            wouldPayYesMaybeCount: 4,
          ),
        ),
        ProofRelevanceOutcomeDecision.proofNotUnderstood,
      );
    });

    test('conservative fallback returns proofNotUnderstood', () {
      expect(
        ProofRelevanceOutcomeMatrix.resolve(
          _summary(
            totalTesters: 20,
            usefulProofCount: 4,
            tooVagueOrNotRelevantCount: 2,
            understoodWhatItNoticedCount: 4,
            couldTellIfRightCount: 4,
            didNotFeelLikeVagueAiCount: 3,
          ),
        ),
        ProofRelevanceOutcomeDecision.proofNotUnderstood,
      );
    });
  });

  group('ProofRelevanceOutcomeCopy.report', () {
    test('returns correct nextAction and guardrail for each decision', () {
      final cases = <(ProofRelevanceOutcomeSummary, String)>[
        (
          _summary(totalTesters: 19),
          'Keep testing the proof relevance build until at least 20 testers '
              'complete the flow.',
        ),
        (
          _summary(totalTesters: 30, tooVagueOrNotRelevantCount: 6),
          'Repair proof explanation or evidence display. Do not tighten anchors '
              'blindly.',
        ),
        (
          _summary(totalTesters: 30, understoodWhatItNoticedCount: 5),
          'Make the proof explanation clearer before returning to Pro or pricing.',
        ),
        (
          _stableSummary().copyWith(
            specificProofExampleRememberedCount: 3,
            wouldPayYesMaybeCount: 1,
          ),
          'Return to evidence-trail clarity and Pro understanding test.',
        ),
        (
          _productionPassingSummary(),
          'Stop product development and finish App Store readiness.',
        ),
      ];

      for (final (summary, expectedNextAction) in cases) {
        final decision = ProofRelevanceOutcomeMatrix.resolve(summary);
        final report = ProofRelevanceOutcomeCopy.report(summary, decision);
        expect(report.nextAction, expectedNextAction);
        expect(report.guardrail, ProofRelevanceOutcomeCopy.guardrail);
        expect(report.title, ProofRelevanceOutcomeCopy.titleFor(decision));
        expect(report.body, ProofRelevanceOutcomeCopy.bodyFor(decision));
      }
    });

    test('passes metadata-safe guard', () {
      for (final text in ProofRelevanceOutcomeCopy.allVisibleStrings()) {
        expect(ProofSurfaceAdviceGuard.passes(text), isTrue, reason: text);
      }
    });
  });

  group('Protected areas', () {
    test('no imports from Pro pricing paywall or evidence-trail features', () {
      for (final path in [
        'lib/features/proof_relevance_repair/proof_relevance_outcome_matrix.dart',
        'lib/features/proof_relevance_repair/proof_relevance_outcome_copy.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source.contains('PaywallSource'), isFalse);
        expect(source.contains('RevenueCat'), isFalse);
        expect(source.contains('restorePurchases'), isFalse);
        expect(source.contains('billing/'), isFalse);
        expect(source.contains('record_screen'), isFalse);
        expect(source.contains('evidence_trail_clarity'), isFalse);
        expect(source.contains('pricing_validation'), isFalse);
      }
    });
  });
}
