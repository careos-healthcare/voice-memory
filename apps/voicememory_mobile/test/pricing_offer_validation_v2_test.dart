import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/beta_proof_feedback/beta_proof_feedback_model.dart';
import 'package:voicememory_mobile/features/beta_repair_lab/beta_repair_lab_model.dart';
import 'package:voicememory_mobile/features/beta_repair_lab/beta_repair_lab_store.dart';
import 'package:voicememory_mobile/features/evidence_trail_clarity/evidence_trail_clarity_engine.dart';
import 'package:voicememory_mobile/features/evidence_trail_pro_understanding/evidence_trail_pro_understanding.dart';
import 'package:voicememory_mobile/features/pricing_offer_validation/pricing_offer_validation_v2.dart';
import 'package:voicememory_mobile/features/pricing_offer_validation/pricing_offer_validation_v2_copy.dart';
import 'package:voicememory_mobile/features/pricing_validation/pricing_validation_engine.dart';
import 'package:voicememory_mobile/features/proof_confidence_calibration/proof_confidence_calibration_model.dart';
import 'package:voicememory_mobile/features/proof_detail_repair/proof_detail_repair_copy.dart';
import 'package:voicememory_mobile/features/proof_selection/proof_selection_principle.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_engine.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_model.dart';

PricingOfferValidationSummary _summary({
  int totalTesters = 30,
  int usefulProofCount = 10,
  int understoodLongerTrailCount = 8,
  int understoodNotMoreAiCount = 8,
  int payYesCount = 2,
  int payMaybeCount = 1,
  int payNoCount = 2,
  int priceTooHighCount = 1,
  int needStrongerProofCount = 1,
  int needRankingCount = 1,
  int ctaTapCount = 2,
}) =>
    PricingOfferValidationSummary(
      totalTesters: totalTesters,
      usefulProofCount: usefulProofCount,
      understoodLongerTrailCount: understoodLongerTrailCount,
      understoodNotMoreAiCount: understoodNotMoreAiCount,
      payYesCount: payYesCount,
      payMaybeCount: payMaybeCount,
      payNoCount: payNoCount,
      priceTooHighCount: priceTooHighCount,
      needStrongerProofCount: needStrongerProofCount,
      needRankingCount: needRankingCount,
      ctaTapCount: ctaTapCount,
    );

