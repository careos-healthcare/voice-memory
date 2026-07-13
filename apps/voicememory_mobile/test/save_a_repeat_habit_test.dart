import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_prompt_assist/archive_prompt_assist.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/change_trail_clarity/change_trail_clarity.dart';
import 'package:voicememory_mobile/features/context_trail_clarity/context_trail_clarity.dart';
import 'package:voicememory_mobile/features/core_archive_journey/core_archive_journey.dart';
import 'package:voicememory_mobile/features/low_effort_archive_capture/low_effort_archive_capture.dart';
import 'package:voicememory_mobile/features/positive_archive_reinforcement/positive_archive_reinforcement.dart';
import 'package:voicememory_mobile/features/proof_detail_repair/proof_detail_repair_copy.dart';
import 'package:voicememory_mobile/features/proof_selection/proof_selection_principle.dart';
import 'package:voicememory_mobile/features/proof_trail_positioning/proof_trail_positioning.dart';
import 'package:voicememory_mobile/features/release_candidate_comprehension/release_candidate_comprehension.dart';
import 'package:voicememory_mobile/features/save_a_repeat_habit/save_a_repeat_habit.dart';
import 'package:voicememory_mobile/features/save_a_repeat_habit/save_a_repeat_habit_copy.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_engine.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_model.dart';

SaveARepeatHabitInput _input({
  bool userUnderstandsSaveRepeat = true,
  bool userStillUsesChatGptByHabit = false,
  bool userStillUsesNotesByHabit = false,
  bool userFeelsDailyPressure = false,
  bool userFeelsDashboardMaintenance = false,
  bool userUnderstandsOneSentenceEnough = true,
  bool userUnderstandsArchiveComparesLater = true,
  bool userUnderstandsRepeatTrigger = true,
  bool wouldPayYes = true,
  bool wouldPayMaybe = false,
}) =>
    SaveARepeatHabitInput(
      userUnderstandsSaveRepeat: userUnderstandsSaveRepeat,
      userStillUsesChatGptByHabit: userStillUsesChatGptByHabit,
      userStillUsesNotesByHabit: userStillUsesNotesByHabit,
      userFeelsDailyPressure: userFeelsDailyPressure,
      userFeelsDashboardMaintenance: userFeelsDashboardMaintenance,
      userUnderstandsOneSentenceEnough: userUnderstandsOneSentenceEnough,
      userUnderstandsArchiveComparesLater: userUnderstandsArchiveComparesLater,
      userUnderstandsRepeatTrigger: userUnderstandsRepeatTrigger,
      wouldPayYes: wouldPayYes,
      wouldPayMaybe: wouldPayMaybe,
    );

