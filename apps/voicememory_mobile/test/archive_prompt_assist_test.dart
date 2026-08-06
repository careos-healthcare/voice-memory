import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_prompt_assist/archive_prompt_assist.dart';
import 'package:voicememory_mobile/features/archive_prompt_assist/archive_prompt_assist_copy.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/change_trail_clarity/change_trail_clarity.dart';
import 'package:voicememory_mobile/features/core_archive_journey/core_archive_journey.dart';
import 'package:voicememory_mobile/features/low_effort_archive_capture/low_effort_archive_capture.dart';
import 'package:voicememory_mobile/features/proof_detail_repair/proof_detail_repair_copy.dart';
import 'package:voicememory_mobile/features/proof_selection/proof_selection_principle.dart';
import 'package:voicememory_mobile/features/release_candidate_comprehension/release_candidate_comprehension.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_engine.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_model.dart';

const _safePhrase = 'said yes when I had no capacity';

ArchivePromptAssistInput _input({
  bool hasSafeRepeat = true,
  String safeRepeatPhrase = _safePhrase,
  bool hasEnoughArchiveSignal = true,
  bool userRecentlyCorrectedProof = false,
  bool isWatchOnly = false,
  bool isGenericOrRejected = false,
  bool isPrivateRawText = false,
}) => ArchivePromptAssistInput(
  hasSafeRepeat: hasSafeRepeat,
  safeRepeatPhrase: safeRepeatPhrase,
  hasEnoughArchiveSignal: hasEnoughArchiveSignal,
  userRecentlyCorrectedProof: userRecentlyCorrectedProof,
  isWatchOnly: isWatchOnly,
  isGenericOrRejected: isGenericOrRejected,
  isPrivateRawText: isPrivateRawText,
);