PricingOfferValidationSummary _corePassingSummary({
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
  group('PricingOfferValidationV2 thresholds', () {
    test('30 tester exact targets', () {
      expect(PricingOfferValidationV2.usefulProofTargetFor(30), 7);
      expect(PricingOfferValidationV2.understoodLongerTrailTargetFor(30), 6);
      expect(PricingOfferValidationV2.understoodNotMoreAiTargetFor(30), 6);
      expect(PricingOfferValidationV2.payYesMaybeTargetFor(30), 3);
      expect(PricingOfferValidationV2.priceTooHighHighTargetFor(30), 6);
      expect(PricingOfferValidationV2.needStrongerProofHighTargetFor(30), 6);
      expect(PricingOfferValidationV2.needRankingHighTargetFor(30), 6);
      expect(PricingOfferValidationV2.ctaTapTargetFor(30), 1);
    });

    test('20 tester scaled targets', () {
      expect(PricingOfferValidationV2.usefulProofTargetFor(20), 5);
      expect(PricingOfferValidationV2.understoodLongerTrailTargetFor(20), 4);
      expect(PricingOfferValidationV2.understoodNotMoreAiTargetFor(20), 4);
      expect(PricingOfferValidationV2.payYesMaybeTargetFor(20), 2);
      expect(PricingOfferValidationV2.priceTooHighHighTargetFor(20), 4);
      expect(PricingOfferValidationV2.needStrongerProofHighTargetFor(20), 4);
      expect(PricingOfferValidationV2.needRankingHighTargetFor(20), 4);
      expect(PricingOfferValidationV2.ctaTapTargetFor(20), 1);
    });
  });

  group('PricingOfferValidationV2.resolve', () {
    test('under 20 testers returns insufficientData', () {
      expect(
        PricingOfferValidationV2.resolve(_summary(totalTesters: 19)),
        PricingOfferValidationDecision.insufficientData,
      );
    });

    test('weak useful proof returns repairProofFirst', () {
      expect(
        PricingOfferValidationV2.resolve(
          _summary(totalTesters: 30, usefulProofCount: 4),
        ),
        PricingOfferValidationDecision.repairProofFirst,
      );
    });

    test('weak Pro understanding returns repairProUnderstanding', () {
      expect(
        PricingOfferValidationV2.resolve(
          _corePassingSummary().copyWith(
            understoodLongerTrailCount: 3,
            understoodNotMoreAiCount: 6,
          ),
        ),
        PricingOfferValidationDecision.repairProUnderstanding,
      );
      expect(
        PricingOfferValidationV2.resolve(
          _corePassingSummary().copyWith(
            understoodLongerTrailCount: 6,
            understoodNotMoreAiCount: 3,
          ),
        ),
        PricingOfferValidationDecision.repairProUnderstanding,
      );
    });

    test(
      'pay yes/maybe strong and price not rejected returns pricingAcceptedProductionCandidate',
      () {
        expect(
          PricingOfferValidationV2.resolve(
            _corePassingSummary().copyWith(
              payYesCount: 2,
              payMaybeCount: 1,
              priceTooHighCount: 2,
            ),
          ),
          PricingOfferValidationDecision.pricingAcceptedProductionCandidate,
        );
      },
    );

    test(
      'pay yes/maybe strong but price too high returns validatePriceCopy',
      () {
        expect(
          PricingOfferValidationV2.resolve(
            _corePassingSummary().copyWith(
              payYesCount: 2,
              payMaybeCount: 1,
              priceTooHighCount: 6,
            ),
          ),
          PricingOfferValidationDecision.validatePriceCopy,
        );
      },
    );

    test(
      'Pro understood but pay weak and stronger proof requested returns sharpenValueProposition',
      () {
        expect(
          PricingOfferValidationV2.resolve(
            _corePassingSummary().copyWith(
              payYesCount: 0,
              payMaybeCount: 1,
              needStrongerProofCount: 7,
              needRankingCount: 1,
            ),
          ),
          PricingOfferValidationDecision.sharpenValueProposition,
        );
      },
    );

    test(
      'ranking requested but pay yes/maybe passes returns holdRanking',
      () {
        expect(
          PricingOfferValidationV2.resolve(
            _corePassingSummary().copyWith(
              payYesCount: 2,
              payMaybeCount: 1,
              needRankingCount: 7,
              needStrongerProofCount: 1,
            ),
          ),
          PricingOfferValidationDecision.holdRanking,
        );
      },
    );

    test(
      'ranking requested and pay weak only after proof/Pro pass returns investigateRankingOnlyIfPaymentBlocked',
      () {
        expect(
          PricingOfferValidationV2.resolve(
            _corePassingSummary().copyWith(
              payYesCount: 0,
              payMaybeCount: 1,
              needRankingCount: 7,
              needStrongerProofCount: 1,
            ),
          ),
          PricingOfferValidationDecision
              .investigateRankingOnlyIfPaymentBlocked,
        );
      },
    );

    test('conservative fallback returns sharpenValueProposition', () {
      expect(
        PricingOfferValidationV2.resolve(
          _corePassingSummary().copyWith(
            payYesCount: 0,
            payMaybeCount: 1,
            needRankingCount: 1,
            needStrongerProofCount: 1,
          ),
        ),
        PricingOfferValidationDecision.sharpenValueProposition,
      );
    });
  });

  group('PricingOfferValidationV2Copy', () {
    test('copy title asks if longer trail is worth keeping', () {
      expect(
        PricingOfferValidationV2Copy.title,
        'Is the longer trail worth keeping?',
      );
    });

    test('copy says Free shows first useful proof', () {
      expect(
        PricingOfferValidationV2Copy.body,
        contains('Free shows the first useful proof'),
      );
    });

    test('copy says Pro keeps returns/changes/fades/corrections', () {
      final body = PricingOfferValidationV2Copy.body.toLowerCase();
      expect(body, contains('returns'));
      expect(body, contains('changes'));
      expect(body, contains('fades'));
      expect(body, contains('corrected'));
    });

    test('value line says not paying for more AI', () {
      expect(
        PricingOfferValidationV2Copy.valueLine,
        contains('not paying for more AI'),
      );
    });

    test('value line says paying to keep evidence trail over time', () {
      expect(
        PricingOfferValidationV2Copy.valueLine,
        contains('paying to keep the evidence trail over time'),
      );
    });

    test('reason options include stronger proof first', () {
      expect(
        PricingOfferValidationV2Copy.reasonOptions,
        contains('I need stronger proof first'),
      );
    });

    test('reason options include ranking', () {
      expect(
        PricingOfferValidationV2Copy.reasonOptions,
        contains('I would need ranking'),
      );
    });

    test('reason options include price too high', () {
      expect(
        PricingOfferValidationV2Copy.reasonOptions,
        contains('Price feels too high'),
      );
    });

    test(
      'guardrail blocks ranking unless pricing fails specifically because prioritisation is needed',
      () {
        expect(
          PricingOfferValidationV2Copy.guardrail,
          contains('Do not add ranking unless pricing fails specifically'),
        );
        expect(
          PricingOfferValidationV2Copy.guardrail,
          contains('need prioritisation to pay'),
        );
      },
    );

    test('copy does not claim advice ranking therapy diagnosis or coaching', () {
      for (final text in [
        PricingOfferValidationV2Copy.title,
        PricingOfferValidationV2Copy.body,
        PricingOfferValidationV2Copy.valueLine,
        PricingOfferValidationV2Copy.priceQuestion,
        PricingOfferValidationV2Copy.reasonQuestion,
        PricingOfferValidationV2Copy.cta,
        PricingOfferValidationV2Copy.secondary,
      ]) {
        expect(ProofSurfaceAdviceGuard.passes(text), isTrue, reason: text);
        final lower = text.toLowerCase();
        expect(lower.contains('ranking'), isFalse, reason: text);
        expect(lower.contains('advice'), isFalse, reason: text);
        expect(lower.contains('therapy'), isFalse, reason: text);
        expect(lower.contains('diagnosis'), isFalse, reason: text);
        expect(lower.contains('coaching'), isFalse, reason: text);
      }
    });
  });

  group('Protected areas', () {
    test('module does not import billing entitlements or ranking', () {
      for (final path in [
        'lib/features/pricing_offer_validation/pricing_offer_validation_v2.dart',
        'lib/features/pricing_offer_validation/pricing_offer_validation_v2_copy.dart',
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

    test('pricing validation and evidence trail behaviour unchanged', () {
      BetaRepairLabStore.repairModeOverrideForTest = 'pricingValidation';
      expect(
        PricingValidationEngine.shouldShow(
          input: _repairInput(),
          hasProEngagement: true,
        ),
        isFalse,
      );
      expect(
        EvidenceTrailProUnderstanding.resolve(
          const EvidenceTrailProUnderstandingSummary(
            totalTesters: 19,
            usefulProofCount: 10,
            understoodFirstProofCount: 8,
            understoodLongerTrailCount: 8,
            understoodProKeepsChangesCount: 8,
            thoughtProWasMoreAiCount: 1,
            wantedRankingCount: 1,
            paywallCtaTapCount: 2,
            wouldPayYesMaybeCount: 4,
          ),
        ),
        EvidenceTrailProUnderstandingDecision.insufficientData,
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

extension on PricingOfferValidationSummary {
  PricingOfferValidationSummary copyWith({
    int? totalTesters,
    int? usefulProofCount,
    int? understoodLongerTrailCount,
    int? understoodNotMoreAiCount,
    int? payYesCount,
    int? payMaybeCount,
    int? payNoCount,
    int? priceTooHighCount,
    int? needStrongerProofCount,
    int? needRankingCount,
    int? ctaTapCount,
  }) =>
      PricingOfferValidationSummary(
        totalTesters: totalTesters ?? this.totalTesters,
        usefulProofCount: usefulProofCount ?? this.usefulProofCount,
        understoodLongerTrailCount:
            understoodLongerTrailCount ?? this.understoodLongerTrailCount,
        understoodNotMoreAiCount:
            understoodNotMoreAiCount ?? this.understoodNotMoreAiCount,
        payYesCount: payYesCount ?? this.payYesCount,
        payMaybeCount: payMaybeCount ?? this.payMaybeCount,
        payNoCount: payNoCount ?? this.payNoCount,
        priceTooHighCount: priceTooHighCount ?? this.priceTooHighCount,
        needStrongerProofCount:
            needStrongerProofCount ?? this.needStrongerProofCount,
        needRankingCount: needRankingCount ?? this.needRankingCount,
        ctaTapCount: ctaTapCount ?? this.ctaTapCount,
      );
}
