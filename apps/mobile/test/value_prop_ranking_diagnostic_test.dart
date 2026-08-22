import 'dart:io';

import 'package:archiveme_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:archiveme_mobile/features/beta_repair_lab/beta_repair_lab_model.dart';
import 'package:archiveme_mobile/features/beta_repair_lab/beta_repair_lab_store.dart';
import 'package:archiveme_mobile/features/evidence_trail_pro_understanding/evidence_trail_pro_understanding.dart';
import 'package:archiveme_mobile/features/pricing_offer_validation/pricing_offer_validation_v2.dart';
import 'package:archiveme_mobile/features/pricing_validation/pricing_validation_engine.dart';
import 'package:archiveme_mobile/features/proof_confidence_calibration/proof_confidence_calibration_model.dart';
import 'package:archiveme_mobile/features/proof_detail_repair/proof_detail_repair_copy.dart';
import 'package:archiveme_mobile/features/proof_selection/proof_selection_principle.dart';
import 'package:archiveme_mobile/features/surface_priority/surface_priority_engine.dart';
import 'package:archiveme_mobile/features/surface_priority/surface_priority_model.dart';
import 'package:archiveme_mobile/features/value_prop_ranking_diagnostic/value_prop_ranking_diagnostic.dart';
import 'package:archiveme_mobile/features/value_prop_ranking_diagnostic/value_prop_ranking_diagnostic_copy.dart';
import 'package:flutter_test/flutter_test.dart';

ValuePropRankingDiagnosticSummary _summary({
  int totalTesters = 30,
  int usefulProofCount = 10,
  int understoodLongerTrailCount = 8,
  int understoodNotMoreAiCount = 8,
  int payYesCount = 2,
  int payMaybeCount = 1,
  int payNoCount = 2,
  int needStrongerProofCount = 1,
  int needSeeOverTimeCount = 1,
  int needRankingBeforePayingCount = 1,
  int priceTooHighCount = 1,
  int worthPayingCount = 1,
}) => ValuePropRankingDiagnosticSummary(
  totalTesters: totalTesters,
  usefulProofCount: usefulProofCount,
  understoodLongerTrailCount: understoodLongerTrailCount,
  understoodNotMoreAiCount: understoodNotMoreAiCount,
  payYesCount: payYesCount,
  payMaybeCount: payMaybeCount,
  payNoCount: payNoCount,
  needStrongerProofCount: needStrongerProofCount,
  needSeeOverTimeCount: needSeeOverTimeCount,
  needRankingBeforePayingCount: needRankingBeforePayingCount,
  priceTooHighCount: priceTooHighCount,
  worthPayingCount: worthPayingCount,
);

ValuePropRankingDiagnosticSummary _corePassingSummary({
  int totalTesters = 30,
}) => _summary(
  totalTesters: totalTesters,
  usefulProofCount: totalTesters == 20 ? 5 : 7,
  understoodLongerTrailCount: totalTesters == 20 ? 4 : 6,
  understoodNotMoreAiCount: totalTesters == 20 ? 4 : 6,
);

