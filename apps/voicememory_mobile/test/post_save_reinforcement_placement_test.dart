import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_prompt_assist/archive_prompt_assist.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/change_trail_clarity/change_trail_clarity.dart';
import 'package:voicememory_mobile/features/context_trail_clarity/context_trail_clarity.dart';
import 'package:voicememory_mobile/features/core_archive_journey/core_archive_journey.dart';
import 'package:voicememory_mobile/features/feature_noise_reduction/feature_noise_reduction.dart';
import 'package:voicememory_mobile/features/first_five_minutes/first_five_minutes_simplification.dart';
import 'package:voicememory_mobile/features/positive_archive_reinforcement/positive_archive_reinforcement.dart';
import 'package:voicememory_mobile/features/post_save_reinforcement/post_save_reinforcement_placement.dart';
import 'package:voicememory_mobile/features/post_save_reinforcement/post_save_reinforcement_placement_copy.dart';
import 'package:voicememory_mobile/features/prompt_assist_visibility/prompt_assist_visibility.dart';
import 'package:voicememory_mobile/features/proof_detail_repair/proof_detail_repair_copy.dart';
import 'package:voicememory_mobile/features/proof_selection/proof_selection_principle.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_engine.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_model.dart';

const _safePhrase = 'said yes when I had no capacity';

PostSaveReinforcementPlacementInput _input({
  PostSaveReinforcementPlacementSurface surface =
      PostSaveReinforcementPlacementSurface.afterSimpleSave,
  bool savedMoment = true,
  bool isFirstMoment = false,
  bool isRelatedToPreviousRepeat = false,
  bool hasSafeRepeat = true,
  bool hasEnoughArchiveSignal = true,
  bool userCorrectedProofRecently = false,
  bool isWatchOnly = false,
  bool isPrivateRawText = false,
  bool isPostSave = true,
  bool isRecordScreen = false,
  bool wouldCompeteWithFirstProof = false,
  bool wouldPressureMoreRecording = false,
}) =>
    PostSaveReinforcementPlacementInput(
      surface: surface,
      savedMoment: savedMoment,
      isFirstMoment: isFirstMoment,
      isRelatedToPreviousRepeat: isRelatedToPreviousRepeat,
      hasSafeRepeat: hasSafeRepeat,
      hasEnoughArchiveSignal: hasEnoughArchiveSignal,
      userCorrectedProofRecently: userCorrectedProofRecently,
      isWatchOnly: isWatchOnly,
      isPrivateRawText: isPrivateRawText,
      isPostSave: isPostSave,
      isRecordScreen: isRecordScreen,
      wouldCompeteWithFirstProof: wouldCompeteWithFirstProof,
      wouldPressureMoreRecording: wouldPressureMoreRecording,
    );

