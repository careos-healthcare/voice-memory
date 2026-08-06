import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/beta_repair_lab/beta_repair_lab_engine.dart';
import 'package:voicememory_mobile/features/beta_repair_lab/beta_repair_lab_model.dart';
import 'package:voicememory_mobile/features/beta_repair_lab/beta_repair_lab_store.dart';
import 'package:voicememory_mobile/features/evidence_trail_clarity/evidence_trail_clarity_engine.dart';
import 'package:voicememory_mobile/features/pricing_validation/pricing_validation_engine.dart';
import 'package:voicememory_mobile/features/proof_clarity_importance_diagnostic/proof_clarity_importance_diagnostic.dart';
import 'package:voicememory_mobile/features/proof_clarity_importance_diagnostic/proof_clarity_importance_diagnostic_copy.dart';
import 'package:voicememory_mobile/features/proof_confidence_calibration/proof_confidence_calibration_model.dart';
import 'package:voicememory_mobile/features/proof_detail_repair/proof_detail_repair_copy.dart';

ProofClarityImportanceSummary _summary({
  int totalTesters = 30,
  int usefulProofCount = 10,
  int tooVagueOrNotRelevantCount = 2,
  int proofExplanationClearCount = 8,
  int wantsRankingImportanceCount = 2,
}) => ProofClarityImportanceSummary(
  totalTesters: totalTesters,
  usefulProofCount: usefulProofCount,
  tooVagueOrNotRelevantCount: tooVagueOrNotRelevantCount,
  proofExplanationClearCount: proofExplanationClearCount,
  wantsRankingImportanceCount: wantsRankingImportanceCount,
);

ProofClarityImportanceSummary _stableSummary({int totalTesters = 30}) =>
    _summary(
      totalTesters: totalTesters,
      usefulProofCount: totalTesters == 20 ? 5 : 7,
      tooVagueOrNotRelevantCount: totalTesters == 20 ? 3 : 5,
      proofExplanationClearCount: totalTesters == 20 ? 4 : 6,
      wantsRankingImportanceCount: totalTesters == 20 ? 3 : 5,
    );

BetaRepairLabVisibilityInput _repairInput() => BetaRepairLabVisibilityInput(
  mode: BetaRepairLabMode.evidenceTrailTimelineClarity,
  entryCount: 4,
  source: 'test',
  isPro: false,
  isRecording: false,
  isDegradedTranscriptState: false,
  whatChangedQuestionActive: false,
  patternReviewInboxHasActiveItems: false,
  hasTimelineProofVisible: true,
  hasConfirmedRepeat: true,
  confidenceLevel: ProofConfidenceLevel.watchOnly,
  hasUsefulProofFeedback: false,
  feedbackType: null,
  isNegativeFeedback: false,
  betaMissionEnabled: true,
);

