import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/beta_repair_lab/beta_repair_lab_model.dart';
import 'package:voicememory_mobile/features/beta_repair_lab/beta_repair_lab_store.dart';
import 'package:voicememory_mobile/features/change_trail_clarity/change_trail_clarity.dart';
import 'package:voicememory_mobile/features/core_archive_journey/core_archive_journey.dart';
import 'package:voicememory_mobile/features/evidence_trail_pro_understanding/evidence_trail_pro_understanding.dart';
import 'package:voicememory_mobile/features/low_effort_archive_capture/low_effort_archive_capture.dart';
import 'package:voicememory_mobile/features/low_effort_archive_capture/low_effort_archive_capture_copy.dart';
import 'package:voicememory_mobile/features/payment_blocker_matrix/payment_blocker_decision_matrix.dart';
import 'package:voicememory_mobile/features/pricing_offer_validation/pricing_offer_validation_v2.dart';
import 'package:voicememory_mobile/features/pricing_validation/pricing_validation_engine.dart';
import 'package:voicememory_mobile/features/proof_confidence_calibration/proof_confidence_calibration_model.dart';
import 'package:voicememory_mobile/features/proof_detail_repair/proof_detail_repair_copy.dart';
import 'package:voicememory_mobile/features/proof_selection/proof_selection_principle.dart';
import 'package:voicememory_mobile/features/release_candidate_comprehension/release_candidate_comprehension.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_engine.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_model.dart';
import 'package:voicememory_mobile/features/value_prop_ranking_diagnostic/value_prop_ranking_diagnostic.dart';

LowEffortArchiveCaptureSummary _summary({
  int totalTesters = 30,
  int understoodNoDailyRequirementCount = 8,
  int understoodOneSentenceEnoughCount = 8,
  int understoodNoMindMapMaintenanceCount = 8,
  int understoodSaveWhenRealRepeatCount = 8,
  int thoughtDailyHomeworkCount = 1,
  int thoughtManualMindMapMaintenanceCount = 1,
  int preferredChatGptBecauseLessWorkCount = 1,
  int wouldPayYesCount = 2,
  int wouldPayMaybeCount = 1,
  int wouldPayNoCount = 2,
}) => LowEffortArchiveCaptureSummary(
  totalTesters: totalTesters,
  understoodNoDailyRequirementCount: understoodNoDailyRequirementCount,
  understoodOneSentenceEnoughCount: understoodOneSentenceEnoughCount,
  understoodNoMindMapMaintenanceCount: understoodNoMindMapMaintenanceCount,
  understoodSaveWhenRealRepeatCount: understoodSaveWhenRealRepeatCount,
  thoughtDailyHomeworkCount: thoughtDailyHomeworkCount,
  thoughtManualMindMapMaintenanceCount: thoughtManualMindMapMaintenanceCount,
  preferredChatGptBecauseLessWorkCount: preferredChatGptBecauseLessWorkCount,
  wouldPayYesCount: wouldPayYesCount,
  wouldPayMaybeCount: wouldPayMaybeCount,
  wouldPayNoCount: wouldPayNoCount,
);

