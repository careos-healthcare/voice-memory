import 'dart:io';

import 'package:archiveme_mobile/features/archive_prompt_assist/archive_prompt_assist.dart';
import 'package:archiveme_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:archiveme_mobile/features/change_trail_clarity/change_trail_clarity.dart';
import 'package:archiveme_mobile/features/core_archive_journey/core_archive_journey.dart';
import 'package:archiveme_mobile/features/low_effort_archive_capture/low_effort_archive_capture.dart';
import 'package:archiveme_mobile/features/positive_archive_reinforcement/positive_archive_reinforcement.dart';
import 'package:archiveme_mobile/features/positive_archive_reinforcement/positive_archive_reinforcement_copy.dart';
import 'package:archiveme_mobile/features/proof_detail_repair/proof_detail_repair_copy.dart';
import 'package:archiveme_mobile/features/proof_selection/proof_selection_principle.dart';
import 'package:archiveme_mobile/features/release_candidate_comprehension/release_candidate_comprehension.dart';
import 'package:archiveme_mobile/features/surface_priority/surface_priority_engine.dart';
import 'package:archiveme_mobile/features/surface_priority/surface_priority_model.dart';
import 'package:flutter_test/flutter_test.dart';

PositiveArchiveReinforcementInput _input({
  bool savedMoment = true,
  bool hasSafeRepeat = true,
  bool hasEnoughArchiveSignal = true,
  bool isFirstMoment = false,
  bool isRelatedToPreviousRepeat = false,
  bool userCorrectedProofRecently = false,
  bool isWatchOnly = false,
  bool isPrivateRawText = false,
}) => PositiveArchiveReinforcementInput(
  savedMoment: savedMoment,
  hasSafeRepeat: hasSafeRepeat,
  hasEnoughArchiveSignal: hasEnoughArchiveSignal,
  isFirstMoment: isFirstMoment,
  isRelatedToPreviousRepeat: isRelatedToPreviousRepeat,
  userCorrectedProofRecently: userCorrectedProofRecently,
  isWatchOnly: isWatchOnly,
  isPrivateRawText: isPrivateRawText,
);