void main() {
  group('SaveARepeatHabit.resolve', () {
    test('weak repeat trigger understanding -> clarifyRepeatTrigger', () {
      expect(
        SaveARepeatHabit.resolve(
          _input(userUnderstandsRepeatTrigger: false),
        ).decision,
        SaveARepeatHabitDecision.clarifyRepeatTrigger,
      );
    });

    test('weak one sentence understanding -> clarifyOneSentenceEnough', () {
      expect(
        SaveARepeatHabit.resolve(
          _input(userUnderstandsOneSentenceEnough: false),
        ).decision,
        SaveARepeatHabitDecision.clarifyOneSentenceEnough,
      );
    });

    test('daily pressure -> clarifyNoDailyPressure', () {
      expect(
        SaveARepeatHabit.resolve(_input(userFeelsDailyPressure: true)).decision,
        SaveARepeatHabitDecision.clarifyNoDailyPressure,
      );
    });

    test('dashboard maintenance feeling -> clarifyNoDashboardMaintenance', () {
      expect(
        SaveARepeatHabit.resolve(
          _input(userFeelsDashboardMaintenance: true),
        ).decision,
        SaveARepeatHabitDecision.clarifyNoDashboardMaintenance,
      );
    });

    test('weak archive compares later understanding -> clarifyArchiveComparesLater',
        () {
      expect(
        SaveARepeatHabit.resolve(
          _input(userUnderstandsArchiveComparesLater: false),
        ).decision,
        SaveARepeatHabitDecision.clarifyArchiveComparesLater,
      );
    });

    test('ChatGPT habit remains -> clarifyChatGptHabitDifference', () {
      expect(
        SaveARepeatHabit.resolve(
          _input(userStillUsesChatGptByHabit: true),
        ).decision,
        SaveARepeatHabitDecision.clarifyChatGptHabitDifference,
      );
    });

    test('Notes habit remains -> clarifyNotesHabitDifference', () {
      expect(
        SaveARepeatHabit.resolve(
          _input(userStillUsesNotesByHabit: true),
        ).decision,
        SaveARepeatHabitDecision.clarifyNotesHabitDifference,
      );
    });

    test('comprehension passes but payment weak -> pricingValidation', () {
      expect(
        SaveARepeatHabit.resolve(
          _input(wouldPayYes: false, wouldPayMaybe: false),
        ).decision,
        SaveARepeatHabitDecision.pricingValidation,
      );
    });

    test('comprehension and payment pass -> releaseCandidate', () {
      expect(
        SaveARepeatHabit.resolve(_input()).decision,
        SaveARepeatHabitDecision.releaseCandidate,
      );
    });
  });

  group('SaveARepeatHabitCopy', () {
    test('headline says When it repeats, save it', () {
      expect(SaveARepeatHabitCopy.headline, 'When it repeats, save it');
    });

    test('body says save one real moment', () {
      expect(SaveARepeatHabitCopy.body, contains('save one real moment'));
    });

    test('body says ArchiveMe compares it later', () {
      expect(
        SaveARepeatHabitCopy.body,
        contains('ArchiveMe compares it later'),
      );
    });

    test('triggerLine says I noticed this again', () {
      expect(
        SaveARepeatHabitCopy.triggerLine,
        contains('I noticed this again'),
      );
    });

    test('oneSentenceLine says one real sentence is enough', () {
      expect(
        SaveARepeatHabitCopy.oneSentenceLine,
        contains('One real sentence is enough'),
      );
    });

    test('notDailyLine says no daily journal', () {
      expect(SaveARepeatHabitCopy.notDailyLine, contains('No daily journal'));
    });

    test('notDailyLine says no streak', () {
      expect(SaveARepeatHabitCopy.notDailyLine, contains('No streak'));
    });

    test('notDailyLine says no dashboard to maintain', () {
      expect(
        SaveARepeatHabitCopy.notDailyLine,
        contains('No dashboard to maintain'),
      );
    });

    test('whyItMattersLine says ArchiveMe evidence to compare later', () {
      expect(
        SaveARepeatHabitCopy.whyItMattersLine,
        contains('ArchiveMe evidence to compare later'),
      );
    });

    test('chatDifferenceLine distinguishes ChatGPT from ArchiveMe evidence trail',
        () {
      expect(
        SaveARepeatHabitCopy.chatDifferenceLine,
        contains('ChatGPT can suggest what to do'),
      );
      expect(
        SaveARepeatHabitCopy.chatDifferenceLine,
        contains('ArchiveMe shows what you already said before'),
      );
    });

    test('notesDifferenceLine distinguishes notes storage from ArchiveMe comparing',
        () {
      expect(
        SaveARepeatHabitCopy.notesDifferenceLine,
        contains('Notes store what happened'),
      );
      expect(
        SaveARepeatHabitCopy.notesDifferenceLine,
        contains('ArchiveMe checks what returns'),
      );
    });

    test('proLine says Free shows first useful proof', () {
      expect(
        SaveARepeatHabitCopy.proLine,
        contains('Free shows the first useful proof'),
      );
    });

    test('proLine says Pro keeps longer trail', () {
      expect(
        SaveARepeatHabitCopy.proLine,
        contains('Pro keeps the longer trail'),
      );
    });

    test('guardrail blocks daily habit tracker', () {
      expect(
        SaveARepeatHabitCopy.guardrail,
        contains('daily habit tracker'),
      );
    });

    test('guardrail blocks chat app', () {
      expect(SaveARepeatHabitCopy.guardrail, contains('chat app'));
    });

    test('guardrail blocks storage app', () {
      expect(SaveARepeatHabitCopy.guardrail, contains('storage app'));
    });

    test('guardrail blocks dashboard to maintain', () {
      expect(
        SaveARepeatHabitCopy.guardrail,
        contains('dashboard to maintain'),
      );
    });

    test('copy does not say better than ChatGPT', () {
      for (final text in SaveARepeatHabitCopy.allVisibleStrings()) {
        final lower = text.toLowerCase();
        expect(lower.contains('better than chatgpt'), isFalse, reason: text);
        expect(lower.contains('better chatgpt'), isFalse, reason: text);
      }
    });

    test('copy does not position ArchiveMe as voice chat', () {
      for (final text in SaveARepeatHabitCopy.allVisibleStrings()) {
        final lower = text.toLowerCase();
        expect(lower.contains('voice chat'), isFalse, reason: text);
        expect(lower.contains('voice assistant'), isFalse, reason: text);
      }
    });

    test('copy does not introduce ranking or importance scoring', () {
      for (final text in SaveARepeatHabitCopy.allVisibleStrings()) {
        final lower = text.toLowerCase();
        expect(lower.contains('ranking'), isFalse, reason: text);
        expect(lower.contains('importance score'), isFalse, reason: text);
      }
    });

    test('copy avoids therapy diagnosis coaching and advice claims', () {
      for (final text in SaveARepeatHabitCopy.allVisibleStrings()) {
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
        'lib/features/save_a_repeat_habit/save_a_repeat_habit.dart',
        'lib/features/save_a_repeat_habit/save_a_repeat_habit_copy.dart',
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

ChangeTrailClaritySummary _fullTrailSummary() => const ChangeTrailClaritySummary(
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