BetaRepairLabVisibilityInput _repairInput() => const BetaRepairLabVisibilityInput(
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
  group('ValuePropRankingDiagnostic thresholds', () {
    test('30 tester exact targets', () {
      expect(ValuePropRankingDiagnostic.usefulProofTargetFor(30), 7);
      expect(ValuePropRankingDiagnostic.understoodLongerTrailTargetFor(30), 6);
      expect(ValuePropRankingDiagnostic.understoodNotMoreAiTargetFor(30), 6);
      expect(ValuePropRankingDiagnostic.payYesMaybeTargetFor(30), 3);
      expect(ValuePropRankingDiagnostic.worthPayingTargetFor(30), 3);
      expect(ValuePropRankingDiagnostic.needStrongerProofHighTargetFor(30), 6);
      expect(ValuePropRankingDiagnostic.needSeeOverTimeHighTargetFor(30), 6);
      expect(
        ValuePropRankingDiagnostic.needRankingBeforePayingHighTargetFor(30),
        6,
      );
      expect(ValuePropRankingDiagnostic.priceTooHighHighTargetFor(30), 6);
    });

    test('20 tester scaled targets', () {
      expect(ValuePropRankingDiagnostic.usefulProofTargetFor(20), 5);
      expect(ValuePropRankingDiagnostic.understoodLongerTrailTargetFor(20), 4);
      expect(ValuePropRankingDiagnostic.understoodNotMoreAiTargetFor(20), 4);
      expect(ValuePropRankingDiagnostic.payYesMaybeTargetFor(20), 2);
      expect(ValuePropRankingDiagnostic.worthPayingTargetFor(20), 2);
      expect(ValuePropRankingDiagnostic.needStrongerProofHighTargetFor(20), 4);
      expect(ValuePropRankingDiagnostic.needSeeOverTimeHighTargetFor(20), 4);
      expect(
        ValuePropRankingDiagnostic.needRankingBeforePayingHighTargetFor(20),
        4,
      );
      expect(ValuePropRankingDiagnostic.priceTooHighHighTargetFor(20), 4);
    });
  });

  group('ValuePropRankingDiagnostic.resolve', () {
    test('under 20 testers returns insufficientData', () {
      expect(
        ValuePropRankingDiagnostic.resolve(_summary(totalTesters: 19)),
        ValuePropRankingDiagnosticDecision.insufficientData,
      );
    });

    test('weak useful proof returns repairProofFirst', () {
      expect(
        ValuePropRankingDiagnostic.resolve(
          _summary(usefulProofCount: 4),
        ),
        ValuePropRankingDiagnosticDecision.repairProofFirst,
      );
    });

    test('weak Pro understanding returns repairProUnderstanding', () {
      expect(
        ValuePropRankingDiagnostic.resolve(
          _corePassingSummary().copyWith(
            understoodLongerTrailCount: 3,
            understoodNotMoreAiCount: 6,
          ),
        ),
        ValuePropRankingDiagnosticDecision.repairProUnderstanding,
      );
    });

    test(
      'need see over time high with some payment intent returns validateLongerTrailValue',
      () {
        expect(
          ValuePropRankingDiagnostic.resolve(
            _corePassingSummary().copyWith(
              payYesCount: 1,
              payMaybeCount: 1,
              needSeeOverTimeCount: 7,
              needStrongerProofCount: 1,
            ),
          ),
          ValuePropRankingDiagnosticDecision.validateLongerTrailValue,
        );
      },
    );

    test(
      'stronger proof high and weak payment returns sharpenValueProposition',
      () {
        expect(
          ValuePropRankingDiagnostic.resolve(
            _corePassingSummary().copyWith(
              payYesCount: 0,
              payMaybeCount: 1,
              needStrongerProofCount: 7,
              needSeeOverTimeCount: 1,
            ),
          ),
          ValuePropRankingDiagnosticDecision.sharpenValueProposition,
        );
      },
    );

    test('price too high high returns validatePriceCopy', () {
      expect(
        ValuePropRankingDiagnostic.resolve(
          _corePassingSummary().copyWith(
            priceTooHighCount: 6,
            needSeeOverTimeCount: 1,
            needStrongerProofCount: 1,
          ),
        ),
        ValuePropRankingDiagnosticDecision.validatePriceCopy,
      );
    });

    test(
      'ranking-before-paying high with proof/Pro understood and weak payment returns investigateRankingNeedOnly',
      () {
        expect(
          ValuePropRankingDiagnostic.resolve(
            _corePassingSummary().copyWith(
              payYesCount: 0,
              payMaybeCount: 1,
              needRankingBeforePayingCount: 7,
              needSeeOverTimeCount: 1,
              needStrongerProofCount: 1,
              priceTooHighCount: 1,
            ),
          ),
          ValuePropRankingDiagnosticDecision.investigateRankingNeedOnly,
        );
      },
    );

    test('pay yes/maybe and worth paying pass returns productionCandidate', () {
      expect(
        ValuePropRankingDiagnostic.resolve(
          _corePassingSummary().copyWith(
            payYesCount: 2,
            payMaybeCount: 1,
            worthPayingCount: 3,
            needSeeOverTimeCount: 1,
            needStrongerProofCount: 1,
            needRankingBeforePayingCount: 1,
            priceTooHighCount: 1,
          ),
        ),
        ValuePropRankingDiagnosticDecision.productionCandidate,
      );
    });

    test('conservative fallback returns sharpenValueProposition', () {
      expect(
        ValuePropRankingDiagnostic.resolve(
          _corePassingSummary().copyWith(
            payYesCount: 0,
            payMaybeCount: 1,
            worthPayingCount: 1,
            needSeeOverTimeCount: 1,
            needStrongerProofCount: 1,
            needRankingBeforePayingCount: 1,
            priceTooHighCount: 1,
          ),
        ),
        ValuePropRankingDiagnosticDecision.sharpenValueProposition,
      );
    });
  });

  group('ValuePropRankingDiagnosticCopy', () {
    test('copy title asks what would make Pro worth it', () {
      expect(
        ValuePropRankingDiagnosticCopy.title,
        'What would make Pro worth it?',
      );
    });

    test('copy says Pro is the longer evidence trail', () {
      expect(
        ValuePropRankingDiagnosticCopy.body,
        contains('Pro is the longer evidence trail'),
      );
    });

    test('copy says returns/changes/fades/corrected over time', () {
      final body = ValuePropRankingDiagnosticCopy.body.toLowerCase();
      expect(body, contains('returning'));
      expect(body, contains('changes'));
      expect(body, contains('fades'));
      expect(body, contains('corrected'));
      expect(body, contains('over time'));
    });

    test(
      'strongerProofLine tells users to keep using free until clearer repeat',
      () {
        expect(
          ValuePropRankingDiagnosticCopy.strongerProofLine,
          contains('keep using free'),
        );
        expect(
          ValuePropRankingDiagnosticCopy.strongerProofLine,
          contains('clearer repeat'),
        );
      },
    );

    test('rankingLine says confirm whether prioritisation would help pay', () {
      expect(
        ValuePropRankingDiagnosticCopy.rankingLine,
        contains('confirm whether prioritisation would help you pay'),
      );
    });

    test('rankingLine says without showing ranked lists yet', () {
      expect(
        ValuePropRankingDiagnosticCopy.rankingLine,
        contains('without showing ranked lists yet'),
      );
    });

    test('valueLine says value is not more AI', () {
      expect(ValuePropRankingDiagnosticCopy.valueLine, contains('not more AI'));
    });

    test('valueLine says same proof changing over time', () {
      expect(
        ValuePropRankingDiagnosticCopy.valueLine,
        contains('same proof keeps changing over time'),
      );
    });

    test('options include stronger proof first', () {
      expect(
        ValuePropRankingDiagnosticCopy.options,
        contains('I need stronger proof first'),
      );
    });

    test('options include see it over time', () {
      expect(
        ValuePropRankingDiagnosticCopy.options,
        contains('I need to see it over time'),
      );
    });

    test('options include ranking before paying', () {
      expect(
        ValuePropRankingDiagnosticCopy.options,
        contains('I need ranking before paying'),
      );
    });

    test('options include price too high', () {
      expect(
        ValuePropRankingDiagnosticCopy.options,
        contains('The price feels too high'),
      );
    });

    test('options include worth paying', () {
      expect(
        ValuePropRankingDiagnosticCopy.options,
        contains('This is worth paying for'),
      );
    });

    test(
      'guardrail blocks ranked lists until longer-trail value validated',
      () {
        expect(
          ValuePropRankingDiagnosticCopy.guardrail,
          contains('Do not build ranked lists'),
        );
        expect(
          ValuePropRankingDiagnosticCopy.guardrail,
          contains('longer-trail value has been validated'),
        );
      },
    );

    test('copy avoids therapy diagnosis coaching and advice claims', () {
      for (final text in [
        ValuePropRankingDiagnosticCopy.title,
        ValuePropRankingDiagnosticCopy.body,
        ValuePropRankingDiagnosticCopy.strongerProofLine,
        ValuePropRankingDiagnosticCopy.valueLine,
        ValuePropRankingDiagnosticCopy.question,
      ]) {
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
        'lib/features/value_prop_ranking_diagnostic/value_prop_ranking_diagnostic.dart',
        'lib/features/value_prop_ranking_diagnostic/value_prop_ranking_diagnostic_copy.dart',
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

    test('pricing offer validation and evidence trail behaviour unchanged', () {
      BetaRepairLabStore.repairModeOverrideForTest = 'pricingValidation';
      expect(
        PricingValidationEngine.shouldShow(
          input: _repairInput(),
          hasProEngagement: true,
        ),
        isFalse,
      );
      expect(
        PricingOfferValidationV2.resolve(
          const PricingOfferValidationSummary(
            totalTesters: 19,
            usefulProofCount: 10,
            understoodLongerTrailCount: 8,
            understoodNotMoreAiCount: 8,
            payYesCount: 2,
            payMaybeCount: 1,
            payNoCount: 1,
            priceTooHighCount: 1,
            needStrongerProofCount: 1,
            needRankingCount: 1,
            ctaTapCount: 1,
          ),
        ),
        PricingOfferValidationDecision.insufficientData,
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

    test(
      'record screen remains capture-first without stacking extra cards',
      () {
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
      },
    );
  });
}

extension on ValuePropRankingDiagnosticSummary {
  ValuePropRankingDiagnosticSummary copyWith({
    int? totalTesters,
    int? usefulProofCount,
    int? understoodLongerTrailCount,
    int? understoodNotMoreAiCount,
    int? payYesCount,
    int? payMaybeCount,
    int? payNoCount,
    int? needStrongerProofCount,
    int? needSeeOverTimeCount,
    int? needRankingBeforePayingCount,
    int? priceTooHighCount,
    int? worthPayingCount,
  }) => ValuePropRankingDiagnosticSummary(
    totalTesters: totalTesters ?? this.totalTesters,
    usefulProofCount: usefulProofCount ?? this.usefulProofCount,
    understoodLongerTrailCount:
        understoodLongerTrailCount ?? this.understoodLongerTrailCount,
    understoodNotMoreAiCount:
        understoodNotMoreAiCount ?? this.understoodNotMoreAiCount,
    payYesCount: payYesCount ?? this.payYesCount,
    payMaybeCount: payMaybeCount ?? this.payMaybeCount,
    payNoCount: payNoCount ?? this.payNoCount,
    needStrongerProofCount:
        needStrongerProofCount ?? this.needStrongerProofCount,
    needSeeOverTimeCount: needSeeOverTimeCount ?? this.needSeeOverTimeCount,
    needRankingBeforePayingCount:
        needRankingBeforePayingCount ?? this.needRankingBeforePayingCount,
    priceTooHighCount: priceTooHighCount ?? this.priceTooHighCount,
    worthPayingCount: worthPayingCount ?? this.worthPayingCount,
  );
}