void main() {
  group('PositiveArchiveReinforcement.build', () {
    test('no saved moment hides reinforcement', () {
      final result = PositiveArchiveReinforcement.build(
        _input(savedMoment: false),
      );
      expect(result.shouldShow, isFalse);
      expect(
        result.reason,
        PositiveArchiveReinforcementReason.hiddenNoSavedMoment,
      );
    });

    test('private raw text hides reinforcement', () {
      final result = PositiveArchiveReinforcement.build(
        _input(isPrivateRawText: true),
      );
      expect(result.shouldShow, isFalse);
      expect(
        result.reason,
        PositiveArchiveReinforcementReason.hiddenPrivateRawText,
      );
    });

    test('recent correction hides reinforcement', () {
      final result = PositiveArchiveReinforcement.build(
        _input(userCorrectedProofRecently: true),
      );
      expect(result.shouldShow, isFalse);
      expect(
        result.reason,
        PositiveArchiveReinforcementReason.hiddenAfterCorrection,
      );
    });

    test('watchOnly hides reinforcement', () {
      final result = PositiveArchiveReinforcement.build(
        _input(isWatchOnly: true),
      );
      expect(result.shouldShow, isFalse);
      expect(result.reason, PositiveArchiveReinforcementReason.hiddenWatchOnly);
    });

    test('first moment shows firstMomentSaved', () {
      final result = PositiveArchiveReinforcement.build(
        _input(isFirstMoment: true),
      );
      expect(result.shouldShow, isTrue);
      expect(
        result.reason,
        PositiveArchiveReinforcementReason.firstMomentSaved,
      );
    });

    test('first moment message says one real moment is enough', () {
      final result = PositiveArchiveReinforcement.build(
        _input(isFirstMoment: true),
      );
      expect(result.message, contains('One real moment is enough'));
    });

    test('related safe repeat shows repeatRelatedMomentSaved', () {
      final result = PositiveArchiveReinforcement.build(
        _input(isRelatedToPreviousRepeat: true),
      );
      expect(result.shouldShow, isTrue);
      expect(
        result.reason,
        PositiveArchiveReinforcementReason.repeatRelatedMomentSaved,
      );
    });

    test(
      'related repeat message includes returning/changing/fading/corrected',
      () {
        final result = PositiveArchiveReinforcement.build(
          _input(isRelatedToPreviousRepeat: true),
        );
        final message = result.message.toLowerCase();
        expect(message, contains('returning'));
        expect(message, contains('changing'));
        expect(message, contains('fading'));
        expect(message, contains('corrected'));
      },
    );

    test('not enough proof shows notEnoughProofYet', () {
      final result = PositiveArchiveReinforcement.build(
        _input(hasEnoughArchiveSignal: false),
      );
      expect(result.shouldShow, isTrue);
      expect(
        result.reason,
        PositiveArchiveReinforcementReason.notEnoughProofYet,
      );
    });

    test('not enough proof message says no need to force more', () {
      final result = PositiveArchiveReinforcement.build(
        _input(hasEnoughArchiveSignal: false),
      );
      expect(result.message, contains('No need to force more'));
    });

    test('default saved moment gives compare later message', () {
      final result = PositiveArchiveReinforcement.build(_input());
      expect(result.shouldShow, isTrue);
      expect(
        result.reason,
        PositiveArchiveReinforcementReason.simpleMomentSaved,
      );
      expect(result.message, contains('compare later'));
    });
  });

  group('PositiveArchiveReinforcementCopy', () {
    test('headline says Saved for your archive', () {
      expect(
        PositiveArchiveReinforcementCopy.headline,
        'Saved for your archive',
      );
    });

    test('body says one moment is enough', () {
      expect(
        PositiveArchiveReinforcementCopy.body,
        contains('one moment is enough'),
      );
    });

    test('body says compare later', () {
      expect(PositiveArchiveReinforcementCopy.body, contains('compare later'));
    });

    test('noticedLine says noticed it and saved it', () {
      expect(
        PositiveArchiveReinforcementCopy.noticedLine,
        contains('noticed it and saved it'),
      );
    });

    test('smallMomentLine says small moments make trail clear', () {
      expect(
        PositiveArchiveReinforcementCopy.smallMomentLine,
        contains('Small moments are how the trail becomes clear'),
      );
    });

    test('noHomeworkLine says no daily homework', () {
      expect(
        PositiveArchiveReinforcementCopy.noHomeworkLine,
        contains('No daily homework'),
      );
    });

    test('noHomeworkLine says no streak', () {
      expect(
        PositiveArchiveReinforcementCopy.noHomeworkLine,
        contains('No streak'),
      );
    });

    test('noHomeworkLine says no mind-map maintenance', () {
      expect(
        PositiveArchiveReinforcementCopy.noHomeworkLine,
        contains('No mind-map maintenance'),
      );
    });

    test(
      'chatDifferenceLine distinguishes ChatGPT now vs ArchiveMe evidence later',
      () {
        expect(
          PositiveArchiveReinforcementCopy.chatDifferenceLine,
          contains('ChatGPT can suggest what to do'),
        );
        expect(
          PositiveArchiveReinforcementCopy.chatDifferenceLine,
          contains('ArchiveMe shows what you already said before'),
        );
      },
    );

    test(
      'guardrail blocks streaks/daily pressure/advice/therapy/gamification',
      () {
        expect(
          PositiveArchiveReinforcementCopy.guardrail,
          contains('without creating streaks'),
        );
        expect(
          PositiveArchiveReinforcementCopy.guardrail,
          contains('daily pressure'),
        );
        expect(PositiveArchiveReinforcementCopy.guardrail, contains('advice'));
        expect(PositiveArchiveReinforcementCopy.guardrail, contains('therapy'));
        expect(
          PositiveArchiveReinforcementCopy.guardrail,
          contains('gamified habits'),
        );
      },
    );

    test('copy does not position ArchiveMe as voice chat', () {
      for (final text in [
        PositiveArchiveReinforcementCopy.headline,
        PositiveArchiveReinforcementCopy.body,
        PositiveArchiveReinforcementCopy.noticedLine,
        PositiveArchiveReinforcementCopy.smallMomentLine,
        PositiveArchiveReinforcementCopy.notEnoughProofLine,
      ]) {
        final lower = text.toLowerCase();
        expect(lower.contains('voice chat'), isFalse, reason: text);
        expect(lower.contains('voice assistant'), isFalse, reason: text);
      }
    });

    test('copy does not say better than ChatGPT', () {
      for (final text in [
        PositiveArchiveReinforcementCopy.headline,
        PositiveArchiveReinforcementCopy.body,
        PositiveArchiveReinforcementCopy.noticedLine,
        PositiveArchiveReinforcementCopy.smallMomentLine,
        PositiveArchiveReinforcementCopy.chatDifferenceLine,
      ]) {
        final lower = text.toLowerCase();
        expect(lower.contains('better than chatgpt'), isFalse, reason: text);
        expect(lower.contains('better chatgpt'), isFalse, reason: text);
      }
    });

    test('copy does not introduce ranking or importance scoring', () {
      for (final text in [
        PositiveArchiveReinforcementCopy.headline,
        PositiveArchiveReinforcementCopy.body,
        PositiveArchiveReinforcementCopy.noticedLine,
        PositiveArchiveReinforcementCopy.smallMomentLine,
        PositiveArchiveReinforcementCopy.repeatRelatedLine,
        PositiveArchiveReinforcementCopy.notEnoughProofLine,
        PositiveArchiveReinforcementCopy.simpleMomentSavedMessage,
      ]) {
        final lower = text.toLowerCase();
        expect(lower.contains('ranking'), isFalse, reason: text);
        expect(lower.contains('importance score'), isFalse, reason: text);
      }
    });

    test('copy avoids therapy diagnosis coaching and advice claims', () {
      for (final text in [
        PositiveArchiveReinforcementCopy.headline,
        PositiveArchiveReinforcementCopy.body,
        PositiveArchiveReinforcementCopy.noticedLine,
        PositiveArchiveReinforcementCopy.smallMomentLine,
        PositiveArchiveReinforcementCopy.repeatRelatedLine,
        PositiveArchiveReinforcementCopy.notEnoughProofLine,
        PositiveArchiveReinforcementCopy.chatDifferenceLine,
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
        'lib/features/positive_archive_reinforcement/positive_archive_reinforcement.dart',
        'lib/features/positive_archive_reinforcement/positive_archive_reinforcement_copy.dart',
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