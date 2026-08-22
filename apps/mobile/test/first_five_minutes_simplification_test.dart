import 'dart:io';

import 'package:archiveme_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:archiveme_mobile/features/change_trail_clarity/change_trail_clarity.dart';
import 'package:archiveme_mobile/features/context_trail_clarity/context_trail_clarity.dart';
import 'package:archiveme_mobile/features/core_archive_journey/core_archive_journey.dart';
import 'package:archiveme_mobile/features/feature_noise_reduction/feature_noise_reduction.dart';
import 'package:archiveme_mobile/features/first_five_minutes/first_five_minutes_simplification.dart';
import 'package:archiveme_mobile/features/first_five_minutes/first_five_minutes_simplification_copy.dart';
import 'package:archiveme_mobile/features/positive_archive_reinforcement/positive_archive_reinforcement.dart';
import 'package:archiveme_mobile/features/preserved_proof_value/preserved_proof_value.dart';
import 'package:archiveme_mobile/features/proof_detail_repair/proof_detail_repair_copy.dart';
import 'package:archiveme_mobile/features/proof_selection/proof_selection_principle.dart';
import 'package:archiveme_mobile/features/proof_trail_positioning/proof_trail_positioning.dart';
import 'package:archiveme_mobile/features/save_a_repeat_habit/save_a_repeat_habit.dart';
import 'package:archiveme_mobile/features/store_readiness_proof/store_readiness_proof.dart';
import 'package:archiveme_mobile/features/surface_priority/surface_priority_engine.dart';
import 'package:archiveme_mobile/features/surface_priority/surface_priority_model.dart';
import 'package:archiveme_mobile/features/trail_language_guard/trail_language_guard.dart';
import 'package:flutter_test/flutter_test.dart';

FirstFiveMinutesInput _input({
  FirstFiveMinutesSurface surface = FirstFiveMinutesSurface.recordCapture,
  int minuteIndex = 2,
  bool hasSavedFirstMoment = false,
  bool hasSavedSecondMoment = false,
  bool hasFirstUsefulProof = false,
  bool hasUserAskedForSurface = false,
  bool isStoreReadinessMode = false,
  bool isPostSave = false,
  bool userFeelsConfused = false,
}) => FirstFiveMinutesInput(
  surface: surface,
  minuteIndex: minuteIndex,
  hasSavedFirstMoment: hasSavedFirstMoment,
  hasSavedSecondMoment: hasSavedSecondMoment,
  hasFirstUsefulProof: hasFirstUsefulProof,
  hasUserAskedForSurface: hasUserAskedForSurface,
  isStoreReadinessMode: isStoreReadinessMode,
  isPostSave: isPostSave,
  userFeelsConfused: userFeelsConfused,
);

