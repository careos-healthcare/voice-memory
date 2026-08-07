import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_prompt_assist/archive_prompt_assist.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/change_trail_clarity/change_trail_clarity.dart';
import 'package:voicememory_mobile/features/context_trail_clarity/context_trail_clarity.dart';
import 'package:voicememory_mobile/features/core_archive_journey/core_archive_journey.dart';
import 'package:voicememory_mobile/features/low_effort_archive_capture/low_effort_archive_capture.dart';
import 'package:voicememory_mobile/features/positive_archive_reinforcement/positive_archive_reinforcement.dart';
import 'package:voicememory_mobile/features/preserved_proof_value/preserved_proof_value.dart';
import 'package:voicememory_mobile/features/preserved_proof_value/preserved_proof_value_copy.dart';
import 'package:voicememory_mobile/features/proof_detail_repair/proof_detail_repair_copy.dart';
import 'package:voicememory_mobile/features/proof_selection/proof_selection_principle.dart';
import 'package:voicememory_mobile/features/proof_trail_positioning/proof_trail_positioning.dart';
import 'package:voicememory_mobile/features/release_candidate_comprehension/release_candidate_comprehension.dart';
import 'package:voicememory_mobile/features/save_a_repeat_habit/save_a_repeat_habit.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_engine.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_model.dart';

PreservedProofValueInput _input({
  bool userUnderstandsFirstProof = true,
  bool userUnderstandsProKeepsTrail = true,
  bool userUnderstandsPreservedProof = true,
  bool userUnderstandsWhatWouldBeLost = true,
  bool userThinksProMeansMoreAi = false,
  bool userThinksProMeansStorage = false,
  bool userThinksPaymentFeelsOptional = true,
  bool userFeelsPressureOrManipulation = false,
  bool wouldPayYes = true,
  bool wouldPayMaybe = false,
}) => PreservedProofValueInput(
  userUnderstandsFirstProof: userUnderstandsFirstProof,
  userUnderstandsProKeepsTrail: userUnderstandsProKeepsTrail,
  userUnderstandsPreservedProof: userUnderstandsPreservedProof,
  userUnderstandsWhatWouldBeLost: userUnderstandsWhatWouldBeLost,
  userThinksProMeansMoreAi: userThinksProMeansMoreAi,
  userThinksProMeansStorage: userThinksProMeansStorage,
  userThinksPaymentFeelsOptional: userThinksPaymentFeelsOptional,
  userFeelsPressureOrManipulation: userFeelsPressureOrManipulation,
  wouldPayYes: wouldPayYes,
  wouldPayMaybe: wouldPayMaybe,
);

