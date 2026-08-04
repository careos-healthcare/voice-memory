import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/beta_repair_lab/beta_repair_lab_model.dart';
import 'package:voicememory_mobile/features/beta_repair_lab/beta_repair_lab_store.dart';
import 'package:voicememory_mobile/features/core_archive_journey/core_archive_journey.dart';
import 'package:voicememory_mobile/features/core_archive_journey/core_archive_journey_copy.dart';
import 'package:voicememory_mobile/features/evidence_trail_pro_understanding/evidence_trail_pro_understanding.dart';
import 'package:voicememory_mobile/features/payment_blocker_matrix/payment_blocker_decision_matrix.dart';
import 'package:voicememory_mobile/features/pricing_offer_validation/pricing_offer_validation_v2.dart';
import 'package:voicememory_mobile/features/pricing_validation/pricing_validation_engine.dart';
import 'package:voicememory_mobile/features/proof_confidence_calibration/proof_confidence_calibration_model.dart';
import 'package:voicememory_mobile/features/proof_detail_repair/proof_detail_repair_copy.dart';
import 'package:voicememory_mobile/features/proof_selection/proof_selection_principle.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_engine.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_model.dart';
import 'package:voicememory_mobile/features/value_prop_ranking_diagnostic/value_prop_ranking_diagnostic.dart';

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
  group('CoreArchiveJourney steps', () {
    test('journey includes first proof', () {
      expect(
        CoreArchiveJourney.steps,
        contains(CoreArchiveJourneyStep.firstProof),
      );
    });

    test('journey includes why this proof appeared', () {
      expect(
        CoreArchiveJourney.steps,
        contains(CoreArchiveJourneyStep.whyThisProofAppeared),
      );
    });

    test('journey includes confirm or correct', () {
      expect(
        CoreArchiveJourney.steps,
        contains(CoreArchiveJourneyStep.confirmOrCorrect),
      );
    });

    test('journey includes longer evidence trail', () {
      expect(
        CoreArchiveJourney.steps,
        contains(CoreArchiveJourneyStep.longerEvidenceTrail),
      );
    });

    test('journey includes returns/changes/fades/corrected', () {
      expect(
        CoreArchiveJourney.steps,
        contains(CoreArchiveJourneyStep.returnsChangesFadesCorrected),
      );
    });

    test('journey includes Pro keeps the trail', () {
      expect(
        CoreArchiveJourney.steps,
        contains(CoreArchiveJourneyStep.proKeepsTheTrail),
      );
    });
  });

  group('CoreArchiveJourneyCopy', () {
    test('headline says ArchiveMe shows what keeps repeating', () {
      expect(
        CoreArchiveJourneyCopy.headline,
        'ArchiveMe shows what keeps repeating',
      );
    });

    test('subheadline says not a better voice assistant', () {
      expect(
        CoreArchiveJourneyCopy.subheadline,
        contains('Not a better voice assistant'),
      );
    });

    test('subheadline says private archive', () {
      expect(CoreArchiveJourneyCopy.subheadline, contains('private archive'));
    });

    test('subheadline says returns/changes/fades/corrected over time', () {
      final subheadline = CoreArchiveJourneyCopy.subheadline.toLowerCase();
      expect(subheadline, contains('returns'));
      expect(subheadline, contains('changes'));
      expect(subheadline, contains('fades'));
      expect(subheadline, contains('corrected'));
      expect(subheadline, contains('over time'));
    });

    test('first proof copy says one clear repeat', () {
      expect(CoreArchiveJourneyCopy.firstProof, contains('one clear repeat'));
    });

    test('why proof copy says clearest specific repeat', () {
      expect(
        CoreArchiveJourneyCopy.whyThisProofAppeared,
        contains('clearest specific repeat'),
      );
    });

    test('why proof copy says not necessarily most important thing', () {
      expect(
        CoreArchiveJourneyCopy.whyThisProofAppeared,
        contains('not necessarily the most important thing'),
      );
    });

    test('confirm/correct copy includes accurate, too vague, not relevant', () {
      expect(CoreArchiveJourneyCopy.confirmOrCorrect, contains('accurate'));
      expect(CoreArchiveJourneyCopy.confirmOrCorrect, contains('too vague'));
      expect(CoreArchiveJourneyCopy.confirmOrCorrect, contains('not relevant'));
    });

    test('longer trail copy says returns over time', () {
      expect(
        CoreArchiveJourneyCopy.longerEvidenceTrail,
        contains('returns over time'),
      );
    });

    test('Pro copy says Free shows first useful proof', () {
      expect(
        CoreArchiveJourneyCopy.proKeepsTheTrail,
        contains('Free shows the first useful proof'),
      );
    });

    test('Pro copy says Pro keeps longer evidence trail', () {
      expect(
        CoreArchiveJourneyCopy.proKeepsTheTrail,
        contains('Pro keeps the longer evidence trail'),
      );
    });

    test('antiVoiceAssistantGuardrail says not better ChatGPT Voice', () {
      expect(
        CoreArchiveJourneyCopy.antiVoiceAssistantGuardrail,
        contains('must not be positioned as a better ChatGPT Voice'),
      );
    });

    test(
      'antiVoiceAssistantGuardrail blocks voice chat/transcription/general assistant positioning',
      () {
        expect(
          CoreArchiveJourneyCopy.antiVoiceAssistantGuardrail,
          contains('not voice chat'),
        );
        expect(
          CoreArchiveJourneyCopy.antiVoiceAssistantGuardrail,
          contains('transcription'),
        );
        expect(
          CoreArchiveJourneyCopy.antiVoiceAssistantGuardrail,
          contains('general assistant'),
        );
      },
    );

    test('positioningLine is exactly ChatGPT answers today line', () {
      expect(
        CoreArchiveJourneyCopy.positioningLine,
        'ChatGPT answers today. ArchiveMe shows what keeps repeating across your life.',
      );
    });

    test(
      'proofOfChangeLine says remembers repeats and proves change over time',
      () {
        expect(
          CoreArchiveJourneyCopy.proofOfChangeLine,
          contains('remembers repeats'),
        );
        expect(
          CoreArchiveJourneyCopy.proofOfChangeLine,
          contains('proves change over time'),
        );
      },
    );

    test('doNotBuildList includes better voice chat', () {
      expect(
        CoreArchiveJourneyCopy.doNotBuildList,
        contains('Better voice chat'),
      );
    });

    test('doNotBuildList includes generic transcription', () {
      expect(
        CoreArchiveJourneyCopy.doNotBuildList,
        contains('Generic transcription'),
      );
    });

    test('doNotBuildList includes AI companion', () {
      expect(CoreArchiveJourneyCopy.doNotBuildList, contains('AI companion'));
    });

    test('doNotBuildList includes ranked advice', () {
      expect(CoreArchiveJourneyCopy.doNotBuildList, contains('Ranked advice'));
    });

    test('doNotBuildList includes therapy or diagnosis', () {
      expect(
        CoreArchiveJourneyCopy.doNotBuildList,
        contains('Therapy or diagnosis'),
      );
    });

    test('copy does not claim ArchiveMe is better than ChatGPT Voice', () {
      for (final text in [
        CoreArchiveJourneyCopy.headline,
        CoreArchiveJourneyCopy.subheadline,
        CoreArchiveJourneyCopy.positioningLine,
        CoreArchiveJourneyCopy.proofOfChangeLine,
        CoreArchiveJourneyCopy.firstProof,
        CoreArchiveJourneyCopy.whyThisProofAppeared,
        CoreArchiveJourneyCopy.confirmOrCorrect,
        CoreArchiveJourneyCopy.longerEvidenceTrail,
        CoreArchiveJourneyCopy.returnsChangesFadesCorrected,
        CoreArchiveJourneyCopy.proKeepsTheTrail,
      ]) {
        expect(
          text.toLowerCase().contains('better than chatgpt'),
          isFalse,
          reason: text,
        );
        expect(
          text.toLowerCase().contains('better chatgpt voice'),
          isFalse,
          reason: text,
        );
      }
    });

    test('copy does not promise advice coaching therapy or diagnosis', () {
      for (final text in [
        CoreArchiveJourneyCopy.headline,
        CoreArchiveJourneyCopy.subheadline,
        CoreArchiveJourneyCopy.positioningLine,
        CoreArchiveJourneyCopy.proofOfChangeLine,
        CoreArchiveJourneyCopy.firstProof,
        CoreArchiveJourneyCopy.whyThisProofAppeared,
        CoreArchiveJourneyCopy.confirmOrCorrect,
        CoreArchiveJourneyCopy.longerEvidenceTrail,
        CoreArchiveJourneyCopy.returnsChangesFadesCorrected,
        CoreArchiveJourneyCopy.proKeepsTheTrail,
      ]) {
        expect(ProofSurfaceAdviceGuard.passes(text), isTrue, reason: text);
        final lower = text.toLowerCase();
        expect(lower.contains('advice'), isFalse, reason: text);
        expect(lower.contains('coaching'), isFalse, reason: text);
        expect(lower.contains('therapy'), isFalse, reason: text);
        expect(lower.contains('diagnosis'), isFalse, reason: text);
      }
    });

    test('copy does not introduce ranking or importance scoring', () {
      for (final text in [
        CoreArchiveJourneyCopy.headline,
        CoreArchiveJourneyCopy.subheadline,
        CoreArchiveJourneyCopy.positioningLine,
        CoreArchiveJourneyCopy.proofOfChangeLine,
        CoreArchiveJourneyCopy.firstProof,
        CoreArchiveJourneyCopy.whyThisProofAppeared,
        CoreArchiveJourneyCopy.confirmOrCorrect,
        CoreArchiveJourneyCopy.longerEvidenceTrail,
        CoreArchiveJourneyCopy.returnsChangesFadesCorrected,
        CoreArchiveJourneyCopy.proKeepsTheTrail,
      ]) {
        final lower = text.toLowerCase();
        expect(lower.contains('ranking'), isFalse, reason: text);
        expect(lower.contains('importance score'), isFalse, reason: text);
      }
    });
  });

  group('CoreArchiveJourneyGuardrail', () {
    test('guardrail disallows voice assistant positioning', () {
      expect(
        CoreArchiveJourneyGuardrail.allowsVoiceAssistantPositioning(),
        isFalse,
      );
    });

    test('guardrail disallows generic transcription positioning', () {
      expect(
        CoreArchiveJourneyGuardrail.allowsGenericTranscriptionPositioning(),
        isFalse,
      );
    });

    test('guardrail disallows ranking dashboard positioning', () {
      expect(
        CoreArchiveJourneyGuardrail.allowsRankingDashboardPositioning(),
        isFalse,
      );
    });

    test('guardrail disallows therapy/diagnosis positioning', () {
      expect(
        CoreArchiveJourneyGuardrail.allowsTherapyDiagnosisPositioning(),
        isFalse,
      );
    });

    test('guardrail allows evidence trail positioning', () {
      expect(
        CoreArchiveJourneyGuardrail.allowsEvidenceTrailPositioning(),
        isTrue,
      );
    });

    test('guardrail allows repeat/change positioning', () {
      expect(
        CoreArchiveJourneyGuardrail.allowsRepeatAndChangePositioning(),
        isTrue,
      );
    });
  });

  group('Protected areas', () {
    test('module does not import billing entitlements or ranking UI', () {
      for (final path in [
        'lib/features/core_archive_journey/core_archive_journey.dart',
        'lib/features/core_archive_journey/core_archive_journey_copy.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source.contains('RevenueCat'), isFalse);
        expect(source.contains('restorePurchases'), isFalse);
        expect(source.contains('billing/'), isFalse);
        expect(source.contains('importance_scoring'), isFalse);
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
        PaymentBlockerDecisionMatrix.resolve(
          const PaymentBlockerSummary(
            totalTesters: 30,
            usefulProofCount: 7,
            understoodLongerTrailCount: 6,
            understoodNotMoreAiCount: 6,
            payYesCount: 2,
            payMaybeCount: 1,
            payNoCount: 1,
            needSeeOverTimeCount: 1,
            needStrongerProofCount: 1,
            needRankingBeforePayingCount: 1,
            priceTooHighCount: 1,
            worthPayingCount: 3,
          ),
        ),
        PaymentBlockerDecision.productionCandidate,
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
