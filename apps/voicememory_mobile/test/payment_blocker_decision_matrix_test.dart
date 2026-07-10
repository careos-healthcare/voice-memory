import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/beta_repair_lab/beta_repair_lab_model.dart';
import 'package:voicememory_mobile/features/beta_repair_lab/beta_repair_lab_store.dart';
import 'package:voicememory_mobile/features/evidence_trail_pro_understanding/evidence_trail_pro_understanding.dart';
import 'package:voicememory_mobile/features/payment_blocker_matrix/payment_blocker_decision_copy.dart';
import 'package:voicememory_mobile/features/payment_blocker_matrix/payment_blocker_decision_matrix.dart';
import 'package:voicememory_mobile/features/pricing_offer_validation/pricing_offer_validation_v2.dart';
import 'package:voicememory_mobile/features/pricing_validation/pricing_validation_engine.dart';
import 'package:voicememory_mobile/features/proof_confidence_calibration/proof_confidence_calibration_model.dart';
import 'package:voicememory_mobile/features/proof_detail_repair/proof_detail_repair_copy.dart';
import 'package:voicememory_mobile/features/proof_selection/proof_selection_principle.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_engine.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_model.dart';
import 'package:voicememory_mobile/features/value_prop_ranking_diagnostic/value_prop_ranking_diagnostic.dart';

PaymentBlockerSummary _summary({
  int totalTesters = 30,
  int usefulProofCount = 10,
  int understoodLongerTrailCount = 8,
  int understoodNotMoreAiCount = 8,
  int payYesCount = 2,
  int payMaybeCount = 1,
  int payNoCount = 2,
  int needSeeOverTimeCount = 1,
  int needStrongerProofCount = 1,
  int needRankingBeforePayingCount = 1,
  int priceTooHighCount = 1,
  int worthPayingCount = 1,
}) =>
    PaymentBlockerSummary(
      totalTesters: totalTesters,
      usefulProofCount: usefulProofCount,
      understoodLongerTrailCount: understoodLongerTrailCount,
      understoodNotMoreAiCount: understoodNotMoreAiCount,
      payYesCount: payYesCount,
      payMaybeCount: payMaybeCount,
      payNoCount: payNoCount,
      needSeeOverTimeCount: needSeeOverTimeCount,
      needStrongerProofCount: needStrongerProofCount,
      needRankingBeforePayingCount: needRankingBeforePayingCount,
      priceTooHighCount: priceTooHighCount,
      worthPayingCount: worthPayingCount,
    );