void main() {
  group('PostSaveReinforcementPlacement.build', () {
    test('not post-save hides', () {
      final result = PostSaveReinforcementPlacement.build(
        _input(isPostSave: false),
      );
      expect(result.shouldShow, isFalse);
      expect(result.reason, PostSaveReinforcementPlacementReason.hideNotPostSave);
    });

    test('no saved moment hides', () {
      final result = PostSaveReinforcementPlacement.build(
        _input(savedMoment: false),
      );
      expect(result.shouldShow, isFalse);
      expect(result.reason, PostSaveReinforcementPlacementReason.hideNoSavedMoment);
    });

    test('private raw text hides', () {
      final result = PostSaveReinforcementPlacement.build(
        _input(isPrivateRawText: true),
      );
      expect(result.shouldShow, isFalse);
      expect(result.reason, PostSaveReinforcementPlacementReason.hidePrivateRawText);
    });

    test('recent correction hides', () {
      final result = PostSaveReinforcementPlacement.build(
        _input(userCorrectedProofRecently: true),
      );
      expect(result.shouldShow, isFalse);
      expect(result.reason, PostSaveReinforcementPlacementReason.hideAfterCorrection);
    });

    test('correction surface hides', () {
      final result = PostSaveReinforcementPlacement.build(
        _input(surface: PostSaveReinforcementPlacementSurface.afterCorrection),
      );
      expect(result.shouldShow, isFalse);
      expect(result.reason, PostSaveReinforcementPlacementReason.hideAfterCorrection);
    });

    test('watchOnly hides', () {
      final result = PostSaveReinforcementPlacement.build(
        _input(isWatchOnly: true),
      );
      expect(result.shouldShow, isFalse);
      expect(result.reason, PostSaveReinforcementPlacementReason.hideWatchOnly);
    });

    test('competing with first proof hides', () {
      final result = PostSaveReinforcementPlacement.build(
        _input(wouldCompeteWithFirstProof: true),
      );
      expect(result.shouldShow, isFalse);
      expect(
        result.reason,
        PostSaveReinforcementPlacementReason.hideWouldCompeteWithFirstProof,
      );
    });

    test('pressure to record more hides', () {
      final result = PostSaveReinforcementPlacement.build(
        _input(wouldPressureMoreRecording: true),
      );
      expect(result.shouldShow, isFalse);
      expect(
        result.reason,
        PostSaveReinforcementPlacementReason.hideWouldPressureMoreRecording,
      );
    });

    test('first moment shows first moment saved', () {
      final result = PostSaveReinforcementPlacement.build(
        _input(isFirstMoment: true),
      );
      expect(result.shouldShow, isTrue);
      expect(
        result.reason,
        PostSaveReinforcementPlacementReason.showFirstMomentSaved,
      );
    });

    test('repeat-related safe repeat shows repeat-related reinforcement', () {
      final result = PostSaveReinforcementPlacement.build(
        _input(
          isRelatedToPreviousRepeat: true,
          hasSafeRepeat: true,
        ),
      );
      expect(result.shouldShow, isTrue);
      expect(
        result.reason,
        PostSaveReinforcementPlacementReason.showRepeatRelatedMomentSaved,
      );
    });

    test('weak evidence save shows not enough proof yet', () {
      final result = PostSaveReinforcementPlacement.build(
        _input(hasEnoughArchiveSignal: false),
      );
      expect(result.shouldShow, isTrue);
      expect(
        result.reason,
        PostSaveReinforcementPlacementReason.showNotEnoughProofYet,
      );
    });

    test('simple save shows simple moment saved', () {
      final result = PostSaveReinforcementPlacement.build(_input());
      expect(result.shouldShow, isTrue);
      expect(
        result.reason,
        PostSaveReinforcementPlacementReason.showSimpleMomentSaved,
      );
    });
  });

  group('PostSaveReinforcementPlacementCopy', () {
    test('headline says Saved for your archive', () {
      expect(
        PostSaveReinforcementPlacementCopy.headline,
        'Saved for your archive',
      );
    });

    test('body says one moment is enough', () {
      expect(
        PostSaveReinforcementPlacementCopy.body,
        contains('one moment is enough'),
      );
    });

    test('body says ArchiveMe has something real to compare later', () {
      expect(
        PostSaveReinforcementPlacementCopy.body,
        contains('something real to compare later'),
      );
    });

    test('firstMomentLine says one real moment is enough to start your archive',
        () {
      expect(
        PostSaveReinforcementPlacementCopy.firstMomentLine.toLowerCase(),
        contains('one real moment is enough to start your archive'),
      );
    });

    test('simpleMomentLine says gives archive something real to compare later',
        () {
      expect(
        PostSaveReinforcementPlacementCopy.simpleMomentLine,
        contains('gives your archive something real to compare later'),
      );
    });

    test('repeatRelatedLine includes returning changing fading corrected', () {
      expect(
        PostSaveReinforcementPlacementCopy.repeatRelatedLine,
        contains('returning'),
      );
      expect(
        PostSaveReinforcementPlacementCopy.repeatRelatedLine,
        contains('changing'),
      );
      expect(
        PostSaveReinforcementPlacementCopy.repeatRelatedLine,
        contains('fading'),
      );
      expect(
        PostSaveReinforcementPlacementCopy.repeatRelatedLine,
        contains('corrected'),
      );
    });

    test('notEnoughProofLine says no need to force more', () {
      expect(
        PostSaveReinforcementPlacementCopy.notEnoughProofLine.toLowerCase(),
        contains('no need to force more'),
      );
    });

    test('notEnoughProofLine says real moments over time', () {
      expect(
        PostSaveReinforcementPlacementCopy.notEnoughProofLine,
        contains('real moments over time'),
      );
    });

    test('noPressureLine says no daily homework', () {
      expect(
        PostSaveReinforcementPlacementCopy.noPressureLine,
        contains('No daily homework'),
      );
    });

    test('noPressureLine says no streak', () {
      expect(
        PostSaveReinforcementPlacementCopy.noPressureLine,
        contains('No streak'),
      );
    });

    test('noPressureLine says no pressure to record more', () {
      expect(
        PostSaveReinforcementPlacementCopy.noPressureLine.toLowerCase(),
        contains('no pressure to record more'),
      );
    });

    test('nextLine says user can stop here', () {
      expect(
        PostSaveReinforcementPlacementCopy.nextLine,
        contains('stop here'),
      );
    });

    test('nextLine says save another only if something real is still on mind',
        () {
      expect(
        PostSaveReinforcementPlacementCopy.nextLine,
        contains('only if something real is still on your mind'),
      );
    });

    test('guardrail blocks streaks', () {
      expect(PostSaveReinforcementPlacementCopy.guardrail, contains('streaks'));
    });

    test('guardrail blocks pressure', () {
      expect(PostSaveReinforcementPlacementCopy.guardrail, contains('pressure'));
    });

    test('guardrail blocks advice', () {
      expect(PostSaveReinforcementPlacementCopy.guardrail, contains('advice'));
    });

    test('guardrail blocks therapy', () {
      expect(PostSaveReinforcementPlacementCopy.guardrail, contains('therapy'));
    });

    test('guardrail blocks requirement to record more', () {
      expect(
        PostSaveReinforcementPlacementCopy.guardrail,
        contains('requirement to record more'),
      );
    });

    test('copy does not say better than ChatGPT', () {
      for (final text in PostSaveReinforcementPlacementCopy.allVisibleStrings()) {
        final lower = text.toLowerCase();
        expect(lower.contains('better than chatgpt'), isFalse, reason: text);
        expect(lower.contains('better chatgpt'), isFalse, reason: text);
      }
    });

    test('copy does not position ArchiveMe as voice chat', () {
      for (final text in PostSaveReinforcementPlacementCopy.allVisibleStrings()) {
        final lower = text.toLowerCase();
        expect(lower.contains('voice chat'), isFalse, reason: text);
        expect(lower.contains('voice assistant'), isFalse, reason: text);
      }
    });

    test('copy does not introduce ranking or importance scoring', () {
      for (final text in PostSaveReinforcementPlacementCopy.allVisibleStrings()) {
        final lower = text.toLowerCase();
        expect(lower.contains('ranking'), isFalse, reason: text);
        expect(lower.contains('importance score'), isFalse, reason: text);
      }
    });

    test('copy avoids therapy diagnosis coaching and advice claims', () {
      for (final text in PostSaveReinforcementPlacementCopy.allVisibleStrings()) {
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
        'lib/features/post_save_reinforcement/post_save_reinforcement_placement.dart',
        'lib/features/post_save_reinforcement/post_save_reinforcement_placement_copy.dart',
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
        PromptAssistVisibility.build(
          PromptAssistVisibilityInput(
            surface: PromptAssistVisibilitySurface.firstSession,
            hasSafeRepeat: false,
            hasSafeRepeatPhrase: '',
            hasEnoughArchiveSignal: false,
            userHasSavedFirstMoment: false,
            userHasFirstUsefulProof: false,
            userRecentlyCorrectedProof: false,
            isPrivateRawText: false,
            userAskedForHelpWhatToSay: false,
            isDailyPrompt: false,
            isChatLike: false,
          ),
        ).reason,
        PromptAssistVisibilityReason.showFirstSessionFallback,
      );
      expect(
        FirstFiveMinutesSimplification.build(
          const FirstFiveMinutesInput(
            surface: FirstFiveMinutesSurface.promptAssist,
            minuteIndex: 2,
            hasSavedFirstMoment: false,
            hasSavedSecondMoment: false,
            hasFirstUsefulProof: false,
            hasUserAskedForSurface: false,
            isStoreReadinessMode: false,
            isPostSave: false,
            userFeelsConfused: false,
          ),
        ).reason,
        FirstFiveMinutesReason.showPromptAssist,
      );
      expect(
        FeatureNoiseReduction.build(
          const FeatureNoiseReductionInput(
            surfaceType: FeatureSurfaceType.promptAssist,
            eligibleEntryCount: 5,
            hasFirstUsefulProof: true,
            hasConfirmedRepeat: true,
            hasLongerTrail: true,
            hasUserCorrection: false,
            isFirstSession: false,
            isRecordScreen: true,
            isPostSave: false,
            userAskedForSurface: false,
            storeReadinessMode: false,
          ),
        ).reason,
        FeatureNoiseReductionReason.showPromptAssist,
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
            safeRepeatPhrase: _safePhrase,
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
        ChangeTrailClarity.resolve(_fullTrailSummary()),
        ChangeTrailClarityDecision.releaseCandidate,
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
