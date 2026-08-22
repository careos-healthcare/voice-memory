import 'dart:io';

import 'package:archiveme_mobile/features/archive_prompt_assist/archive_prompt_assist.dart';
import 'package:archiveme_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:archiveme_mobile/features/change_trail_clarity/change_trail_clarity.dart';
import 'package:archiveme_mobile/features/context_trail_clarity/context_trail_clarity.dart';
import 'package:archiveme_mobile/features/core_archive_journey/core_archive_journey.dart';
import 'package:archiveme_mobile/features/low_effort_archive_capture/low_effort_archive_capture.dart';
import 'package:archiveme_mobile/features/no_dashboard_positioning/no_dashboard_positioning_guard.dart';
import 'package:archiveme_mobile/features/no_dashboard_positioning/no_dashboard_positioning_guard_copy.dart';
import 'package:archiveme_mobile/features/positive_archive_reinforcement/positive_archive_reinforcement.dart';
import 'package:archiveme_mobile/features/preserved_proof_value/preserved_proof_value.dart';
import 'package:archiveme_mobile/features/proof_detail_repair/proof_detail_repair_copy.dart';
import 'package:archiveme_mobile/features/proof_selection/proof_selection_principle.dart';
import 'package:archiveme_mobile/features/proof_trail_positioning/proof_trail_positioning.dart';
import 'package:archiveme_mobile/features/proof_trail_positioning/proof_trail_positioning_copy.dart';
import 'package:archiveme_mobile/features/save_a_repeat_habit/save_a_repeat_habit.dart';
import 'package:archiveme_mobile/features/surface_priority/surface_priority_engine.dart';
import 'package:archiveme_mobile/features/surface_priority/surface_priority_model.dart';
import 'package:archiveme_mobile/features/trail_language_guard/trail_language_guard.dart';
import 'package:archiveme_mobile/features/trail_language_guard/trail_language_guard_copy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NoDashboardPositioningGuard.evaluate', () {
    test('proof trail language allowed', () {
      const copy = 'ArchiveMe keeps your proof trail over time.';
      final result = NoDashboardPositioningGuard.evaluate(copy);
      expect(result.action, NoDashboardPositioningGuardAction.allowed);
      expect(
        result.reason,
        NoDashboardPositioningGuardReason.allowedProofTrailLanguage,
      );
      expect(
        NoDashboardPositioningGuard.containsPreferredProofTrailLanguage(copy),
        isTrue,
      );
    });

    test('one repeat language allowed', () {
      const copy = 'Save one repeat when something stands out.';
      final result = NoDashboardPositioningGuard.evaluate(copy);
      expect(result.action, NoDashboardPositioningGuardAction.allowed);
      expect(
        NoDashboardPositioningGuard.containsPreferredProofTrailLanguage(copy),
        isTrue,
      );
    });

    test('first useful proof language allowed', () {
      const copy = 'See the first useful proof after a few saves.';
      final result = NoDashboardPositioningGuard.evaluate(copy);
      expect(result.action, NoDashboardPositioningGuardAction.allowed);
      expect(
        NoDashboardPositioningGuard.containsPreferredProofTrailLanguage(copy),
        isTrue,
      );
    });

    test('longer proof trail language allowed', () {
      const copy = 'Pro keeps the longer proof trail as it grows.';
      final result = NoDashboardPositioningGuard.evaluate(copy);
      expect(result.action, NoDashboardPositioningGuardAction.allowed);
      expect(
        NoDashboardPositioningGuard.containsPreferredProofTrailLanguage(copy),
        isTrue,
      );
    });

    test('returns/changes/fades/corrected language allowed', () {
      const copy =
          'Watch what returned, changed, faded, or was corrected over time.';
      final result = NoDashboardPositioningGuard.evaluate(copy);
      expect(result.action, NoDashboardPositioningGuardAction.allowed);
      expect(
        NoDashboardPositioningGuard.containsPreferredProofTrailLanguage(copy),
        isTrue,
      );
    });

    test('one sentence is enough language allowed', () {
      const copy = 'One sentence is enough to start the trail.';
      final result = NoDashboardPositioningGuard.evaluate(copy);
      expect(result.action, NoDashboardPositioningGuardAction.allowed);
      expect(
        NoDashboardPositioningGuard.containsPreferredProofTrailLanguage(copy),
        isTrue,
      );
    });

    test('dashboard positioning blocked', () {
      final result = NoDashboardPositioningGuard.evaluate(
        'ArchiveMe is your life dashboard.',
      );
      expect(result.action, NoDashboardPositioningGuardAction.block);
      expect(
        result.reason,
        NoDashboardPositioningGuardReason.blockedDashboardPositioning,
      );
    });

    test('command center positioning blocked', () {
      final result = NoDashboardPositioningGuard.evaluate(
        'ArchiveMe is your command center for life.',
      );
      expect(result.action, NoDashboardPositioningGuardAction.block);
      expect(
        result.reason,
        NoDashboardPositioningGuardReason.blockedCommandCenter,
      );
    });

    test('life operating system positioning blocked', () {
      final result = NoDashboardPositioningGuard.evaluate(
        'Build your life operating system inside ArchiveMe.',
      );
      expect(result.action, NoDashboardPositioningGuardAction.block);
      expect(
        result.reason,
        NoDashboardPositioningGuardReason.blockedLifeOperatingSystem,
      );
    });

    test('second brain positioning blocked', () {
      final result = NoDashboardPositioningGuard.evaluate(
        'Build your second brain inside ArchiveMe.',
      );
      expect(result.action, NoDashboardPositioningGuardAction.block);
      expect(
        result.reason,
        NoDashboardPositioningGuardReason.blockedSecondBrain,
      );
    });

    test('productivity system positioning blocked', () {
      final result = NoDashboardPositioningGuard.evaluate(
        'ArchiveMe is your productivity system for everything.',
      );
      expect(result.action, NoDashboardPositioningGuardAction.block);
      expect(
        result.reason,
        NoDashboardPositioningGuardReason.blockedProductivitySystem,
      );
    });

    test('personal analytics dashboard positioning blocked', () {
      final result = NoDashboardPositioningGuard.evaluate(
        'See your personal analytics dashboard at a glance.',
      );
      expect(result.action, NoDashboardPositioningGuardAction.block);
      expect(
        result.reason,
        NoDashboardPositioningGuardReason.blockedPersonalAnalyticsDashboard,
      );
    });

    test('full life report positioning blocked', () {
      final result = NoDashboardPositioningGuard.evaluate(
        'Get your full life report every month.',
      );
      expect(result.action, NoDashboardPositioningGuardAction.block);
      expect(
        result.reason,
        NoDashboardPositioningGuardReason.blockedFullLifeReport,
      );
    });

    test('action plan manager positioning blocked', () {
      final result = NoDashboardPositioningGuard.evaluate(
        'Use ArchiveMe as your action plan manager.',
      );
      expect(result.action, NoDashboardPositioningGuardAction.block);
      expect(
        result.reason,
        NoDashboardPositioningGuardReason.blockedActionPlanManager,
      );
    });

    test('dashboard overview warns', () {
      final result = NoDashboardPositioningGuard.evaluate(
        'See the dashboard overview panel.',
      );
      expect(result.action, NoDashboardPositioningGuardAction.warn);
      expect(
        result.reason,
        NoDashboardPositioningGuardReason.warnedDashboardDrift,
      );
    });

    test('anti-dashboard instructional copy allowed', () {
      expect(
        NoDashboardPositioningGuard.evaluate(
          ProofTrailPositioningCopy.guardrail,
        ).action,
        NoDashboardPositioningGuardAction.allowed,
      );
      expect(
        NoDashboardPositioningGuard.evaluate(
          TrailLanguageGuardCopy.guardrail,
        ).action,
        NoDashboardPositioningGuardAction.allowed,
      );
      expect(
        NoDashboardPositioningGuard.evaluate(
          'No reports, dashboards, action items, or context work needed now.',
        ).action,
        NoDashboardPositioningGuardAction.allowed,
      );
    });

    test('not-a-dashboard negation allowed', () {
      final result = NoDashboardPositioningGuard.evaluate(
        'ArchiveMe is not a dashboard for your whole life.',
      );
      expect(result.action, NoDashboardPositioningGuardAction.allowed);
    });
  });

  group('NoDashboardPositioningGuardCopy', () {
    test('headline says ArchiveMe is not a life dashboard', () {
      expect(
        NoDashboardPositioningGuardCopy.headline,
        'ArchiveMe is not a life dashboard',
      );
    });

    test(
      'preferredLanguageLine includes proof trail and one sentence is enough',
      () {
        final line = NoDashboardPositioningGuardCopy.preferredLanguageLine
            .toLowerCase();
        expect(line, contains('proof trail'));
        expect(line, contains('one repeat'));
        expect(line, contains('first useful proof'));
        expect(line, contains('longer proof trail'));
        expect(line, contains('one sentence is enough'));
      },
    );

    test('avoidLanguageLine blocks dashboard positioning frames', () {
      final line = NoDashboardPositioningGuardCopy.avoidLanguageLine
          .toLowerCase();
      expect(line, contains('dashboard'));
      expect(line, contains('command center'));
      expect(line, contains('life operating system'));
      expect(line, contains('second brain'));
      expect(line, contains('productivity system'));
      expect(line, contains('personal analytics dashboard'));
      expect(line, contains('full life report'));
      expect(line, contains('action plan manager'));
    });

    test('guardrail says copy guard only', () {
      expect(
        NoDashboardPositioningGuardCopy.guardrail,
        contains('Copy guard only'),
      );
      expect(
        NoDashboardPositioningGuardCopy.guardrail,
        contains('No UI changes unless a first-journey blocker exists'),
      );
    });

    test('copy avoids therapy diagnosis coaching and advice claims', () {
      for (final text in NoDashboardPositioningGuardCopy.allVisibleStrings()) {
        expect(ProofSurfaceAdviceGuard.passes(text), isTrue, reason: text);
        final lower = text.toLowerCase();
        expect(lower.contains('advice'), isFalse, reason: text);
        expect(lower.contains('coaching'), isFalse, reason: text);
        expect(lower.contains('therapy'), isFalse, reason: text);
        expect(lower.contains('diagnosis'), isFalse, reason: text);
      }
    });

    test('own copy passes strict guard', () {
      for (final text in NoDashboardPositioningGuardCopy.allVisibleStrings()) {
        expect(
          NoDashboardPositioningGuard.passesStrict(text),
          isTrue,
          reason: text,
        );
      }
    });
  });

  group('Main proof surfaces', () {
    test('main proof surface copy does not block on dashboard positioning', () {
      final offenders = <String>[];
      for (final text in ProofSurfaceAdviceGuard.mainProofSurfaceCopyBlocks()) {
        final result = NoDashboardPositioningGuard.evaluate(text);
        if (result.action == NoDashboardPositioningGuardAction.block) {
          offenders.add('${result.matchedPhrase}: $text');
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });
  });

  group('Protected areas', () {
    test('module does not import billing entitlements or analytics expansion', () {
      for (final path in [
        'lib/features/no_dashboard_positioning/no_dashboard_positioning_guard.dart',
        'lib/features/no_dashboard_positioning/no_dashboard_positioning_guard_copy.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source.contains('RevenueCat'), isFalse);
        expect(source.contains('restorePurchases'), isFalse);
        expect(source.contains('billing/'), isFalse);
        expect(source.contains('paywall'), isFalse);
      }
    });

    test(
      'proof_surface_advice_guard registers no dashboard positioning copy',
      () {
        final source = File(
          'lib/features/archive_proof/proof_surface_advice_guard.dart',
        ).readAsStringSync();
        expect(source, contains('no_dashboard_positioning_guard_copy.dart'));
        expect(
          source,
          contains('NoDashboardPositioningGuardCopy.allVisibleStrings()'),
        );
      },
    );

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
        TrailLanguageGuard.isAllowedCopy(
          'ArchiveMe keeps your proof trail over time.',
        ).isAllowed,
        isTrue,
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