void main() {
  group('ProofClarityImportanceDiagnostic thresholds', () {
    test('30 tester exact targets', () {
      expect(ProofClarityImportanceDiagnostic.usefulProofTargetFor(30), 7);
      expect(ProofClarityImportanceDiagnostic.tooVagueHighTargetFor(30), 6);
      expect(
        ProofClarityImportanceDiagnostic.proofExplanationClearTargetFor(30),
        6,
      );
      expect(
        ProofClarityImportanceDiagnostic.wantsRankingImportanceTargetFor(30),
        6,
      );
    });

    test('20 tester scaled targets', () {
      expect(ProofClarityImportanceDiagnostic.usefulProofTargetFor(20), 5);
      expect(ProofClarityImportanceDiagnostic.tooVagueHighTargetFor(20), 4);
      expect(
        ProofClarityImportanceDiagnostic.proofExplanationClearTargetFor(20),
        4,
      );
      expect(
        ProofClarityImportanceDiagnostic.wantsRankingImportanceTargetFor(20),
        4,
      );
    });
  });

  group('ProofClarityImportanceDiagnostic.resolve', () {
    test('under 20 testers returns insufficientData', () {
      expect(
        ProofClarityImportanceDiagnostic.resolve(_summary(totalTesters: 19)),
        ProofClarityImportanceDecision.insufficientData,
      );
    });

    test(
      'high vague and ranking demand returns bothProblemsRepairExplanationFirst',
      () {
        expect(
          ProofClarityImportanceDiagnostic.resolve(
            _summary(
              tooVagueOrNotRelevantCount: 6,
              wantsRankingImportanceCount: 6,
            ),
          ),
          ProofClarityImportanceDecision.bothProblemsRepairExplanationFirst,
        );
      },
    );

    test('high vague returns repairProofExplanation', () {
      expect(
        ProofClarityImportanceDiagnostic.resolve(
          _summary(tooVagueOrNotRelevantCount: 6),
        ),
        ProofClarityImportanceDecision.repairProofExplanation,
      );
    });

    test('low explanation clear returns repairProofExplanation', () {
      expect(
        ProofClarityImportanceDiagnostic.resolve(
          _summary(proofExplanationClearCount: 5),
        ),
        ProofClarityImportanceDecision.repairProofExplanation,
      );
    });

    test(
      'ranking demand with clear explanation returns investigateRankingImportance',
      () {
        expect(
          ProofClarityImportanceDiagnostic.resolve(
            _summary(
              proofExplanationClearCount: 8,
              wantsRankingImportanceCount: 7,
            ),
          ),
          ProofClarityImportanceDecision.investigateRankingImportance,
        );
      },
    );

    test('stable signals return proofExplanationStable', () {
      expect(
        ProofClarityImportanceDiagnostic.resolve(_stableSummary()),
        ProofClarityImportanceDecision.proofExplanationStable,
      );
      expect(
        ProofClarityImportanceDiagnostic.resolve(
          _stableSummary(totalTesters: 20),
        ),
        ProofClarityImportanceDecision.proofExplanationStable,
      );
    });

    test('vague high beats ranking-only investigation', () {
      expect(
        ProofClarityImportanceDiagnostic.resolve(
          _summary(
            tooVagueOrNotRelevantCount: 7,
            proofExplanationClearCount: 8,
            wantsRankingImportanceCount: 7,
          ),
        ),
        ProofClarityImportanceDecision.bothProblemsRepairExplanationFirst,
      );
    });

    test('low explanation beats ranking investigation', () {
      expect(
        ProofClarityImportanceDiagnostic.resolve(
          _summary(
            proofExplanationClearCount: 4,
            wantsRankingImportanceCount: 8,
          ),
        ),
        ProofClarityImportanceDecision.repairProofExplanation,
      );
    });

    test('conservative fallback returns repairProofExplanation', () {
      expect(
        ProofClarityImportanceDiagnostic.resolve(
          _summary(
            totalTesters: 20,
            usefulProofCount: 4,
            proofExplanationClearCount: 4,
            wantsRankingImportanceCount: 3,
          ),
        ),
        ProofClarityImportanceDecision.repairProofExplanation,
      );
    });
  });

  group('ProofClarityImportanceDiagnosticCopy', () {
    test('includes facilitator diagnostic questions', () {
      expect(
        ProofClarityImportanceDiagnosticCopy
            .facilitatorQuestionExplanationClear,
        contains('clear enough'),
      );
      expect(
        ProofClarityImportanceDiagnosticCopy.facilitatorQuestionWantsRanking,
        contains('rank or prioritize'),
      );
    });

    test('returns correct nextAction and guardrail for each decision', () {
      final cases = <(ProofClarityImportanceSummary, String)>[
        (
          _summary(totalTesters: 19),
          'Keep testing Build 69 until at least 20 testers complete proof '
              'detail and facilitator questions.',
        ),
        (
          _summary(tooVagueOrNotRelevantCount: 6),
          'Repair proof explanation copy only. Do not tighten anchors or add '
              'more proof.',
        ),
        (
          _summary(
            tooVagueOrNotRelevantCount: 6,
            wantsRankingImportanceCount: 6,
          ),
          'Repair proof explanation before investigating ranking or '
              'importance features.',
        ),
        (
          _summary(
            proofExplanationClearCount: 8,
            wantsRankingImportanceCount: 7,
          ),
          'Run follow-up interviews on ranking demand. Do not build ranked '
              'lists or change anchors yet.',
        ),
        (
          _stableSummary(),
          'Return to evidence-trail clarity and value signals. Do not add '
              'ranking yet.',
        ),
      ];

      for (final (summary, expectedNextAction) in cases) {
        final decision = ProofClarityImportanceDiagnostic.resolve(summary);
        final report = ProofClarityImportanceDiagnosticCopy.report(
          summary,
          decision,
        );
        expect(report.nextAction, expectedNextAction);
        expect(
          report.guardrail,
          ProofClarityImportanceDiagnosticCopy.guardrail,
        );
        expect(
          report.title,
          ProofClarityImportanceDiagnosticCopy.titleFor(decision),
        );
      }
    });

    test('passes metadata-safe guard', () {
      for (final text
          in ProofClarityImportanceDiagnosticCopy.allVisibleStrings()) {
        expect(ProofSurfaceAdviceGuard.passes(text), isTrue, reason: text);
      }
    });
  });

  group('Proof detail clarification copy', () {
    test('detail explains why this one was selected and not ranked yet', () {
      final body = ProofDetailRepairCopy.composeBody(
        'said yes when I had no capacity',
      );
      expect(body, contains(ProofDetailRepairCopy.whyThisOneLine));
      expect(
        body,
        contains(ProofDetailRepairCopy.notRankingOrMostImportantLine),
      );
      expect(body, contains('not ranking every past mention yet'));
    });
  });

  group('Protected areas', () {
    test(
      'diagnostic does not import anchors pro pricing paywall or evidence trail',
      () {
        for (final path in [
          'lib/features/proof_clarity_importance_diagnostic/proof_clarity_importance_diagnostic.dart',
          'lib/features/proof_clarity_importance_diagnostic/proof_clarity_importance_diagnostic_copy.dart',
          'lib/features/proof_detail_repair/proof_detail_repair_copy.dart',
        ]) {
          final source = File(path).readAsStringSync();
          expect(source.contains('anchor_specificity_guard'), isFalse);
          expect(source.contains('PaywallSource'), isFalse);
          expect(source.contains('RevenueCat'), isFalse);
          expect(source.contains('billing/'), isFalse);
          expect(source.contains('evidence_trail_clarity'), isFalse);
          expect(source.contains('pricing_validation'), isFalse);
        }
      },
    );

    test('pro pricing evidence trail behaviour unchanged', () {
      expect(
        EvidenceTrailClarityEngine.shouldShow(
          input: _repairInput(),
          hasSafeAnchor: false,
        ),
        isFalse,
      );
      BetaRepairLabStore.repairModeOverrideForTest = 'pricingValidation';
      expect(
        PricingValidationEngine.shouldShow(
          input: _repairInput(),
          hasProEngagement: true,
        ),
        isFalse,
      );
    });

    test('anchor guard module not modified by diagnostic', () {
      final source = File(
        'lib/features/proof_protection/anchor_specificity_guard.dart',
      ).readAsStringSync();
      expect(source.contains('isBehaviorSpecific'), isTrue);
    });
  });
}