LowEffortArchiveCaptureSummary _fullComprehensionSummary({
  int totalTesters = 30,
}) => _summary(
  totalTesters: totalTesters,
  understoodNoDailyRequirementCount: totalTesters == 20 ? 5 : 7,
  understoodOneSentenceEnoughCount: totalTesters == 20 ? 5 : 7,
  understoodNoMindMapMaintenanceCount: totalTesters == 20 ? 5 : 7,
  understoodSaveWhenRealRepeatCount: totalTesters == 20 ? 5 : 7,
  thoughtDailyHomeworkCount: 0,
  thoughtManualMindMapMaintenanceCount: 0,
  preferredChatGptBecauseLessWorkCount: 0,
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
  group('LowEffortArchiveCapture.resolve', () {
    test('under 20 testers returns insufficientData', () {
      expect(
        LowEffortArchiveCapture.resolve(_summary(totalTesters: 19)),
        LowEffortArchiveCaptureDecision.insufficientData,
      );
    });

    test('daily homework confusion high returns clarifyNoDailyRequirement', () {
      expect(
        LowEffortArchiveCapture.resolve(
          _fullComprehensionSummary().copyWith(thoughtDailyHomeworkCount: 5),
        ),
        LowEffortArchiveCaptureDecision.clarifyNoDailyRequirement,
      );
    });

    test(
      'no-daily-requirement understanding low returns clarifyNoDailyRequirement',
      () {
        expect(
          LowEffortArchiveCapture.resolve(
            _fullComprehensionSummary().copyWith(
              understoodNoDailyRequirementCount: 4,
            ),
          ),
          LowEffortArchiveCaptureDecision.clarifyNoDailyRequirement,
        );
      },
    );

    test('one sentence understanding low returns clarifyOneSentenceEnough', () {
      expect(
        LowEffortArchiveCapture.resolve(
          _fullComprehensionSummary().copyWith(
            understoodOneSentenceEnoughCount: 4,
          ),
        ),
        LowEffortArchiveCaptureDecision.clarifyOneSentenceEnough,
      );
    });

    test(
      'mind-map maintenance confusion high returns clarifyNoMindMapMaintenance',
      () {
        expect(
          LowEffortArchiveCapture.resolve(
            _fullComprehensionSummary().copyWith(
              thoughtManualMindMapMaintenanceCount: 5,
            ),
          ),
          LowEffortArchiveCaptureDecision.clarifyNoMindMapMaintenance,
        );
      },
    );

    test(
      'no-maintenance understanding low returns clarifyNoMindMapMaintenance',
      () {
        expect(
          LowEffortArchiveCapture.resolve(
            _fullComprehensionSummary().copyWith(
              understoodNoMindMapMaintenanceCount: 4,
            ),
          ),
          LowEffortArchiveCaptureDecision.clarifyNoMindMapMaintenance,
        );
      },
    );

    test('when-to-use understanding low returns clarifyWhenToUse', () {
      expect(
        LowEffortArchiveCapture.resolve(
          _fullComprehensionSummary().copyWith(
            understoodSaveWhenRealRepeatCount: 4,
          ),
        ),
        LowEffortArchiveCaptureDecision.clarifyWhenToUse,
      );
    });

    test(
      'ChatGPT less-work concern high returns reduceChatGptLessWorkConcern',
      () {
        expect(
          LowEffortArchiveCapture.resolve(
            _fullComprehensionSummary().copyWith(
              preferredChatGptBecauseLessWorkCount: 5,
            ),
          ),
          LowEffortArchiveCaptureDecision.reduceChatGptLessWorkConcern,
        );
      },
    );

    test(
      'all comprehension passes but payment weak returns pricingValidation',
      () {
        expect(
          LowEffortArchiveCapture.resolve(
            _fullComprehensionSummary().copyWith(
              wouldPayYesCount: 0,
              wouldPayMaybeCount: 1,
            ),
          ),
          LowEffortArchiveCaptureDecision.pricingValidation,
        );
      },
    );

    test('all comprehension and payment pass returns releaseCandidate', () {
      expect(
        LowEffortArchiveCapture.resolve(_fullComprehensionSummary()),
        LowEffortArchiveCaptureDecision.releaseCandidate,
      );
    });
  });

  group('LowEffortArchiveCaptureCopy', () {
    test('headline says No daily homework', () {
      expect(LowEffortArchiveCaptureCopy.headline, 'No daily homework');
    });

    test('body says does not need constant chatting', () {
      expect(
        LowEffortArchiveCaptureCopy.body,
        contains('does not need constant chatting'),
      );
    });

    test('body says does not need daily journaling', () {
      expect(
        LowEffortArchiveCaptureCopy.body,
        contains('does not need constant chatting or daily journaling'),
      );
    });

    test('body says save one real moment when something repeats', () {
      expect(
        LowEffortArchiveCaptureCopy.body,
        contains('Save one real moment when something repeats'),
      );
    });

    test('body says archive compares it later', () {
      expect(
        LowEffortArchiveCaptureCopy.body,
        contains('The archive compares it later'),
      );
    });

    test('oneSentenceLine says one sentence is enough', () {
      expect(
        LowEffortArchiveCaptureCopy.oneSentenceLine,
        'One sentence is enough.',
      );
    });

    test('noMaintenanceLine says user does not maintain the mind map', () {
      expect(
        LowEffortArchiveCaptureCopy.noMaintenanceLine,
        contains('You do not maintain the mind map'),
      );
    });

    test(
      'noMaintenanceLine says ArchiveMe builds the trail from saved moments',
      () {
        expect(
          LowEffortArchiveCaptureCopy.noMaintenanceLine,
          contains('ArchiveMe builds the trail from saved moments'),
        );
      },
    );

    test('whenToUseLine gives real repeat examples', () {
      final line = LowEffortArchiveCaptureCopy.whenToUseLine.toLowerCase();
      expect(line, contains('thought'));
      expect(line, contains('pressure'));
      expect(line, contains('avoidance'));
      expect(line, contains('checking'));
      expect(line, contains('reaction'));
    });

    test(
      'chatDifferenceLine distinguishes ChatGPT now vs ArchiveMe proof over time',
      () {
        expect(
          LowEffortArchiveCaptureCopy.chatDifferenceLine,
          contains('ChatGPT helps with the conversation you are having now'),
        );
        expect(
          LowEffortArchiveCaptureCopy.chatDifferenceLine,
          contains('ArchiveMe keeps proof of what keeps coming back'),
        );
      },
    );

    test('proLine says Pro keeps longer trail', () {
      expect(
        LowEffortArchiveCaptureCopy.proLine,
        contains('Pro keeps the longer trail'),
      );
    });

    test('proLine keeps habit small', () {
      expect(
        LowEffortArchiveCaptureCopy.proLine,
        contains('save small moments when they matter'),
      );
    });

    test('guardrail blocks daily task/streak/homework/manual maintenance', () {
      expect(LowEffortArchiveCaptureCopy.guardrail, contains('daily task'));
      expect(LowEffortArchiveCaptureCopy.guardrail, contains('streak'));
      expect(LowEffortArchiveCaptureCopy.guardrail, contains('homework'));
      expect(
        LowEffortArchiveCaptureCopy.guardrail,
        contains('manual mind-map maintenance'),
      );
    });

    test('copy does not position ArchiveMe as voice chat', () {
      for (final text in [
        LowEffortArchiveCaptureCopy.headline,
        LowEffortArchiveCaptureCopy.oneSentenceLine,
        LowEffortArchiveCaptureCopy.noMaintenanceLine,
        LowEffortArchiveCaptureCopy.whenToUseLine,
        LowEffortArchiveCaptureCopy.proLine,
      ]) {
        final lower = text.toLowerCase();
        expect(lower.contains('voice chat'), isFalse, reason: text);
        expect(lower.contains('voice assistant'), isFalse, reason: text);
      }
    });

    test('copy does not say better than ChatGPT', () {
      for (final text in [
        LowEffortArchiveCaptureCopy.headline,
        LowEffortArchiveCaptureCopy.body,
        LowEffortArchiveCaptureCopy.oneSentenceLine,
        LowEffortArchiveCaptureCopy.noMaintenanceLine,
        LowEffortArchiveCaptureCopy.whenToUseLine,
        LowEffortArchiveCaptureCopy.proLine,
      ]) {
        final lower = text.toLowerCase();
        expect(lower.contains('better than chatgpt'), isFalse, reason: text);
        expect(lower.contains('better chatgpt'), isFalse, reason: text);
      }
    });

    test('copy does not introduce ranking or importance scoring', () {
      for (final text in [
        LowEffortArchiveCaptureCopy.headline,
        LowEffortArchiveCaptureCopy.body,
        LowEffortArchiveCaptureCopy.oneSentenceLine,
        LowEffortArchiveCaptureCopy.noMaintenanceLine,
        LowEffortArchiveCaptureCopy.whenToUseLine,
        LowEffortArchiveCaptureCopy.chatDifferenceLine,
        LowEffortArchiveCaptureCopy.proLine,
      ]) {
        final lower = text.toLowerCase();
        expect(lower.contains('ranking'), isFalse, reason: text);
        expect(lower.contains('importance score'), isFalse, reason: text);
      }
    });

    test('copy avoids therapy diagnosis coaching and advice claims', () {
      for (final text in [
        LowEffortArchiveCaptureCopy.headline,
        LowEffortArchiveCaptureCopy.body,
        LowEffortArchiveCaptureCopy.oneSentenceLine,
        LowEffortArchiveCaptureCopy.noMaintenanceLine,
        LowEffortArchiveCaptureCopy.whenToUseLine,
        LowEffortArchiveCaptureCopy.chatDifferenceLine,
        LowEffortArchiveCaptureCopy.proLine,
      ]) {
        expect(ProofSurfaceAdviceGuard.passes(text), isTrue, reason: text);
        final lower = text.toLowerCase();
        expect(lower.contains('advice'), isFalse, reason: text);
        expect(lower.contains('coaching'), isFalse, reason: text);
        expect(lower.contains('therapy'), isFalse, reason: text);
        expect(lower.contains('diagnosis'), isFalse, reason: text);
      }
    });
  });

  group('Protected areas', () {
    test('module does not import billing entitlements or ranking UI', () {
      for (final path in [
        'lib/features/low_effort_archive_capture/low_effort_archive_capture.dart',
        'lib/features/low_effort_archive_capture/low_effort_archive_capture_copy.dart',
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
      expect(
        ChangeTrailClarity.resolve(_fullTrailSummary()),
        ChangeTrailClarityDecision.releaseCandidate,
      );
      expect(
        ReleaseCandidateComprehension.resolve(_fullReleaseComprehension()),
        ReleaseCandidateComprehensionDecision.releaseCandidate,
      );
      expect(
        CoreArchiveJourneyGuardrail.allowsVoiceAssistantPositioning(),
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

ChangeTrailClaritySummary _fullTrailSummary() =>
    const ChangeTrailClaritySummary(
      totalTesters: 30,
      understoodFirstProofCount: 7,
      understoodProKeepsTrailCount: 6,
      understoodReturnsCount: 6,
      understoodChangesCount: 6,
      understoodFadesCount: 6,
      understoodCorrectionsCount: 6,
      thoughtMoreAiCount: 0,
      wantedMoreProofCount: 0,
      wantedRankingCount: 0,
      wouldPayYesCount: 2,
      wouldPayMaybeCount: 1,
      wouldPayNoCount: 1,
    );

ReleaseCandidateComprehensionSummary _fullReleaseComprehension() =>
    const ReleaseCandidateComprehensionSummary(
      totalTesters: 30,
      understoodNotVoiceChatCount: 7,
      understoodFirstProofCount: 7,
      understoodWhyAppearedCount: 7,
      understoodConfirmCorrectCount: 7,
      understoodProKeepsTrailCount: 6,
      understoodReturnsChangesFadesCorrectionsCount: 6,
      thoughtItWasVoiceChatCount: 0,
      thoughtItWasMoreAiCount: 0,
      wouldPayYesCount: 2,
      wouldPayMaybeCount: 1,
      wouldPayNoCount: 1,
    );

extension on LowEffortArchiveCaptureSummary {
  LowEffortArchiveCaptureSummary copyWith({
    int? totalTesters,
    int? understoodNoDailyRequirementCount,
    int? understoodOneSentenceEnoughCount,
    int? understoodNoMindMapMaintenanceCount,
    int? understoodSaveWhenRealRepeatCount,
    int? thoughtDailyHomeworkCount,
    int? thoughtManualMindMapMaintenanceCount,
    int? preferredChatGptBecauseLessWorkCount,
    int? wouldPayYesCount,
    int? wouldPayMaybeCount,
    int? wouldPayNoCount,
  }) => LowEffortArchiveCaptureSummary(
    totalTesters: totalTesters ?? this.totalTesters,
    understoodNoDailyRequirementCount:
        understoodNoDailyRequirementCount ??
        this.understoodNoDailyRequirementCount,
    understoodOneSentenceEnoughCount:
        understoodOneSentenceEnoughCount ??
        this.understoodOneSentenceEnoughCount,
    understoodNoMindMapMaintenanceCount:
        understoodNoMindMapMaintenanceCount ??
        this.understoodNoMindMapMaintenanceCount,
    understoodSaveWhenRealRepeatCount:
        understoodSaveWhenRealRepeatCount ??
        this.understoodSaveWhenRealRepeatCount,
    thoughtDailyHomeworkCount:
        thoughtDailyHomeworkCount ?? this.thoughtDailyHomeworkCount,
    thoughtManualMindMapMaintenanceCount:
        thoughtManualMindMapMaintenanceCount ??
        this.thoughtManualMindMapMaintenanceCount,
    preferredChatGptBecauseLessWorkCount:
        preferredChatGptBecauseLessWorkCount ??
        this.preferredChatGptBecauseLessWorkCount,
    wouldPayYesCount: wouldPayYesCount ?? this.wouldPayYesCount,
    wouldPayMaybeCount: wouldPayMaybeCount ?? this.wouldPayMaybeCount,
    wouldPayNoCount: wouldPayNoCount ?? this.wouldPayNoCount,
  );
}
