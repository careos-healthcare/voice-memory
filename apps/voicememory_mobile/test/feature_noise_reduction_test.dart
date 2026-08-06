import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/change_trail_clarity/change_trail_clarity.dart';
import 'package:voicememory_mobile/features/context_trail_clarity/context_trail_clarity.dart';
import 'package:voicememory_mobile/features/core_archive_journey/core_archive_journey.dart';
import 'package:voicememory_mobile/features/feature_noise_reduction/feature_noise_reduction.dart';
import 'package:voicememory_mobile/features/feature_noise_reduction/feature_noise_reduction_copy.dart';
import 'package:voicememory_mobile/features/low_effort_archive_capture/low_effort_archive_capture.dart';
import 'package:voicememory_mobile/features/positive_archive_reinforcement/positive_archive_reinforcement.dart';
import 'package:voicememory_mobile/features/preserved_proof_value/preserved_proof_value.dart';
import 'package:voicememory_mobile/features/proof_detail_repair/proof_detail_repair_copy.dart';
import 'package:voicememory_mobile/features/proof_selection/proof_selection_principle.dart';
import 'package:voicememory_mobile/features/proof_trail_positioning/proof_trail_positioning.dart';
import 'package:voicememory_mobile/features/save_a_repeat_habit/save_a_repeat_habit.dart';
import 'package:voicememory_mobile/features/store_readiness_proof/store_readiness_proof.dart';
import 'package:voicememory_mobile/features/trail_language_guard/trail_language_guard.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_engine.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_model.dart';

FeatureNoiseReductionInput _input({
  FeatureSurfaceType surfaceType = FeatureSurfaceType.recordCapture,
  int eligibleEntryCount = 5,
  bool hasFirstUsefulProof = true,
  bool hasConfirmedRepeat = true,
  bool hasLongerTrail = true,
  bool hasUserCorrection = false,
  bool isFirstSession = false,
  bool isRecordScreen = false,
  bool isPostSave = false,
  bool userAskedForSurface = false,
  bool storeReadinessMode = false,
}) => FeatureNoiseReductionInput(
  surfaceType: surfaceType,
  eligibleEntryCount: eligibleEntryCount,
  hasFirstUsefulProof: hasFirstUsefulProof,
  hasConfirmedRepeat: hasConfirmedRepeat,
  hasLongerTrail: hasLongerTrail,
  hasUserCorrection: hasUserCorrection,
  isFirstSession: isFirstSession,
  isRecordScreen: isRecordScreen,
  isPostSave: isPostSave,
  userAskedForSurface: userAskedForSurface,
  storeReadinessMode: storeReadinessMode,
);