PaymentBlockerSummary _corePassingSummary({
  int totalTesters = 30,
}) =>
    _summary(
      totalTesters: totalTesters,
      usefulProofCount: totalTesters == 20 ? 5 : 7,
      understoodLongerTrailCount: totalTesters == 20 ? 4 : 6,
      understoodNotMoreAiCount: totalTesters == 20 ? 4 : 6,
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
  group('PaymentBlockerDecisionMatrix thresholds', () {
    test('30 tester exact targets', () {
      expect(PaymentBlockerDecisionMatrix.usefulProofTargetFor(30), 7);
      expect(PaymentBlockerDecisionMatrix.understoodLongerTrailTargetFor(30), 6);
      expect(PaymentBlockerDecisionMatrix.understoodNotMoreAiTargetFor(30), 6);
      expect(PaymentBlockerDecisionMatrix.payYesMaybeTargetFor(30), 3);
      expect(PaymentBlockerDecisionMatrix.worthPayingTargetFor(30), 3);
      expect(PaymentBlockerDecisionMatrix.needSeeOverTimeHighTargetFor(30), 6);
      expect(
        PaymentBlockerDecisionMatrix.needStrongerProofHighTargetFor(30),
        6,
      );
      expect(
        PaymentBlockerDecisionMatrix.needRankingBeforePayingHighTargetFor(30),
        6,
      );
      expect(PaymentBlockerDecisionMatrix.priceTooHighHighTargetFor(30), 6);
    });
  });

  group('PaymentBlockerDecisionMatrix.resolve', () {
    test('under 20 testers returns insufficientData', () {
      expect(
        PaymentBlockerDecisionMatrix.resolve(_summary(totalTesters: 19)),
        PaymentBlockerDecision.insufficientData,
      );
    });

    test('weak useful proof returns repairProofFirst', () {
      expect(
        PaymentBlockerDecisionMatrix.resolve(
          _summary(totalTesters: 30, usefulProofCount: 4),
        ),
        PaymentBlockerDecision.repairProofFirst,
      );
    });

    test('weak longer-trail understanding returns repairProUnderstanding', () {
      expect(
        PaymentBlockerDecisionMatrix.resolve(
          _corePassingSummary().copyWith(understoodLongerTrailCount: 3),
        ),
        PaymentBlockerDecision.repairProUnderstanding,
      );
    });

    test('weak not-more-AI understanding returns repairProUnderstanding', () {
      expect(
        PaymentBlockerDecisionMatrix.resolve(
          _corePassingSummary().copyWith(understoodNotMoreAiCount: 3),
        ),
        PaymentBlockerDecision.repairProUnderstanding,
      );
    });

    test('price too high high returns validatePriceCopy', () {
      expect(
        PaymentBlockerDecisionMatrix.resolve(
          _corePassingSummary().copyWith(priceTooHighCount: 6),
        ),
        PaymentBlockerDecision.validatePriceCopy,
      );
    });

    test('need see over time high returns validateLongerTrailValue', () {
      expect(
        PaymentBlockerDecisionMatrix.resolve(
          _corePassingSummary().copyWith(needSeeOverTimeCount: 7),
        ),
        PaymentBlockerDecision.validateLongerTrailValue,
      );
    });

    test('need stronger proof high returns sharpenProofValueProposition', () {
      expect(
        PaymentBlockerDecisionMatrix.resolve(
          _corePassingSummary().copyWith(needStrongerProofCount: 7),
        ),
        PaymentBlockerDecision.sharpenProofValueProposition,
      );
    });

    test(
      'need ranking before paying high returns investigatePrioritisationConceptOnly',
      () {
        expect(
          PaymentBlockerDecisionMatrix.resolve(
            _corePassingSummary().copyWith(needRankingBeforePayingCount: 7),
          ),
          PaymentBlockerDecision.investigatePrioritisationConceptOnly,
        );
      },
    );

    test('need stronger proof beats ranking', () {
      expect(
        PaymentBlockerDecisionMatrix.resolve(
          _corePassingSummary().copyWith(
            needStrongerProofCount: 7,
            needRankingBeforePayingCount: 7,
          ),
        ),
        PaymentBlockerDecision.sharpenProofValueProposition,
      );
    });

    test('need see over time beats stronger proof', () {
      expect(
        PaymentBlockerDecisionMatrix.resolve(
          _corePassingSummary().copyWith(
            needSeeOverTimeCount: 7,
            needStrongerProofCount: 7,
          ),
        ),
        PaymentBlockerDecision.validateLongerTrailValue,
      );
    });

    test('price too high beats see over time', () {
      expect(
        PaymentBlockerDecisionMatrix.resolve(
          _corePassingSummary().copyWith(
            priceTooHighCount: 6,
            needSeeOverTimeCount: 7,
          ),
        ),
        PaymentBlockerDecision.validatePriceCopy,
      );
    });

    test(
      'pay yes/maybe and worth paying pass returns productionCandidate',
      () {
        expect(
          PaymentBlockerDecisionMatrix.resolve(
            _corePassingSummary().copyWith(
              payYesCount: 2,
              payMaybeCount: 1,
              worthPayingCount: 3,
            ),
          ),
          PaymentBlockerDecision.productionCandidate,
        );
      },
    );

    test('conservative fallback returns sharpenProofValueProposition', () {
      expect(
        PaymentBlockerDecisionMatrix.resolve(
          _corePassingSummary().copyWith(
            payYesCount: 0,
            payMaybeCount: 1,
            worthPayingCount: 1,
          ),
        ),
        PaymentBlockerDecision.sharpenProofValueProposition,
      );
    });
  });

  group('PaymentBlockerDecisionCopy', () {
    test('copy says validate longer-trail value, not features', () {
      expect(
        PaymentBlockerDecisionCopy.validateLongerTrailValue,
        contains('enough value to pay for'),
      );
      expect(
        PaymentBlockerDecisionCopy.validateLongerTrailValue.toLowerCase(),
        isNot(contains('feature')),
      );
    });

    test('copy says sharpen proof value proposition, not more proof', () {
      expect(
        PaymentBlockerDecisionCopy.sharpenProofValueProposition,
        contains('first proof matters'),
      );
      expect(
        PaymentBlockerDecisionCopy.sharpenProofValueProposition,
        contains('Do not add more proof yet'),
      );
    });

    test('copy says investigate prioritisation concept only', () {
      expect(
        PaymentBlockerDecisionCopy.investigatePrioritisationConceptOnly,
        contains('prioritisation would help payment intent'),
      );
    });

    test('copy says do not build ranked lists', () {
      expect(
        PaymentBlockerDecisionCopy.investigatePrioritisationConceptOnly,
        contains('Do not build ranked lists'),
      );
    });

    test('guardrail says ranking is not a product build yet', () {
      expect(
        PaymentBlockerDecisionCopy.guardrail,
        contains('not a product build yet'),
      );
    });

    test('copy avoids therapy diagnosis coaching and advice claims', () {
      for (final text in PaymentBlockerDecisionCopy.allVisibleStrings()) {
        expect(ProofSurfaceAdviceGuard.passes(text), isTrue, reason: text);
        final lower = text.toLowerCase();
        expect(lower.contains('advice'), isFalse, reason: text);
        expect(lower.contains('therapy'), isFalse, reason: text);
        expect(lower.contains('diagnosis'), isFalse, reason: text);
        expect(lower.contains('coaching'), isFalse, reason: text);
      }
    });
  });

  group('Protected areas', () {
    test('module does not import billing entitlements or ranking UI', () {
      for (final path in [
        'lib/features/payment_blocker_matrix/payment_blocker_decision_matrix.dart',
        'lib/features/payment_blocker_matrix/payment_blocker_decision_copy.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source.contains('RevenueCat'), isFalse);
        expect(source.contains('restorePurchases'), isFalse);
        expect(source.contains('billing/'), isFalse);
        expect(source.contains('importance_scoring'), isFalse);
        expect(source.contains('proof_selection_principle'), isFalse);
        expect(source.contains('anchor_specificity_guard'), isFalse);
        expect(source.contains('journal_storage'), isFalse);
        expect(source.contains('paywall'), isFalse);
      }
    });

    test('existing diagnostic modules behaviour unchanged', () {
      BetaRepairLabStore.repairModeOverrideForTest = 'pricingValidation';
      expect(
        PricingValidationEngine.shouldShow(
          input: _repairInput(),
          hasProEngagement: true,
        ),
        isFalse,
      );
      expect(
        ValuePropRankingDiagnostic.resolve(
          const ValuePropRankingDiagnosticSummary(
            totalTesters: 30,
            usefulProofCount: 7,
            understoodLongerTrailCount: 6,
            understoodNotMoreAiCount: 6,
            payYesCount: 2,
            payMaybeCount: 1,
            payNoCount: 1,
            needStrongerProofCount: 1,
            needSeeOverTimeCount: 1,
            needRankingBeforePayingCount: 1,
            priceTooHighCount: 1,
            worthPayingCount: 3,
          ),
        ),
        ValuePropRankingDiagnosticDecision.productionCandidate,
      );
      expect(
        PricingOfferValidationV2.resolve(
          const PricingOfferValidationSummary(
            totalTesters: 30,
            usefulProofCount: 7,
            understoodLongerTrailCount: 6,
            understoodNotMoreAiCount: 6,
            payYesCount: 2,
            payMaybeCount: 1,
            payNoCount: 1,
            priceTooHighCount: 1,
            needStrongerProofCount: 1,
            needRankingCount: 7,
            ctaTapCount: 1,
          ),
        ),
        PricingOfferValidationDecision.holdRanking,
      );
      expect(
        EvidenceTrailProUnderstanding.resolve(
          const EvidenceTrailProUnderstandingSummary(
            totalTesters: 30,
            usefulProofCount: 7,
            understoodFirstProofCount: 6,
            understoodLongerTrailCount: 6,
            understoodProKeepsChangesCount: 6,
            thoughtProWasMoreAiCount: 1,
            wantedRankingCount: 1,
            paywallCtaTapCount: 1,
            wouldPayYesMaybeCount: 3,
          ),
        ),
        EvidenceTrailProUnderstandingDecision.productionCandidate,
      );
    });

    test('proof selection principle still blocks ranking', () {
      expect(ProofSelectionPrinciple.allowsRankingUi(), isFalse);
      expect(
        ProofDetailRepairCopy.whyThisOneLine,
        contains('clearest specific repeat'),
      );
    });

    test('record screen remains capture-first without stacking extra cards', () {
      final audit = SurfacePriorityEngine.auditRecordReady(
        entryCount: 4,
        source: 'record',
        candidates: SurfacePriorityCandidates.recordReady(
          firstMomentCapture: false,
          secondMomentReturn: false,
          lowFrictionReturn: false,
          whatToNoticeNext: false,
          betaTodaySummary: false,
          openCapturePromptChips: false,
          captureFreedomLine: false,
          timelineProofMoment: true,
          archiveTimelineSpine: false,
          timelinePositioning: false,
          currentRelevance: false,
          correctionMemory: false,
          notRelevantRecovery: false,
          proofQualityResponse: false,
          evidenceWeighting: false,
          proofSpecificity: false,
          presentDayRelevance: false,
          patternConfidence: false,
          betaTesterReport: false,
          proEvidenceValue: false,
          privateReportProBridge: false,
          suppressLegacyEducation: false,
          betaProofLift: true,
        ),
      );
      expect(audit.proofCardKey, 'timelineProofMoment');
      expect(audit.guidanceCardKey, isNull);
    });
  });
}

extension on PaymentBlockerSummary {
  PaymentBlockerSummary copyWith({
    int? totalTesters,
    int? usefulProofCount,
    int? understoodLongerTrailCount,
    int? understoodNotMoreAiCount,
    int? payYesCount,
    int? payMaybeCount,
    int? payNoCount,
    int? needSeeOverTimeCount,
    int? needStrongerProofCount,
    int? needRankingBeforePayingCount,
    int? priceTooHighCount,
    int? worthPayingCount,
  }) =>
      PaymentBlockerSummary(
        totalTesters: totalTesters ?? this.totalTesters,
        usefulProofCount: usefulProofCount ?? this.usefulProofCount,
        understoodLongerTrailCount:
            understoodLongerTrailCount ?? this.understoodLongerTrailCount,
        understoodNotMoreAiCount:
            understoodNotMoreAiCount ?? this.understoodNotMoreAiCount,
        payYesCount: payYesCount ?? this.payYesCount,
        payMaybeCount: payMaybeCount ?? this.payMaybeCount,
        payNoCount: payNoCount ?? this.payNoCount,
        needSeeOverTimeCount:
            needSeeOverTimeCount ?? this.needSeeOverTimeCount,
        needStrongerProofCount:
            needStrongerProofCount ?? this.needStrongerProofCount,
        needRankingBeforePayingCount:
            needRankingBeforePayingCount ?? this.needRankingBeforePayingCount,
        priceTooHighCount: priceTooHighCount ?? this.priceTooHighCount,
        worthPayingCount: worthPayingCount ?? this.worthPayingCount,
      );
}