void main() {
  group('ArchivePromptAssist.build', () {
    test('safe repeat with enough signal shows prompt', () {
      final result = ArchivePromptAssist.build(_input());
      expect(result.shouldShowPrompt, isTrue);
      expect(result.reason, ArchivePromptAssistReason.safeRepeatPrompt);
    });

    test('prompt text starts with Try one sentence about', () {
      final result = ArchivePromptAssist.build(_input());
      expect(
        result.promptText,
        startsWith(ArchivePromptAssistCopy.safeRepeatPromptPrefix),
      );
    });

    test('prompt includes safe repeat phrase', () {
      final result = ArchivePromptAssist.build(_input());
      expect(result.promptText, contains(_safePhrase));
    });

    test('no safe repeat shows fallback What repeated today', () {
      final result = ArchivePromptAssist.build(
        _input(hasSafeRepeat: false, hasEnoughArchiveSignal: false),
      );
      expect(result.shouldShowPrompt, isTrue);
      expect(result.promptText, ArchivePromptAssistCopy.fallbackPrompt);
      expect(result.reason, ArchivePromptAssistReason.fallbackRepeatPrompt);
    });

    test('recently corrected proof hides prompt', () {
      final result = ArchivePromptAssist.build(
        _input(userRecentlyCorrectedProof: true),
      );
      expect(result.shouldShowPrompt, isFalse);
      expect(result.reason, ArchivePromptAssistReason.hiddenAfterCorrection);
    });

    test('private raw text hides prompt', () {
      final result = ArchivePromptAssist.build(_input(isPrivateRawText: true));
      expect(result.shouldShowPrompt, isFalse);
      expect(result.reason, ArchivePromptAssistReason.hiddenPrivateRawText);
    });

    test('watchOnly hides prompt', () {
      final result = ArchivePromptAssist.build(_input(isWatchOnly: true));
      expect(result.shouldShowPrompt, isFalse);
      expect(result.reason, ArchivePromptAssistReason.hiddenWatchOnly);
    });

    test('generic/rejected hides prompt', () {
      final result = ArchivePromptAssist.build(
        _input(isGenericOrRejected: true),
      );
      expect(result.shouldShowPrompt, isFalse);
      expect(result.reason, ArchivePromptAssistReason.hiddenGenericOrRejected);
    });

    test('empty safe phrase falls back safely', () {
      final result = ArchivePromptAssist.build(_input(safeRepeatPhrase: '   '));
      expect(result.shouldShowPrompt, isTrue);
      expect(result.promptText, ArchivePromptAssistCopy.fallbackPrompt);
      expect(result.reason, ArchivePromptAssistReason.fallbackRepeatPrompt);
    });
  });

  group('ArchivePromptAssistCopy', () {
    test('headline asks Not sure what to record', () {
      expect(ArchivePromptAssistCopy.headline, 'Not sure what to record?');
    });

    test('body says suggest a small prompt from what already repeated', () {
      expect(
        ArchivePromptAssistCopy.body,
        contains('suggest a small prompt from what has already repeated'),
      );
    });

    test('body says one sentence is enough', () {
      expect(ArchivePromptAssistCopy.body, contains('One sentence is enough'));
    });

    test('oneSentenceReminder says keep it small', () {
      expect(
        ArchivePromptAssistCopy.oneSentenceReminder,
        contains('Keep it small'),
      );
    });

    test('noChatModeLine says this is not chat', () {
      expect(
        ArchivePromptAssistCopy.noChatModeLine,
        contains('This is not chat'),
      );
    });

    test(
      'archiveBasedLine says safe archive signals, not private raw journal text',
      () {
        expect(
          ArchivePromptAssistCopy.archiveBasedLine,
          contains('safe archive signals'),
        );
        expect(
          ArchivePromptAssistCopy.archiveBasedLine,
          contains('not private raw journal text'),
        );
      },
    );

    test('lowPressureLine says no daily homework', () {
      expect(
        ArchivePromptAssistCopy.lowPressureLine,
        contains('No daily homework'),
      );
    });

    test('lowPressureLine says no mind-map maintenance', () {
      expect(
        ArchivePromptAssistCopy.lowPressureLine,
        contains('No mind-map maintenance'),
      );
    });

    test(
      'chatGptDifferenceLine distinguishes ChatGPT now vs ArchiveMe past repeat',
      () {
        expect(
          ArchivePromptAssistCopy.chatGptDifferenceLine,
          contains('ChatGPT helps you talk now'),
        );
        expect(
          ArchivePromptAssistCopy.chatGptDifferenceLine,
          contains('what keeps coming back'),
        );
      },
    );

    test('guardrail blocks turning prompt assist into chat', () {
      expect(
        ArchivePromptAssistCopy.guardrail,
        contains('Do not turn prompt assist into chat'),
      );
    });

    test('copy does not say better than ChatGPT', () {
      for (final text in [
        ArchivePromptAssistCopy.headline,
        ArchivePromptAssistCopy.body,
        ArchivePromptAssistCopy.oneSentenceReminder,
        ArchivePromptAssistCopy.noChatModeLine,
        ArchivePromptAssistCopy.lowPressureLine,
      ]) {
        final lower = text.toLowerCase();
        expect(lower.contains('better than chatgpt'), isFalse, reason: text);
        expect(lower.contains('better chatgpt'), isFalse, reason: text);
      }
    });

    test('copy does not position ArchiveMe as voice chat', () {
      for (final text in [
        ArchivePromptAssistCopy.headline,
        ArchivePromptAssistCopy.body,
        ArchivePromptAssistCopy.oneSentenceReminder,
        ArchivePromptAssistCopy.lowPressureLine,
      ]) {
        final lower = text.toLowerCase();
        expect(lower.contains('voice chat'), isFalse, reason: text);
        expect(lower.contains('voice assistant'), isFalse, reason: text);
      }
    });

    test('copy does not introduce ranking or importance scoring', () {
      for (final text in ArchivePromptAssistCopy.allVisibleStrings()) {
        final lower = text.toLowerCase();
        expect(lower.contains('ranking'), isFalse, reason: text);
        expect(lower.contains('importance score'), isFalse, reason: text);
      }
    });

    test('copy avoids therapy diagnosis coaching and advice claims', () {
      for (final text in [
        ArchivePromptAssistCopy.headline,
        ArchivePromptAssistCopy.body,
        ArchivePromptAssistCopy.oneSentenceReminder,
        ArchivePromptAssistCopy.noChatModeLine,
        ArchivePromptAssistCopy.archiveBasedLine,
        ArchivePromptAssistCopy.lowPressureLine,
        ArchivePromptAssistCopy.chatGptDifferenceLine,
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
        'lib/features/archive_prompt_assist/archive_prompt_assist.dart',
        'lib/features/archive_prompt_assist/archive_prompt_assist_copy.dart',
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