void main() {
  group('FeatureNoiseReduction.build', () {
    test('recordCapture always shows', () {
      final result = FeatureNoiseReduction.build(
        _input(surfaceType: FeatureSurfaceType.recordCapture),
      );
      expect(result.shouldShow, isTrue);
      expect(result.reason, FeatureNoiseReductionReason.showCoreCapture);
    });

    test('firstProof shows with first useful proof', () {
      final result = FeatureNoiseReduction.build(
        _input(surfaceType: FeatureSurfaceType.firstProof),
      );
      expect(result.shouldShow, isTrue);
      expect(result.reason, FeatureNoiseReductionReason.showFirstProofJourney);
    });

    test('whyProofAppeared shows with first useful proof', () {
      final result = FeatureNoiseReduction.build(
        _input(surfaceType: FeatureSurfaceType.whyProofAppeared),
      );
      expect(result.shouldShow, isTrue);
      expect(result.reason, FeatureNoiseReductionReason.showFirstProofJourney);
    });

    test('confirmCorrect shows with first useful proof', () {
      final result = FeatureNoiseReduction.build(
        _input(surfaceType: FeatureSurfaceType.confirmCorrect),
      );
      expect(result.shouldShow, isTrue);
      expect(result.reason, FeatureNoiseReductionReason.showFirstProofJourney);
    });

    test('promptAssist can show in record context', () {
      final result = FeatureNoiseReduction.build(
        _input(
          surfaceType: FeatureSurfaceType.promptAssist,
          isRecordScreen: true,
        ),
      );
      expect(result.shouldShow, isTrue);
      expect(result.reason, FeatureNoiseReductionReason.showPromptAssist);
    });

    test('positiveReinforcement can show post-save', () {
      final result = FeatureNoiseReduction.build(
        _input(
          surfaceType: FeatureSurfaceType.positiveReinforcement,
          isPostSave: true,
        ),
      );
      expect(result.shouldShow, isTrue);
      expect(
        result.reason,
        FeatureNoiseReductionReason.showPositiveReinforcement,
      );
    });

    test('longerTrail shows with confirmed repeat', () {
      final result = FeatureNoiseReduction.build(
        _input(
          surfaceType: FeatureSurfaceType.longerTrail,
          hasConfirmedRepeat: true,
          hasLongerTrail: false,
        ),
      );
      expect(result.shouldShow, isTrue);
      expect(result.reason, FeatureNoiseReductionReason.showLongerTrail);
    });

    test('proTrail shows after first useful proof', () {
      final result = FeatureNoiseReduction.build(
        _input(
          surfaceType: FeatureSurfaceType.proTrail,
          hasFirstUsefulProof: true,
          hasLongerTrail: false,
        ),
      );
      expect(result.shouldShow, isTrue);
      expect(result.reason, FeatureNoiseReductionReason.showProTrail);
    });

    test('debug readiness shows in storeReadinessMode', () {
      final result = FeatureNoiseReduction.build(
        _input(
          surfaceType: FeatureSurfaceType.debugReadiness,
          storeReadinessMode: true,
        ),
      );
      expect(result.shouldShow, isTrue);
      expect(
        result.reason,
        FeatureNoiseReductionReason.showStoreReadinessDebug,
      );
    });

    test('user-requested surface shows with enough evidence', () {
      final result = FeatureNoiseReduction.build(
        _input(
          surfaceType: FeatureSurfaceType.contextDetail,
          userAskedForSurface: true,
          eligibleEntryCount: 3,
        ),
      );
      expect(result.shouldShow, isTrue);
      expect(result.reason, FeatureNoiseReductionReason.showWhenUserAsked);
    });

    test('first session hides context detail', () {
      final result = FeatureNoiseReduction.build(
        _input(
          surfaceType: FeatureSurfaceType.contextDetail,
          isFirstSession: true,
        ),
      );
      expect(result.shouldShow, isFalse);
      expect(result.reason, FeatureNoiseReductionReason.hideFirstSessionNoise);
    });

    test('first session hides reports', () {
      final result = FeatureNoiseReduction.build(
        _input(
          surfaceType: FeatureSurfaceType.weeklyReport,
          isFirstSession: true,
        ),
      );
      expect(result.shouldShow, isFalse);
      expect(result.reason, FeatureNoiseReductionReason.hideFirstSessionNoise);
    });

    test('first session hides action items', () {
      final result = FeatureNoiseReduction.build(
        _input(
          surfaceType: FeatureSurfaceType.actionItems,
          isFirstSession: true,
        ),
      );
      expect(result.shouldShow, isFalse);
      expect(result.reason, FeatureNoiseReductionReason.hideFirstSessionNoise);
    });

    test('record screen hides secondary surfaces', () {
      final result = FeatureNoiseReduction.build(
        _input(
          surfaceType: FeatureSurfaceType.weeklyReport,
          isRecordScreen: true,
        ),
      );
      expect(result.shouldShow, isFalse);
      expect(result.reason, FeatureNoiseReductionReason.hideRecordScreenNoise);
    });

    test('context detail hidden before 3 eligible entries', () {
      final result = FeatureNoiseReduction.build(
        _input(
          surfaceType: FeatureSurfaceType.contextDetail,
          eligibleEntryCount: 2,
        ),
      );
      expect(result.shouldShow, isFalse);
      expect(
        result.reason,
        FeatureNoiseReductionReason.hideContextUntilEvidence,
      );
    });

    test('context detail hidden before first proof', () {
      final result = FeatureNoiseReduction.build(
        _input(
          surfaceType: FeatureSurfaceType.contextDetail,
          hasFirstUsefulProof: false,
        ),
      );
      expect(result.shouldShow, isFalse);
      expect(
        result.reason,
        FeatureNoiseReductionReason.hideContextUntilEvidence,
      );
    });

    test('archive health hidden before 5 eligible entries', () {
      final result = FeatureNoiseReduction.build(
        _input(
          surfaceType: FeatureSurfaceType.archiveHealth,
          eligibleEntryCount: 4,
        ),
      );
      expect(result.shouldShow, isFalse);
      expect(
        result.reason,
        FeatureNoiseReductionReason.hideArchiveHealthUntilEvidence,
      );
    });

    test('quick actions hidden before 5 eligible entries', () {
      final result = FeatureNoiseReduction.build(
        _input(
          surfaceType: FeatureSurfaceType.quickActions,
          eligibleEntryCount: 4,
        ),
      );
      expect(result.shouldShow, isFalse);
      expect(
        result.reason,
        FeatureNoiseReductionReason.hideQuickActionsUntilEvidence,
      );
    });

    test('quick actions hidden without first proof', () {
      final result = FeatureNoiseReduction.build(
        _input(
          surfaceType: FeatureSurfaceType.quickActions,
          hasFirstUsefulProof: false,
        ),
      );
      expect(result.shouldShow, isFalse);
      expect(
        result.reason,
        FeatureNoiseReductionReason.hideQuickActionsUntilEvidence,
      );
    });

    test('action items hidden without user intent', () {
      final result = FeatureNoiseReduction.build(
        _input(
          surfaceType: FeatureSurfaceType.actionItems,
          userAskedForSurface: false,
        ),
      );
      expect(result.shouldShow, isFalse);
      expect(
        result.reason,
        FeatureNoiseReductionReason.hideActionItemsUntilUserIntent,
      );
    });

    test('weekly report hidden before longer trail', () {
      final result = FeatureNoiseReduction.build(
        _input(
          surfaceType: FeatureSurfaceType.weeklyReport,
          hasLongerTrail: false,
        ),
      );
      expect(result.shouldShow, isFalse);
      expect(
        result.reason,
        FeatureNoiseReductionReason.hideReportsUntilEvidence,
      );
    });

    test('monthly report hidden before longer trail', () {
      final result = FeatureNoiseReduction.build(
        _input(
          surfaceType: FeatureSurfaceType.monthlyReport,
          hasLongerTrail: false,
        ),
      );
      expect(result.shouldShow, isFalse);
      expect(
        result.reason,
        FeatureNoiseReductionReason.hideReportsUntilEvidence,
      );
    });

    test('private report hidden before longer trail', () {
      final result = FeatureNoiseReduction.build(
        _input(
          surfaceType: FeatureSurfaceType.privateReport,
          hasLongerTrail: false,
        ),
      );
      expect(result.shouldShow, isFalse);
      expect(
        result.reason,
        FeatureNoiseReductionReason.hideReportsUntilEvidence,
      );
    });

    test('archive review hidden before 5 entries', () {
      final result = FeatureNoiseReduction.build(
        _input(
          surfaceType: FeatureSurfaceType.archiveReview,
          eligibleEntryCount: 4,
        ),
      );
      expect(result.shouldShow, isFalse);
      expect(result.reason, FeatureNoiseReductionReason.hideSecondarySurface);
    });

    test('archive review hidden before first proof', () {
      final result = FeatureNoiseReduction.build(
        _input(
          surfaceType: FeatureSurfaceType.archiveReview,
          hasFirstUsefulProof: false,
        ),
      );
      expect(result.shouldShow, isFalse);
      expect(result.reason, FeatureNoiseReductionReason.hideSecondarySurface);
    });

    test('workspace hint hidden when competing with first proof journey', () {
      final result = FeatureNoiseReduction.build(
        _input(
          surfaceType: FeatureSurfaceType.workspaceHint,
          hasFirstUsefulProof: true,
          hasLongerTrail: false,
        ),
      );
      expect(result.shouldShow, isFalse);
      expect(result.reason, FeatureNoiseReductionReason.hideSecondarySurface);
    });

    test('fallback hides secondary surface', () {
      final result = FeatureNoiseReduction.build(
        _input(surfaceType: FeatureSurfaceType.acquisitionWedge),
      );
      expect(result.shouldShow, isFalse);
      expect(result.reason, FeatureNoiseReductionReason.hideSecondarySurface);
    });
  });

  group('FeatureNoiseReductionCopy', () {
    test('headline says keep first journey clear', () {
      expect(
        FeatureNoiseReductionCopy.headline,
        'Keep the first journey clear',
      );
    });

    test(
      'body includes save a repeat / first proof / correct / longer trail',
      () {
        final body = FeatureNoiseReductionCopy.body.toLowerCase();
        expect(body, contains('save a repeat'));
        expect(body, contains('first proof'));
        expect(body, contains('correct'));
        expect(body, contains('longer trail'));
      },
    );

    test(
      'coreJourneyLine lists record/first proof/why/confirm/correct/longer trail/Pro',
      () {
        final line = FeatureNoiseReductionCopy.coreJourneyLine.toLowerCase();
        expect(line, contains('record'));
        expect(line, contains('first proof'));
        expect(line, contains('why it appeared'));
        expect(line, contains('confirm or correct'));
        expect(line, contains('longer trail'));
        expect(line, contains('pro'));
      },
    );

    test(
      'hideEarlyLine includes reports/action items/archive health/context detail/quick actions/review surfaces',
      () {
        final line = FeatureNoiseReductionCopy.hideEarlyLine.toLowerCase();
        expect(line, contains('reports'));
        expect(line, contains('action items'));
        expect(line, contains('archive health'));
        expect(line, contains('context detail'));
        expect(line, contains('quick actions'));
        expect(line, contains('review surfaces'));
      },
    );

    test('notDeletedLine says hidden does not mean removed', () {
      expect(
        FeatureNoiseReductionCopy.notDeletedLine,
        contains('Hidden does not mean removed'),
      );
    });

    test('lowEffortLine says quiet proof trail', () {
      expect(
        FeatureNoiseReductionCopy.lowEffortLine,
        contains('quiet proof trail'),
      );
    });

    test('proLine says Pro focused on longer trail', () {
      expect(
        FeatureNoiseReductionCopy.proLine,
        contains('keeping the longer trail'),
      );
    });

    test(
      'guardrail says secondary surfaces must not compete with first proof journey',
      () {
        expect(
          FeatureNoiseReductionCopy.guardrail,
          contains('secondary surfaces compete with the first proof journey'),
        );
      },
    );

    test('copy does not say better than ChatGPT', () {
      for (final text in FeatureNoiseReductionCopy.allVisibleStrings()) {
        final lower = text.toLowerCase();
        expect(lower.contains('better than chatgpt'), isFalse, reason: text);
        expect(lower.contains('better chatgpt'), isFalse, reason: text);
      }
    });

    test('copy does not position ArchiveMe as voice chat', () {
      for (final text in FeatureNoiseReductionCopy.allVisibleStrings()) {
        final lower = text.toLowerCase();
        expect(lower.contains('voice chat'), isFalse, reason: text);
        expect(lower.contains('voice assistant'), isFalse, reason: text);
      }
    });

    test('copy does not introduce ranking or importance scoring', () {
      for (final text in FeatureNoiseReductionCopy.allVisibleStrings()) {
        final lower = text.toLowerCase();
        expect(lower.contains('ranking'), isFalse, reason: text);
        expect(lower.contains('importance score'), isFalse, reason: text);
      }
    });

    test('copy avoids therapy diagnosis coaching and advice claims', () {
      for (final text in FeatureNoiseReductionCopy.allVisibleStrings()) {
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
        'lib/features/feature_noise_reduction/feature_noise_reduction.dart',
        'lib/features/feature_noise_reduction/feature_noise_reduction_copy.dart',
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
        StoreReadinessProof.resolve(
          const StoreReadinessProofInput(
            revenueCatApiKeyProvided: true,
            revenueCatConfigured: true,
            productsLoaded: true,
            proEntitlementConfigured: true,
            purchaseFlowReachable: true,
            restorePurchasesReachable: true,
            restoreNoCrashVerified: true,
            purchasesUnavailableFallbackVerified: true,
            proStateCanBeRead: true,
            supportUrlSet: true,
            privacyUrlSet: true,
            appStoreMetadataReady: true,
            screenshotsReady: true,
            physicalDeviceSmokePassed: true,
            testFlightUploadReady: true,
            secretsRotated: true,
          ),
        ).status,
        StoreReadinessProofStatus.readyForSubmission,
      );
      expect(
        TrailLanguageGuard.isAllowedCopy(
          'ArchiveMe keeps your proof trail over time.',
        ).isAllowed,
        isTrue,
      );
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