void main() {
  group('FirstFiveMinutesSimplification.build', () {
    test('one-line positioning shows in first five minutes', () {
      final result = FirstFiveMinutesSimplification.build(
        _input(surface: FirstFiveMinutesSurface.oneLinePositioning),
      );
      expect(result.shouldShow, isTrue);
      expect(result.reason, FirstFiveMinutesReason.showOneLinePositioning);
    });

    test('save repeat prompt shows before first save', () {
      final result = FirstFiveMinutesSimplification.build(
        _input(surface: FirstFiveMinutesSurface.saveRepeatPrompt),
      );
      expect(result.shouldShow, isTrue);
      expect(result.reason, FirstFiveMinutesReason.showSaveRepeatPrompt);
    });

    test('record capture always shows', () {
      final result = FirstFiveMinutesSimplification.build(
        _input(),
      );
      expect(result.shouldShow, isTrue);
      expect(result.reason, FirstFiveMinutesReason.showCapture);
    });

    test('type instead allowed', () {
      final result = FirstFiveMinutesSimplification.build(
        _input(surface: FirstFiveMinutesSurface.typeInstead),
      );
      expect(result.shouldShow, isTrue);
      expect(result.reason, FirstFiveMinutesReason.showCapture);
    });

    test('prompt assist shows before capture', () {
      final result = FirstFiveMinutesSimplification.build(
        _input(surface: FirstFiveMinutesSurface.promptAssist),
      );
      expect(result.shouldShow, isTrue);
      expect(result.reason, FirstFiveMinutesReason.showPromptAssist);
    });

    test('positive reinforcement shows post-save', () {
      final result = FirstFiveMinutesSimplification.build(
        _input(
          surface: FirstFiveMinutesSurface.positiveReinforcement,
          isPostSave: true,
        ),
      );
      expect(result.shouldShow, isTrue);
      expect(result.reason, FirstFiveMinutesReason.showPositiveReinforcement);
    });

    test('saved matters shows after first save', () {
      final result = FirstFiveMinutesSimplification.build(
        _input(
          surface: FirstFiveMinutesSurface.savedMatters,
          hasSavedFirstMoment: true,
        ),
      );
      expect(result.shouldShow, isTrue);
      expect(result.reason, FirstFiveMinutesReason.showSavedMatters);
    });

    test('what happens next shows after first save', () {
      final result = FirstFiveMinutesSimplification.build(
        _input(
          surface: FirstFiveMinutesSurface.whatHappensNext,
          hasSavedFirstMoment: true,
        ),
      );
      expect(result.shouldShow, isTrue);
      expect(result.reason, FirstFiveMinutesReason.showWhatHappensNext);
    });

    test('first proof preview can show after first save', () {
      final result = FirstFiveMinutesSimplification.build(
        _input(
          surface: FirstFiveMinutesSurface.firstProofPreview,
          hasSavedFirstMoment: true,
        ),
      );
      expect(result.shouldShow, isTrue);
      expect(
        result.reason,
        FirstFiveMinutesReason.showFirstProofPreviewAfterSave,
      );
    });

    test('first proof preview does not imply proof exists', () {
      final result = FirstFiveMinutesSimplification.build(
        _input(
          surface: FirstFiveMinutesSurface.firstProofPreview,
          hasSavedFirstMoment: true,
        ),
      );
      final preview = FirstFiveMinutesSimplification.previewCopyFor(result);
      expect(preview, contains('can show the first useful proof'));
      expect(
        FirstFiveMinutesSimplificationCopy.previewImpliesProofExists(preview),
        isFalse,
      );
    });

    test('Pro explanation hidden before first useful proof', () {
      final result = FirstFiveMinutesSimplification.build(
        _input(surface: FirstFiveMinutesSurface.proExplanation),
      );
      expect(result.shouldShow, isFalse);
      expect(result.reason, FirstFiveMinutesReason.hidePaywallTooEarly);
    });

    test('paywall hidden before first useful proof', () {
      final result = FirstFiveMinutesSimplification.build(
        _input(surface: FirstFiveMinutesSurface.paywall),
      );
      expect(result.shouldShow, isFalse);
      expect(result.reason, FirstFiveMinutesReason.hidePaywallTooEarly);
    });

    test('context detail hidden unless user asked', () {
      final result = FirstFiveMinutesSimplification.build(
        _input(surface: FirstFiveMinutesSurface.contextDetail),
      );
      expect(result.shouldShow, isFalse);
      expect(result.reason, FirstFiveMinutesReason.hideContextTooEarly);
    });

    test('archive health hidden', () {
      final result = FirstFiveMinutesSimplification.build(
        _input(surface: FirstFiveMinutesSurface.archiveHealth),
      );
      expect(result.shouldShow, isFalse);
      expect(result.reason, FirstFiveMinutesReason.hideReportsTooEarly);
    });

    test('action items hidden unless user asked', () {
      final result = FirstFiveMinutesSimplification.build(
        _input(surface: FirstFiveMinutesSurface.actionItems),
      );
      expect(result.shouldShow, isFalse);
      expect(result.reason, FirstFiveMinutesReason.hideActionItemsTooEarly);
    });

    test('reports hidden', () {
      final result = FirstFiveMinutesSimplification.build(
        _input(surface: FirstFiveMinutesSurface.reports),
      );
      expect(result.shouldShow, isFalse);
      expect(result.reason, FirstFiveMinutesReason.hideReportsTooEarly);
    });

    test('quick actions hidden', () {
      final result = FirstFiveMinutesSimplification.build(
        _input(surface: FirstFiveMinutesSurface.quickActions),
      );
      expect(result.shouldShow, isFalse);
      expect(result.reason, FirstFiveMinutesReason.hideFeatureNoise);
    });

    test('workspace hidden unless user asked', () {
      final result = FirstFiveMinutesSimplification.build(
        _input(surface: FirstFiveMinutesSurface.workspace),
      );
      expect(result.shouldShow, isFalse);
      expect(result.reason, FirstFiveMinutesReason.hideWorkspaceTooEarly);
    });

    test('debug readiness shows only in storeReadinessMode', () {
      final hidden = FirstFiveMinutesSimplification.build(
        _input(surface: FirstFiveMinutesSurface.debugReadiness),
      );
      expect(hidden.shouldShow, isFalse);

      final shown = FirstFiveMinutesSimplification.build(
        _input(
          surface: FirstFiveMinutesSurface.debugReadiness,
          isStoreReadinessMode: true,
        ),
      );
      expect(shown.shouldShow, isTrue);
      expect(shown.reason, FirstFiveMinutesReason.showDebugReadiness);
    });

    test('fallback hides feature noise', () {
      final result = FirstFiveMinutesSimplification.build(
        _input(surface: FirstFiveMinutesSurface.reports),
      );
      expect(result.shouldShow, isFalse);
      expect(result.reason, FirstFiveMinutesReason.hideReportsTooEarly);
    });
  });

  group('FirstFiveMinutesSimplificationCopy', () {
    test('headline says Save one repeat', () {
      expect(FirstFiveMinutesSimplificationCopy.headline, 'Save one repeat');
    });

    test('body says when something repeats, save one real sentence', () {
      expect(
        FirstFiveMinutesSimplificationCopy.body,
        contains('when something repeats, save one real sentence'),
      );
    });

    test('body says archive compares it later', () {
      expect(
        FirstFiveMinutesSimplificationCopy.body,
        contains('archive compares it later'),
      );
    });

    test('oneLinePositioning says ArchiveMe shows what keeps coming back', () {
      expect(
        FirstFiveMinutesSimplificationCopy.oneLinePositioning,
        'ArchiveMe shows what keeps coming back.',
      );
    });

    test('whenToUseLine includes felt/done/avoided/checked before', () {
      final line = FirstFiveMinutesSimplificationCopy.whenToUseLine
          .toLowerCase();
      expect(line, contains('felt this before'));
      expect(line, contains('done this before'));
      expect(line, contains('avoided this before'));
      expect(line, contains('checked this before'));
    });

    test('oneSentenceLine says one real sentence is enough', () {
      expect(
        FirstFiveMinutesSimplificationCopy.oneSentenceLine,
        'One real sentence is enough.',
      );
    });

    test(
      'savedMattersLine says saved moments give archive something real to compare',
      () {
        expect(
          FirstFiveMinutesSimplificationCopy.savedMattersLine,
          contains('give your archive something real to compare'),
        );
      },
    );

    test(
      'whatHappensNextLine says after enough real moments ArchiveMe can show first useful proof',
      () {
        expect(
          FirstFiveMinutesSimplificationCopy.whatHappensNextLine,
          contains(
            'After enough real moments, ArchiveMe can show the first useful proof',
          ),
        );
      },
    );

    test('notNowLine blocks reports/dashboards/action items/context work', () {
      final line = FirstFiveMinutesSimplificationCopy.notNowLine.toLowerCase();
      expect(line, contains('no reports'));
      expect(line, contains('dashboards'));
      expect(line, contains('action items'));
      expect(line, contains('context work'));
    });

    test('notChatLine distinguishes ChatGPT from ArchiveMe evidence trail', () {
      expect(
        FirstFiveMinutesSimplificationCopy.notChatLine,
        contains('ChatGPT can suggest what to do'),
      );
      expect(
        FirstFiveMinutesSimplificationCopy.notChatLine,
        contains('ArchiveMe shows what you already said before'),
      );
    });

    test('notStorageLine says not store everything', () {
      expect(
        FirstFiveMinutesSimplificationCopy.notStorageLine,
        contains('not where you store everything'),
      );
    });

    test('notStorageLine says save what repeats', () {
      expect(
        FirstFiveMinutesSimplificationCopy.notStorageLine,
        contains('save what repeats'),
      );
    });

    test(
      'guardrail says first five minutes focus only on saving one repeat and comparing later',
      () {
        expect(
          FirstFiveMinutesSimplificationCopy.guardrail,
          contains('focus only on saving one repeat'),
        );
        expect(
          FirstFiveMinutesSimplificationCopy.guardrail,
          contains('compares it later'),
        );
      },
    );

    test('copy does not say better than ChatGPT', () {
      for (final text
          in FirstFiveMinutesSimplificationCopy.allVisibleStrings()) {
        final lower = text.toLowerCase();
        expect(lower.contains('better than chatgpt'), isFalse, reason: text);
        expect(lower.contains('better chatgpt'), isFalse, reason: text);
      }
    });

    test('copy does not position ArchiveMe as voice chat', () {
      for (final text
          in FirstFiveMinutesSimplificationCopy.allVisibleStrings()) {
        final lower = text.toLowerCase();
        expect(lower.contains('voice chat'), isFalse, reason: text);
        expect(lower.contains('voice assistant'), isFalse, reason: text);
      }
    });

    test('copy does not introduce ranking or importance scoring', () {
      for (final text
          in FirstFiveMinutesSimplificationCopy.allVisibleStrings()) {
        final lower = text.toLowerCase();
        expect(lower.contains('ranking'), isFalse, reason: text);
        expect(lower.contains('importance score'), isFalse, reason: text);
      }
    });

    test('copy avoids therapy diagnosis coaching and advice claims', () {
      for (final text
          in FirstFiveMinutesSimplificationCopy.allVisibleStrings()) {
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
        'lib/features/first_five_minutes/first_five_minutes_simplification.dart',
        'lib/features/first_five_minutes/first_five_minutes_simplification_copy.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source.contains('RevenueCat'), isFalse);
        expect(source.contains('restorePurchases'), isFalse);
        expect(source.contains('billing/'), isFalse);
        expect(source.contains('importance_scoring'), isFalse);
        expect(source.contains('anchor_specificity_guard'), isFalse);
        expect(source.contains('journal_storage'), isFalse);
        expect(source.contains('paywall_source'), isFalse);
      }
    });

    test('existing modules behaviour unchanged', () {
      expect(
        FeatureNoiseReduction.build(
          const FeatureNoiseReductionInput(
            surfaceType: FeatureSurfaceType.recordCapture,
            eligibleEntryCount: 5,
            hasFirstUsefulProof: true,
            hasConfirmedRepeat: true,
            hasLongerTrail: true,
            hasUserCorrection: false,
            isFirstSession: false,
            isRecordScreen: false,
            isPostSave: false,
            userAskedForSurface: false,
            storeReadinessMode: false,
          ),
        ).reason,
        FeatureNoiseReductionReason.showCoreCapture,
      );
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