void main() {
  group('PreservedProofValue.resolve', () {
    test('weak first proof understanding -> clarifyFirstProof', () {
      expect(
        PreservedProofValue.resolve(
          _input(userUnderstandsFirstProof: false),
        ).decision,
        PreservedProofValueDecision.clarifyFirstProof,
      );
    });

    test('weak Pro trail understanding -> clarifyProKeepsTrail', () {
      expect(
        PreservedProofValue.resolve(
          _input(userUnderstandsProKeepsTrail: false),
        ).decision,
        PreservedProofValueDecision.clarifyProKeepsTrail,
      );
    });

    test('more-AI confusion -> removeMoreAiConfusion', () {
      expect(
        PreservedProofValue.resolve(
          _input(userThinksProMeansMoreAi: true),
        ).decision,
        PreservedProofValueDecision.removeMoreAiConfusion,
      );
    });

    test('storage confusion -> removeStorageConfusion', () {
      expect(
        PreservedProofValue.resolve(
          _input(userThinksProMeansStorage: true),
        ).decision,
        PreservedProofValueDecision.removeStorageConfusion,
      );
    });

    test('pressure/manipulation feeling -> reducePressure', () {
      expect(
        PreservedProofValue.resolve(
          _input(userFeelsPressureOrManipulation: true),
        ).decision,
        PreservedProofValueDecision.reducePressure,
      );
    });

    test('weak preserved-proof understanding -> clarifyPreservedProof', () {
      expect(
        PreservedProofValue.resolve(
          _input(userUnderstandsPreservedProof: false),
        ).decision,
        PreservedProofValueDecision.clarifyPreservedProof,
      );
    });

    test('weak what-would-be-lost understanding -> clarifyWhatWouldBeLost', () {
      expect(
        PreservedProofValue.resolve(
          _input(userUnderstandsWhatWouldBeLost: false),
        ).decision,
        PreservedProofValueDecision.clarifyWhatWouldBeLost,
      );
    });

    test('payment feels optional and payment weak -> pricingValidation', () {
      expect(
        PreservedProofValue.resolve(
          _input(
            userThinksPaymentFeelsOptional: true,
            wouldPayYes: false,
            wouldPayMaybe: false,
          ),
        ).decision,
        PreservedProofValueDecision.pricingValidation,
      );
    });

    test('comprehension and payment pass -> releaseCandidate', () {
      expect(
        PreservedProofValue.resolve(_input()).decision,
        PreservedProofValueDecision.releaseCandidate,
      );
    });
  });

  group('PreservedProofValueCopy', () {
    test('headline says Keep the proof you are building', () {
      expect(
        PreservedProofValueCopy.headline,
        'Keep the proof you are building',
      );
    });

    test('body says repeats build evidence over time', () {
      expect(
        PreservedProofValueCopy.body,
        contains('repeats build evidence over time'),
      );
    });

    test('body says Pro keeps longer trail', () {
      expect(
        PreservedProofValueCopy.body,
        contains('Pro keeps the longer trail'),
      );
    });

    test('body includes returned/changed/faded/corrected', () {
      final body = PreservedProofValueCopy.body.toLowerCase();
      expect(body, contains('returned'));
      expect(body, contains('changed'));
      expect(body, contains('faded'));
      expect(body, contains('corrected'));
    });

    test('freeLine says Free shows first useful proof', () {
      expect(
        PreservedProofValueCopy.freeLine,
        contains('Free shows the first useful proof'),
      );
    });

    test('proLine says Pro keeps proof trail after that', () {
      expect(
        PreservedProofValueCopy.proLine,
        contains('Pro keeps the proof trail after that'),
      );
    });

    test('whyPayLine says preserve the trail', () {
      expect(
        PreservedProofValueCopy.whyPayLine,
        contains('preserve the trail'),
      );
    });

    test('whyPayLine says not more chat or more AI', () {
      expect(
        PreservedProofValueCopy.whyPayLine,
        contains('not to get more chat or more AI'),
      );
    });

    test('lossLine says first proof but lose story of what happened next', () {
      expect(
        PreservedProofValueCopy.lossLine,
        contains('first proof but lose the story of what happened next'),
      );
    });

    test('valueLine says not storage', () {
      expect(
        PreservedProofValueCopy.valueLine,
        contains('The value is not storage'),
      );
    });

    test('valueLine says seeing what your past keeps proving', () {
      expect(
        PreservedProofValueCopy.valueLine,
        contains('seeing what your past keeps proving'),
      );
    });

    test(
      'repeatLine includes stayed same/softened/strengthened/faded/corrected',
      () {
        final line = PreservedProofValueCopy.repeatLine.toLowerCase();
        expect(line, contains('stayed the same'));
        expect(line, contains('softened'));
        expect(line, contains('strengthened'));
        expect(line, contains('faded'));
        expect(line, contains('corrected'));
      },
    );

    test('guardrail blocks fear', () {
      expect(PreservedProofValueCopy.guardrail, contains('fear'));
      expect(PreservedProofValueCopy.guardrail, contains('Do not use fear'));
    });

    test('guardrail blocks urgency tricks', () {
      expect(PreservedProofValueCopy.guardrail, contains('urgency tricks'));
    });

    test('guardrail blocks streaks', () {
      expect(PreservedProofValueCopy.guardrail, contains('streaks'));
    });

    test('guardrail blocks scarcity', () {
      expect(PreservedProofValueCopy.guardrail, contains('scarcity'));
    });

    test('copy does not say better than ChatGPT', () {
      for (final text in PreservedProofValueCopy.allVisibleStrings()) {
        final lower = text.toLowerCase();
        expect(lower.contains('better than chatgpt'), isFalse, reason: text);
        expect(lower.contains('better chatgpt'), isFalse, reason: text);
      }
    });

    test('copy does not position ArchiveMe as voice chat', () {
      for (final text in PreservedProofValueCopy.allVisibleStrings()) {
        final lower = text.toLowerCase();
        expect(lower.contains('voice chat'), isFalse, reason: text);
        expect(lower.contains('voice assistant'), isFalse, reason: text);
      }
    });

    test('copy does not introduce ranking or importance scoring', () {
      for (final text in PreservedProofValueCopy.allVisibleStrings()) {
        final lower = text.toLowerCase();
        expect(lower.contains('ranking'), isFalse, reason: text);
        expect(lower.contains('importance score'), isFalse, reason: text);
      }
    });

    test('copy avoids therapy diagnosis coaching and advice claims', () {
      for (final text in PreservedProofValueCopy.allVisibleStrings()) {
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
        'lib/features/preserved_proof_value/preserved_proof_value.dart',
        'lib/features/preserved_proof_value/preserved_proof_value_copy.dart',
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

    test('existing modules behaviour unchanged', () {
      expect(
        SaveARepeatHabit.resolve(
          const SaveARepeatHabitInput(
            userUnderstandsSaveRepeat: true,
            userStillUsesChatGptByHabit: false,
            userStillUsesNotesByHabit: false,
            userFeelsDailyPressure: false,
            userFeelsDashboardMaintenance: false,
            userUnderstandsOneSentenceEnough: true,
            userUnderstandsArchiveComparesLater: true,
            userUnderstandsRepeatTrigger: true,
            wouldPayYes: true,
            wouldPayMaybe: false,
          ),
        ).decision,
        SaveARepeatHabitDecision.releaseCandidate,
      );
      expect(
        ProofTrailPositioning.resolve(
          const ProofTrailPositioningInput(
            userThinksChatBox: false,
            userThinksStorageApp: false,
            userThinksSecondBrain: false,
            userThinksDashboardToMaintain: false,
            userUnderstandsProofTrail: true,
            userUnderstandsMeaningfulResurfacing: true,
            userUnderstandsSaveARepeat: true,
            userUnderstandsLowEffort: true,
            wouldPayYes: true,
            wouldPayMaybe: false,
          ),
        ).decision,
        ProofTrailPositioningDecision.releaseCandidate,
      );
      expect(
        ContextTrailClarity.build(
          const ContextTrailClarityInput(
            eligibleEntryCount: 4,
            taggedContextCount: 2,
            distinctContextCount: 1,
            hasStrongProof: true,
            hasUserCorrection: false,
            isFirstSession: false,
            isRecordScreen: false,
            userAskedForContext: false,
          ),
        ).reason,
        ContextTrailClarityReason.surfaceSingleContextEvidence,
      );
      expect(
        PositiveArchiveReinforcement.build(
          const PositiveArchiveReinforcementInput(
            savedMoment: true,
            hasSafeRepeat: true,
            hasEnoughArchiveSignal: true,
            isFirstMoment: true,
            isRelatedToPreviousRepeat: false,
            userCorrectedProofRecently: false,
            isWatchOnly: false,
            isPrivateRawText: false,
          ),
        ).reason,
        PositiveArchiveReinforcementReason.firstMomentSaved,
      );
      expect(
        ArchivePromptAssist.build(
          const ArchivePromptAssistInput(
            hasSafeRepeat: true,
            safeRepeatPhrase: 'said yes when I had no capacity',
            hasEnoughArchiveSignal: true,
            userRecentlyCorrectedProof: false,
            isWatchOnly: false,
            isGenericOrRejected: false,
            isPrivateRawText: false,
          ),
        ).reason,
        ArchivePromptAssistReason.safeRepeatPrompt,
      );
      expect(
        LowEffortArchiveCapture.resolve(_fullLowEffortSummary()),
        LowEffortArchiveCaptureDecision.releaseCandidate,
      );
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

LowEffortArchiveCaptureSummary _fullLowEffortSummary() =>
    const LowEffortArchiveCaptureSummary(
      totalTesters: 30,
      understoodNoDailyRequirementCount: 7,
      understoodOneSentenceEnoughCount: 7,
      understoodNoMindMapMaintenanceCount: 7,
      understoodSaveWhenRealRepeatCount: 7,
      thoughtDailyHomeworkCount: 0,
      thoughtManualMindMapMaintenanceCount: 0,
      preferredChatGptBecauseLessWorkCount: 0,
      wouldPayYesCount: 2,
      wouldPayMaybeCount: 1,
      wouldPayNoCount: 1,
    );

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
