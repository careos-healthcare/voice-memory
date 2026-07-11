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
import 'package:voicememory_mobile/features/proof_detail_repair/proof_detail_repair_copy.dart';
import 'package:voicememory_mobile/features/proof_selection/proof_selection_principle.dart';
import 'package:voicememory_mobile/features/proof_trail_positioning/proof_trail_positioning.dart';
import 'package:voicememory_mobile/features/save_a_repeat_habit/save_a_repeat_habit.dart';
import 'package:voicememory_mobile/features/trail_language_guard/trail_language_guard.dart';
import 'package:voicememory_mobile/features/trail_language_guard/trail_language_guard_copy.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_engine.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_model.dart';

void main() {
  group('TrailLanguageGuard.isAllowedCopy', () {
    test('proof trail language allowed', () {
      const copy = 'ArchiveMe keeps your proof trail over time.';
      final result = TrailLanguageGuard.isAllowedCopy(copy);
      expect(result.isAllowed, isTrue);
      expect(
        result.reason,
        TrailLanguageGuardReason.allowedProofTrailLanguage,
      );
      expect(TrailLanguageGuard.containsPreferredTrailLanguage(copy), isTrue);
    });

    test('evidence trail language allowed', () {
      final result = TrailLanguageGuard.isAllowedCopy(
        'Pro keeps the evidence trail after the first proof.',
      );
      expect(result.isAllowed, isTrue);
      expect(
        TrailLanguageGuard.containsPreferredTrailLanguage(
          'Pro keeps the evidence trail after the first proof.',
        ),
        isTrue,
      );
    });

    test('saved moments language allowed', () {
      final result = TrailLanguageGuard.isAllowedCopy(
        'Save small saved moments when something repeats.',
      );
      expect(result.isAllowed, isTrue);
      expect(
        TrailLanguageGuard.containsPreferredTrailLanguage(
          'Save small saved moments when something repeats.',
        ),
        isTrue,
      );
    });

    test('what came back language allowed', () {
      final result = TrailLanguageGuard.isAllowedCopy(
        'See what came back from your archive.',
      );
      expect(result.isAllowed, isTrue);
      expect(
        TrailLanguageGuard.containsPreferredTrailLanguage(
          'See what came back from your archive.',
        ),
        isTrue,
      );
    });

    test('returns/changes/fades/corrected language allowed', () {
      final copy =
          'Watch what returned, changed, faded, or was corrected over time.';
      final result = TrailLanguageGuard.isAllowedCopy(copy);
      expect(result.isAllowed, isTrue);
      expect(TrailLanguageGuard.containsPreferredTrailLanguage(copy), isTrue);
    });

    test('one sentence is enough language allowed', () {
      final copy = 'One sentence is enough to start the trail.';
      final result = TrailLanguageGuard.isAllowedCopy(copy);
      expect(result.isAllowed, isTrue);
      expect(TrailLanguageGuard.containsPreferredTrailLanguage(copy), isTrue);
    });

    test('ArchiveMe compares later language allowed', () {
      final copy = 'ArchiveMe compares it later when the repeat returns.';
      final result = TrailLanguageGuard.isAllowedCopy(copy);
      expect(result.isAllowed, isTrue);
      expect(TrailLanguageGuard.containsPreferredTrailLanguage(copy), isTrue);
    });

    test('maintain your mind map blocked', () {
      final result = TrailLanguageGuard.isAllowedCopy(
        'Maintain your mind map every week.',
      );
      expect(result.isAllowed, isFalse);
      expect(
        result.reason,
        TrailLanguageGuardReason.blockedMindMapMaintenance,
      );
    });

    test('keep your mind map active blocked', () {
      final result = TrailLanguageGuard.isAllowedCopy(
        'Keep your mind map active with daily updates.',
      );
      expect(result.isAllowed, isFalse);
      expect(
        result.reason,
        TrailLanguageGuardReason.blockedMindMapMaintenance,
      );
    });

    test('update your map daily blocked', () {
      final result = TrailLanguageGuard.isAllowedCopy(
        'Update your map daily to stay organized.',
      );
      expect(result.isAllowed, isFalse);
      expect(
        result.reason,
        TrailLanguageGuardReason.blockedMindMapMaintenance,
      );
    });

    test('daily tracker blocked', () {
      final result = TrailLanguageGuard.isAllowedCopy(
        'Use ArchiveMe as your daily tracker.',
      );
      expect(result.isAllowed, isFalse);
      expect(result.reason, TrailLanguageGuardReason.blockedDailyTracker);
    });

    test('streak language blocked', () {
      final result = TrailLanguageGuard.isAllowedCopy(
        'Keep your streak alive by recording every day.',
      );
      expect(result.isAllowed, isFalse);
      expect(result.reason, TrailLanguageGuardReason.blockedStreakLanguage);
    });

    test('dashboard to maintain blocked', () {
      final result = TrailLanguageGuard.isAllowedCopy(
        'ArchiveMe is a dashboard to maintain.',
      );
      expect(result.isAllowed, isFalse);
      expect(
        result.reason,
        TrailLanguageGuardReason.blockedDashboardMaintenance,
      );
    });

    test('storage app positioning blocked', () {
      final result = TrailLanguageGuard.isAllowedCopy(
        'ArchiveMe is a storage app for everything you think.',
      );
      expect(result.isAllowed, isFalse);
      expect(
        result.reason,
        TrailLanguageGuardReason.blockedStoragePositioning,
      );
    });

    test('second brain positioning blocked', () {
      final result = TrailLanguageGuard.isAllowedCopy(
        'Build your second brain inside ArchiveMe.',
      );
      expect(result.isAllowed, isFalse);
      expect(
        result.reason,
        TrailLanguageGuardReason.blockedStoragePositioning,
      );
    });

    test('ranked patterns blocked', () {
      final result = TrailLanguageGuard.isAllowedCopy(
        'See your ranked patterns at a glance.',
      );
      expect(result.isAllowed, isFalse);
      expect(
        result.reason,
        TrailLanguageGuardReason.blockedRankingPositioning,
      );
    });

    test('therapy language blocked', () {
      final result = TrailLanguageGuard.isAllowedCopy(
        'ArchiveMe provides therapy support for your patterns.',
      );
      expect(result.isAllowed, isFalse);
      expect(result.reason, TrailLanguageGuardReason.blockedTherapyLanguage);
    });

    test('diagnosis language blocked', () {
      final result = TrailLanguageGuard.isAllowedCopy(
        'This diagnosis explains what your archive means.',
      );
      expect(result.isAllowed, isFalse);
      expect(result.reason, TrailLanguageGuardReason.blockedTherapyLanguage);
    });

    test('coach language blocked', () {
      final result = TrailLanguageGuard.isAllowedCopy(
        'Your archive coach will tell you what to do next.',
      );
      expect(result.isAllowed, isFalse);
      expect(result.reason, TrailLanguageGuardReason.blockedTherapyLanguage);
    });
  });

  group('TrailLanguageGuardCopy', () {
    test('headline says ArchiveMe builds a trail', () {
      expect(
        TrailLanguageGuardCopy.headline,
        'ArchiveMe builds a trail',
      );
    });

    test('body says user does not maintain a mind map', () {
      expect(
        TrailLanguageGuardCopy.body,
        contains('You do not maintain a mind map'),
      );
    });

    test('body says save small real moments', () {
      expect(
        TrailLanguageGuardCopy.body,
        contains('save small real moments'),
      );
    });

    test('body says ArchiveMe builds proof trail over time', () {
      expect(
        TrailLanguageGuardCopy.body,
        contains('builds the proof trail over time'),
      );
    });

    test('preferredLanguageLine includes trail/proof trail/evidence trail/saved moments',
        () {
      final line = TrailLanguageGuardCopy.preferredLanguageLine.toLowerCase();
      expect(line, contains('trail'));
      expect(line, contains('proof trail'));
      expect(line, contains('evidence trail'));
      expect(line, contains('saved moments'));
    });

    test('avoidLanguageLine blocks mind-map maintenance/dashboard/daily/streak/storage',
        () {
      final line = TrailLanguageGuardCopy.avoidLanguageLine.toLowerCase();
      expect(line, contains('mind-map maintenance'));
      expect(line, contains('dashboard to maintain'));
      expect(line, contains('daily tracking'));
      expect(line, contains('streaks'));
      expect(line, contains('storage language'));
    });

    test('whyTrailLine says save repeat now and see later', () {
      expect(
        TrailLanguageGuardCopy.whyTrailLine,
        contains('save the repeat now'),
      );
      expect(
        TrailLanguageGuardCopy.whyTrailLine,
        contains('see what happened later'),
      );
    });

    test('proLine includes returned/changed/faded/corrected', () {
      final line = TrailLanguageGuardCopy.proLine.toLowerCase();
      expect(line, contains('returned'));
      expect(line, contains('changed'));
      expect(line, contains('faded'));
      expect(line, contains('corrected'));
    });

    test('guardrail says quietly preserved proof trail', () {
      expect(
        TrailLanguageGuardCopy.guardrail,
        contains('quietly preserved proof trail'),
      );
    });

    test('guardrail blocks map/dashboard/tracker/storage system', () {
      final guardrail = TrailLanguageGuardCopy.guardrail.toLowerCase();
      expect(guardrail, contains('not a map'));
      expect(guardrail, contains('dashboard'));
      expect(guardrail, contains('tracker'));
      expect(guardrail, contains('storage system'));
    });

    test('copy does not say better than ChatGPT', () {
      for (final text in TrailLanguageGuardCopy.allVisibleStrings()) {
        final lower = text.toLowerCase();
        expect(lower.contains('better than chatgpt'), isFalse, reason: text);
        expect(lower.contains('better chatgpt'), isFalse, reason: text);
      }
    });

    test('copy does not position ArchiveMe as voice chat', () {
      for (final text in TrailLanguageGuardCopy.allVisibleStrings()) {
        final lower = text.toLowerCase();
        expect(lower.contains('voice chat'), isFalse, reason: text);
        expect(lower.contains('voice assistant'), isFalse, reason: text);
      }
    });

    test('copy does not introduce ranking or importance scoring', () {
      for (final text in TrailLanguageGuardCopy.allVisibleStrings()) {
        final lower = text.toLowerCase();
        expect(lower.contains('ranking'), isFalse, reason: text);
        expect(lower.contains('importance score'), isFalse, reason: text);
      }
    });

    test('copy avoids therapy diagnosis coaching and advice claims', () {
      for (final text in TrailLanguageGuardCopy.allVisibleStrings()) {
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
        'lib/features/trail_language_guard/trail_language_guard.dart',
        'lib/features/trail_language_guard/trail_language_guard_copy.dart',
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
        PreservedProofValue.resolve(
          const PreservedProofValueInput(
            userUnderstandsFirstProof: true,
            userUnderstandsProKeepsTrail: true,
            userUnderstandsPreservedProof: true,
            userUnderstandsWhatWouldBeLost: true,
            userThinksProMeansMoreAi: false,
            userThinksProMeansStorage: false,
            userThinksPaymentFeelsOptional: true,
            userFeelsPressureOrManipulation: false,
            wouldPayYes: true,
            wouldPayMaybe: false,
          ),
        ).decision,
        PreservedProofValueDecision.releaseCandidate,
      );
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
