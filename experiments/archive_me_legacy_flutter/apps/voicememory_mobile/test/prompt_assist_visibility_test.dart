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
import 'package:voicememory_mobile/features/prompt_assist_visibility/prompt_assist_visibility.dart';
import 'package:voicememory_mobile/features/prompt_assist_visibility/prompt_assist_visibility_copy.dart';
import 'package:voicememory_mobile/features/proof_detail_repair/proof_detail_repair_copy.dart';
import 'package:voicememory_mobile/features/proof_selection/proof_selection_principle.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_engine.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_model.dart';

const _safePhrase = 'said yes when I had no capacity';

PromptAssistVisibilityInput _input({
  PromptAssistVisibilitySurface surface =
      PromptAssistVisibilitySurface.recordReady,
  bool hasSafeRepeat = true,
  String hasSafeRepeatPhrase = _safePhrase,
  bool hasEnoughArchiveSignal = true,
  bool userHasSavedFirstMoment = false,
  bool userHasFirstUsefulProof = false,
  bool userRecentlyCorrectedProof = false,
  bool isPrivateRawText = false,
  bool userAskedForHelpWhatToSay = false,
  bool isDailyPrompt = false,
  bool isChatLike = false,
}) => PromptAssistVisibilityInput(
  surface: surface,
  hasSafeRepeat: hasSafeRepeat,
  hasSafeRepeatPhrase: hasSafeRepeatPhrase,
  hasEnoughArchiveSignal: hasEnoughArchiveSignal,
  userHasSavedFirstMoment: userHasSavedFirstMoment,
  userHasFirstUsefulProof: userHasFirstUsefulProof,
  userRecentlyCorrectedProof: userRecentlyCorrectedProof,
  isPrivateRawText: isPrivateRawText,
  userAskedForHelpWhatToSay: userAskedForHelpWhatToSay,
  isDailyPrompt: isDailyPrompt,
  isChatLike: isChatLike,
);

