import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/beta_proof_feedback/beta_proof_feedback_model.dart';
import 'package:voicememory_mobile/features/beta_repair_lab/beta_repair_lab_model.dart';
import 'package:voicememory_mobile/features/beta_repair_lab/beta_repair_lab_store.dart';
import 'package:voicememory_mobile/features/evidence_trail_clarity/evidence_trail_clarity_engine.dart';
import 'package:voicememory_mobile/features/evidence_trail_pro_understanding/evidence_trail_pro_understanding.dart';
import 'package:voicememory_mobile/features/evidence_trail_pro_understanding/evidence_trail_pro_understanding_copy.dart';
import 'package:voicememory_mobile/features/pricing_validation/pricing_validation_engine.dart';
import 'package:voicememory_mobile/features/proof_confidence_calibration/proof_confidence_calibration_model.dart';
import 'package:voicememory_mobile/features/proof_detail_repair/proof_detail_repair_copy.dart';
import 'package:voicememory_mobile/features/proof_selection/proof_selection_principle.dart';

EvidenceTrailProUnderstandingSummary _summary({
  int totalTesters = 30,
  int usefulProofCount = 10,
  int understoodFirstProofCount = 8,
  int understoodLongerTrailCount = 8,
  int understoodProKeepsChangesCount = 8,
  int thoughtProWasMoreAiCount = 2,
  int wantedRankingCount = 2,
  int paywallCtaTapCount = 2,
  int wouldPayYesMaybeCount = 4,
}) =>
    EvidenceTrailProUnderstandingSummary(
      totalTesters: totalTesters,
      usefulProofCount: usefulProofCount,
      understoodFirstProofCount: understoodFirstProofCount,
      understoodLongerTrailCount: understoodLongerTrailCount,
      understoodProKeepsChangesCount: understoodProKeepsChangesCount,
      thoughtProWasMoreAiCount: thoughtProWasMoreAiCount,
      wantedRankingCount: wantedRankingCount,
      paywallCtaTapCount: paywallCtaTapCount,
      wouldPayYesMaybeCount: wouldPayYesMaybeCount,
    );

EvidenceTrailProUnderstandingSummary _productionPassingSummary({
  int totalTesters = 30,
}) =>
    _summary(
      totalTesters: totalTesters,
      usefulProofCount: totalTesters == 20 ? 5 : 7,
      understoodLongerTrailCount: totalTesters == 20 ? 4 : 6,
      understoodProKeepsChangesCount: totalTesters == 20 ? 4 : 6,
      paywallCtaTapCount: 1,
      wouldPayYesMaybeCount: totalTesters == 20 ? 2 : 3,
    );

BetaRepairLabVisibilityInput _strongEvidenceTrailInput() =>
    BetaRepairLabVisibilityInput(
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
      confidenceLevel: ProofConfidenceLevel.strong,
      hasUsefulProofFeedback: true,
      feedbackType: BetaProofFeedbackType.useful,
      isNegativeFeedback: false,
      betaMissionEnabled: true,
    );