void main() {
  group('PromptAssistVisibility.build', () {
    test('private raw text hides prompt', () {
      final result = PromptAssistVisibility.build(
        _input(isPrivateRawText: true),
      );
      expect(result.shouldShow, isFalse);
      expect(result.reason, PromptAssistVisibilityReason.hidePrivateRawText);
    });

    test('recent correction hides prompt', () {
      final result = PromptAssistVisibility.build(
        _input(userRecentlyCorrectedProof: true),
      );
      expect(result.shouldShow, isFalse);
      expect(result.reason, PromptAssistVisibilityReason.hideAfterCorrection);
    });

    test('daily prompt hides prompt', () {
      final result = PromptAssistVisibility.build(_input(isDailyPrompt: true));
      expect(result.shouldShow, isFalse);
      expect(result.reason, PromptAssistVisibilityReason.hideDailyPrompt);
    });

    test('chat-like prompt hides prompt', () {
      final result = PromptAssistVisibility.build(_input(isChatLike: true));
      expect(result.shouldShow, isFalse);
      expect(result.reason, PromptAssistVisibilityReason.hideChatLike);
    });

    test('correction mode hides prompt', () {
      final result = PromptAssistVisibility.build(
        _input(surface: PromptAssistVisibilitySurface.correctionMode),
      );
      expect(result.shouldShow, isFalse);
      expect(result.reason, PromptAssistVisibilityReason.hideAfterCorrection);
    });

    test('watchOnly hides prompt', () {
      final result = PromptAssistVisibility.build(
        _input(surface: PromptAssistVisibilitySurface.watchOnly),
      );
      expect(result.shouldShow, isFalse);
      expect(result.reason, PromptAssistVisibilityReason.hideWatchOnly);
    });

    test('user asking what to say shows prompt', () {
      final result = PromptAssistVisibility.build(
        _input(
          userAskedForHelpWhatToSay: true,
          hasSafeRepeat: false,
          hasEnoughArchiveSignal: false,
        ),
      );
      expect(result.shouldShow, isTrue);
      expect(result.reason, PromptAssistVisibilityReason.showUserAskedForHelp);
    });

    test(
      'safe repeat with phrase and enough signal shows safe repeat prompt',
      () {
        final result = PromptAssistVisibility.build(_input());
        expect(result.shouldShow, isTrue);
        expect(
          result.reason,
          PromptAssistVisibilityReason.showSafeRepeatPrompt,
        );
      },
    );

    test('safe repeat prompt starts with Try one sentence about', () {
      final result = PromptAssistVisibility.build(_input());
      expect(
        result.promptText,
        startsWith(PromptAssistVisibilityCopy.safeRepeatLine),
      );
    });

    test('safe repeat prompt includes safe phrase', () {
      final result = PromptAssistVisibility.build(_input());
      expect(result.promptText, contains(_safePhrase));
    });

    test('first session shows fallback', () {
      final result = PromptAssistVisibility.build(
        _input(
          surface: PromptAssistVisibilitySurface.firstSession,
          hasSafeRepeat: false,
          hasEnoughArchiveSignal: false,
        ),
      );
      expect(result.shouldShow, isTrue);
      expect(
        result.reason,
        PromptAssistVisibilityReason.showFirstSessionFallback,
      );
    });

    test('record ready shows fallback', () {
      final result = PromptAssistVisibility.build(
        _input(hasSafeRepeat: false, hasEnoughArchiveSignal: false),
      );
      expect(result.shouldShow, isTrue);
      expect(
        result.reason,
        PromptAssistVisibilityReason.showRecordReadyFallback,
      );
    });

    test('fallback prompt says What repeated today', () {
      final result = PromptAssistVisibility.build(
        _input(
          surface: PromptAssistVisibilitySurface.firstSession,
          hasSafeRepeat: false,
          hasEnoughArchiveSignal: false,
        ),
      );
      expect(result.promptText, PromptAssistVisibilityCopy.fallbackLine);
    });

    test(
      'no safe signal fallback hides outside first/record/user-help contexts',
      () {
        final result = PromptAssistVisibility.build(
          _input(
            surface: PromptAssistVisibilitySurface.returningUser,
            hasSafeRepeat: false,
            hasEnoughArchiveSignal: false,
          ),
        );
        expect(result.shouldShow, isFalse);
        expect(result.reason, PromptAssistVisibilityReason.hideNoSafeSignal);
      },
    );
  });

  group('PromptAssistVisibilityCopy', () {
    test('headline says Not sure what to say', () {
      expect(PromptAssistVisibilityCopy.headline, 'Not sure what to say?');
    });

    test('body says suggest one small prompt', () {
      expect(
        PromptAssistVisibilityCopy.body,
        contains('suggest one small prompt'),
      );
    });

    test('body says one real sentence', () {
      expect(PromptAssistVisibilityCopy.body, contains('one real sentence'));
    });

    test('safeRepeatLine says Try one sentence about', () {
      expect(
        PromptAssistVisibilityCopy.safeRepeatLine,
        'Try one sentence about:',
      );
    });

    test('fallbackLine says What repeated today', () {
      expect(PromptAssistVisibilityCopy.fallbackLine, 'What repeated today?');
    });

    test('whyLine says save the repeat without turning into chat', () {
      expect(
        PromptAssistVisibilityCopy.whyLine,
        contains('save the repeat without turning this into chat'),
      );
    });

    test('archiveSignalLine says safe archive signals', () {
      expect(
        PromptAssistVisibilityCopy.archiveSignalLine,
        contains('safe archive signals'),
      );
    });

    test('archiveSignalLine says not private raw journal text', () {
      expect(
        PromptAssistVisibilityCopy.archiveSignalLine,
        contains('not private raw journal text'),
      );
    });

    test('lowEffortLine says one sentence is enough', () {
      expect(
        PromptAssistVisibilityCopy.lowEffortLine,
        contains('One sentence is enough'),
      );
    });

    test('notChatLine says not a conversation', () {
      expect(
        PromptAssistVisibilityCopy.notChatLine,
        contains('not a conversation'),
      );
    });

    test('notChatLine says quick way to save proof', () {
      expect(
        PromptAssistVisibilityCopy.notChatLine,
        contains('quick way to save proof'),
      );
    });

    test('guardrail blocks chat', () {
      expect(PromptAssistVisibilityCopy.guardrail, contains('chat'));
      expect(
        PromptAssistVisibilityCopy.guardrail,
        contains('without becoming chat'),
      );
    });

    test('guardrail blocks advice', () {
      expect(PromptAssistVisibilityCopy.guardrail, contains('advice'));
    });

    test('guardrail blocks coaching', () {
      expect(PromptAssistVisibilityCopy.guardrail, contains('coaching'));
    });

    test('guardrail blocks required daily check-in', () {
      expect(
        PromptAssistVisibilityCopy.guardrail,
        contains('required daily check-in'),
      );
    });

    test('copy does not say better than ChatGPT', () {
      for (final text in PromptAssistVisibilityCopy.allVisibleStrings()) {
        final lower = text.toLowerCase();
        expect(lower.contains('better than chatgpt'), isFalse, reason: text);
        expect(lower.contains('better chatgpt'), isFalse, reason: text);
      }
    });

    test('copy does not position ArchiveMe as voice chat', () {
      for (final text in PromptAssistVisibilityCopy.allVisibleStrings()) {
        final lower = text.toLowerCase();
        expect(lower.contains('voice chat'), isFalse, reason: text);
        expect(lower.contains('voice assistant'), isFalse, reason: text);
      }
    });

    test('copy does not introduce ranking or importance scoring', () {
      for (final text in PromptAssistVisibilityCopy.allVisibleStrings()) {
        final lower = text.toLowerCase();
        expect(lower.contains('ranking'), isFalse, reason: text);
        expect(lower.contains('importance score'), isFalse, reason: text);
      }
    });

    test('copy avoids therapy diagnosis coaching and advice claims', () {
      for (final text in PromptAssistVisibilityCopy.allVisibleStrings()) {
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
        'lib/features/prompt_assist_visibility/prompt_assist_visibility.dart',
        'lib/features/prompt_assist_visibility/prompt_assist_visibility_copy.dart',
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