BetaRepairLabVisibilityInput _repairInput() =>
    BetaRepairLabVisibilityInput(
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
  group('EvidenceTrailProUnderstanding thresholds', () {
    test('30 tester exact targets', () {
      expect(EvidenceTrailProUnderstanding.usefulProofTargetFor(30), 7);
      expect(
        EvidenceTrailProUnderstanding.understoodLongerTrailTargetFor(30),
        6,
      );
      expect(
        EvidenceTrailProUnderstanding.understoodProKeepsChangesTargetFor(30),
        6,
      );
      expect(
        EvidenceTrailProUnderstanding.thoughtProWasMoreAiHighTargetFor(30),
        6,
      );
      expect(EvidenceTrailProUnderstanding.wantedRankingHighTargetFor(30), 6);
      expect(EvidenceTrailProUnderstanding.paywallCtaTapTargetFor(30), 1);
      expect(EvidenceTrailProUnderstanding.wouldPayTargetFor(30), 3);
    });

    test('20 tester scaled targets', () {
      expect(EvidenceTrailProUnderstanding.usefulProofTargetFor(20), 5);
      expect(
        EvidenceTrailProUnderstanding.understoodLongerTrailTargetFor(20),
        4,
      );
      expect(
        EvidenceTrailProUnderstanding.understoodProKeepsChangesTargetFor(20),
        4,
      );
      expect(
        EvidenceTrailProUnderstanding.thoughtProWasMoreAiHighTargetFor(20),
        4,
      );
      expect(EvidenceTrailProUnderstanding.wantedRankingHighTargetFor(20), 4);
      expect(EvidenceTrailProUnderstanding.paywallCtaTapTargetFor(20), 1);
      expect(EvidenceTrailProUnderstanding.wouldPayTargetFor(20), 2);
    });
  });

  group('EvidenceTrailProUnderstanding.resolve', () {
    test('under 20 testers returns insufficientData', () {
      expect(
        EvidenceTrailProUnderstanding.resolve(_summary(totalTesters: 19)),
        EvidenceTrailProUnderstandingDecision.insufficientData,
      );
    });

    test('weak useful proof returns repairProofFirst', () {
      expect(
        EvidenceTrailProUnderstanding.resolve(
          _summary(usefulProofCount: 6),
        ),
        EvidenceTrailProUnderstandingDecision.repairProofFirst,
      );
    });

    test('low longer-trail understanding returns explainLongerTrail', () {
      expect(
        EvidenceTrailProUnderstanding.resolve(
          _summary(understoodLongerTrailCount: 5),
        ),
        EvidenceTrailProUnderstandingDecision.explainLongerTrail,
      );
    });

    test('high more-AI confusion returns removeMoreAiConfusion', () {
      expect(
        EvidenceTrailProUnderstanding.resolve(
          _summary(thoughtProWasMoreAiCount: 6),
        ),
        EvidenceTrailProUnderstandingDecision.removeMoreAiConfusion,
      );
    });

    test('ranking wanted but longer-trail understood returns holdRanking', () {
      expect(
        EvidenceTrailProUnderstanding.resolve(
          _summary(
            understoodLongerTrailCount: 8,
            understoodProKeepsChangesCount: 8,
            wantedRankingCount: 7,
          ),
        ),
        EvidenceTrailProUnderstandingDecision.holdRanking,
      );
    });

    test(
      'proof and understanding pass but payment weak returns readyForPricingValidation',
      () {
        expect(
          EvidenceTrailProUnderstanding.resolve(
            _summary(
              usefulProofCount: 8,
              understoodLongerTrailCount: 8,
              understoodProKeepsChangesCount: 8,
              paywallCtaTapCount: 0,
              wouldPayYesMaybeCount: 1,
            ),
          ),
          EvidenceTrailProUnderstandingDecision.readyForPricingValidation,
        );
      },
    );

    test(
      'proof understanding CTA and would-pay pass returns productionCandidate',
      () {
        expect(
          EvidenceTrailProUnderstanding.resolve(_productionPassingSummary()),
          EvidenceTrailProUnderstandingDecision.productionCandidate,
        );
        expect(
          EvidenceTrailProUnderstanding.resolve(
            _productionPassingSummary(totalTesters: 20),
          ),
          EvidenceTrailProUnderstandingDecision.productionCandidate,
        );
      },
    );

    test('more-AI confusion beats ranking and pricing signals', () {
      expect(
        EvidenceTrailProUnderstanding.resolve(
          _summary(
            thoughtProWasMoreAiCount: 7,
            wantedRankingCount: 7,
            paywallCtaTapCount: 2,
            wouldPayYesMaybeCount: 4,
          ),
        ),
        EvidenceTrailProUnderstandingDecision.removeMoreAiConfusion,
      );
    });

    test('conservative fallback returns explainLongerTrail', () {
      expect(
        EvidenceTrailProUnderstanding.resolve(
          _summary(
            totalTesters: 20,
            usefulProofCount: 5,
            understoodLongerTrailCount: 4,
            understoodProKeepsChangesCount: 3,
          ),
        ),
        EvidenceTrailProUnderstandingDecision.explainLongerTrail,
      );
    });
  });

  group('EvidenceTrailProUnderstandingCopy', () {
    test('copy says Keep the longer trail', () {
      expect(
        EvidenceTrailProUnderstandingCopy.title,
        'Keep the longer trail',
      );
    });

    test('copy says Free shows first proof', () {
      expect(
        EvidenceTrailProUnderstandingCopy.supportingLine,
        contains('Free shows the first proof'),
      );
    });

    test('copy says Pro keeps evidence trail over time', () {
      expect(
        EvidenceTrailProUnderstandingCopy.supportingLine,
        contains('Pro keeps the evidence trail over time'),
      );
    });

    test('copy includes returns changes softens strengthens fades corrected', () {
      final body = EvidenceTrailProUnderstandingCopy.body.toLowerCase();
      expect(body, contains('returns'));
      expect(body, contains('changes'));
      expect(body, contains('softens'));
      expect(body, contains('strengthens'));
      expect(body, contains('fades'));
      expect(body, contains('corrected'));
    });

    test('copy does not say ranking as a product claim', () {
      for (final text in [
        EvidenceTrailProUnderstandingCopy.title,
        EvidenceTrailProUnderstandingCopy.body,
        EvidenceTrailProUnderstandingCopy.supportingLine,
        EvidenceTrailProUnderstandingCopy.cta,
      ]) {
        expect(text.toLowerCase().contains('ranking'), isFalse, reason: text);
      }
    });

    test('copy does not say advice as a product claim', () {
      for (final text in [
        EvidenceTrailProUnderstandingCopy.title,
        EvidenceTrailProUnderstandingCopy.body,
        EvidenceTrailProUnderstandingCopy.supportingLine,
        EvidenceTrailProUnderstandingCopy.cta,
        EvidenceTrailProUnderstandingCopy.secondary,
        EvidenceTrailProUnderstandingCopy.clarityQuestion,
      ]) {
        expect(text.toLowerCase().contains('advice'), isFalse, reason: text);
      }
    });

    test('copy does not say therapy diagnosis or coaching', () {
      for (final text in EvidenceTrailProUnderstandingCopy.allVisibleStrings()) {
        expect(ProofSurfaceAdviceGuard.passes(text), isTrue, reason: text);
        final lower = text.toLowerCase();
        expect(lower.contains('therapy'), isFalse, reason: text);
        expect(lower.contains('diagnosis'), isFalse, reason: text);
        expect(lower.contains('coaching'), isFalse, reason: text);
      }
    });

    test('guardrail blocks selling Pro before users understand trail', () {
      expect(
        EvidenceTrailProUnderstandingCopy.guardrail,
        contains('Do not sell Pro until users understand'),
      );
      expect(
        EvidenceTrailProUnderstandingCopy.guardrail,
        contains('longer evidence trail'),
      );
    });

    test('clarity options include Yes Not yet and I need more proof first', () {
      expect(
        EvidenceTrailProUnderstandingCopy.clarityOptions,
        [
          'Yes',
          'Not yet',
          'I need more proof first',
        ],
      );
    });
  });

  group('Protected areas', () {
    test('module does not import ranking importance scoring or billing', () {
      for (final path in [
        'lib/features/evidence_trail_pro_understanding/evidence_trail_pro_understanding.dart',
        'lib/features/evidence_trail_pro_understanding/evidence_trail_pro_understanding_copy.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source.contains('proof_selection_principle'), isFalse);
        expect(source.contains('importance_scoring'), isFalse);
        expect(source.contains('RevenueCat'), isFalse);
        expect(source.contains('restorePurchases'), isFalse);
        expect(source.contains('billing/'), isFalse);
        expect(source.contains('anchor_specificity_guard'), isFalse);
        expect(source.contains('journal_storage'), isFalse);
      }
    });

    test('evidence trail and pricing validation behaviour unchanged', () {
      BetaRepairLabStore.repairModeOverrideForTest =
          'evidenceTrailTimelineClarity';
      expect(
        EvidenceTrailClarityEngine.shouldShow(
          input: _strongEvidenceTrailInput(),
          hasSafeAnchor: true,
        ),
        isTrue,
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

    test('proof selection principle still blocks ranking', () {
      expect(ProofSelectionPrinciple.allowsRankingUi(), isFalse);
      expect(ProofDetailRepairCopy.whyThisOneLine, contains('clearest specific repeat'));
    });
  });
}
