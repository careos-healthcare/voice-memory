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
import 'package:voicememory_mobile/features/proof_trail_positioning/proof_trail_positioning_copy.dart';
import 'package:voicememory_mobile/features/release_candidate_comprehension/release_candidate_comprehension.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_engine.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_model.dart';

ProofTrailPositioningInput _input({
  bool userThinksChatBox = false,
  bool userThinksStorageApp = false,
  bool userThinksSecondBrain = false,
  bool userThinksDashboardToMaintain = false,
  bool userUnderstandsProofTrail = true,
  bool userUnderstandsMeaningfulResurfacing = true,
  bool userUnderstandsSaveARepeat = true,
  bool userUnderstandsLowEffort = true,
  bool wouldPayYes = true,
  bool wouldPayMaybe = false,
}) => ProofTrailPositioningInput(
  userThinksChatBox: userThinksChatBox,
  userThinksStorageApp: userThinksStorageApp,
  userThinksSecondBrain: userThinksSecondBrain,
  userThinksDashboardToMaintain: userThinksDashboardToMaintain,
  userUnderstandsProofTrail: userUnderstandsProofTrail,
  userUnderstandsMeaningfulResurfacing: userUnderstandsMeaningfulResurfacing,
  userUnderstandsSaveARepeat: userUnderstandsSaveARepeat,
  userUnderstandsLowEffort: userUnderstandsLowEffort,
  wouldPayYes: wouldPayYes,
  wouldPayMaybe: wouldPayMaybe,
);

void main() {
  group('ProofTrailPositioning.resolve', () {
    test('chat-box confusion -> clarifyNotChat', () {
      expect(
        ProofTrailPositioning.resolve(_input(userThinksChatBox: true)).decision,
        ProofTrailPositioningDecision.clarifyNotChat,
      );
    });

    test('storage-app confusion -> clarifyNotStorage', () {
      expect(
        ProofTrailPositioning.resolve(
          _input(userThinksStorageApp: true),
        ).decision,
        ProofTrailPositioningDecision.clarifyNotStorage,
      );
    });

    test('second-brain confusion -> clarifyNotSecondBrain', () {
      expect(
        ProofTrailPositioning.resolve(
          _input(userThinksSecondBrain: true),
        ).decision,
        ProofTrailPositioningDecision.clarifyNotSecondBrain,
      );
    });

    test('dashboard-maintenance confusion -> clarifyNotDashboard', () {
      expect(
        ProofTrailPositioning.resolve(
          _input(userThinksDashboardToMaintain: true),
        ).decision,
        ProofTrailPositioningDecision.clarifyNotDashboard,
      );
    });

    test('weak proof-trail understanding -> clarifyProofTrail', () {
      expect(
        ProofTrailPositioning.resolve(
          _input(userUnderstandsProofTrail: false),
        ).decision,
        ProofTrailPositioningDecision.clarifyProofTrail,
      );
    });

    test(
      'weak meaningful-resurfacing understanding -> clarifyMeaningfulResurfacing',
      () {
        expect(
          ProofTrailPositioning.resolve(
            _input(userUnderstandsMeaningfulResurfacing: false),
          ).decision,
          ProofTrailPositioningDecision.clarifyMeaningfulResurfacing,
        );
      },
    );

    test('weak save-a-repeat understanding -> clarifySaveARepeat', () {
      expect(
        ProofTrailPositioning.resolve(
          _input(userUnderstandsSaveARepeat: false),
        ).decision,
        ProofTrailPositioningDecision.clarifySaveARepeat,
      );
    });

    test('weak low-effort understanding -> clarifyLowEffort', () {
      expect(
        ProofTrailPositioning.resolve(
          _input(userUnderstandsLowEffort: false),
        ).decision,
        ProofTrailPositioningDecision.clarifyLowEffort,
      );
    });

    test('comprehension passes but payment weak -> pricingValidation', () {
      expect(
        ProofTrailPositioning.resolve(
          _input(wouldPayYes: false, wouldPayMaybe: false),
        ).decision,
        ProofTrailPositioningDecision.pricingValidation,
      );
    });

    test('comprehension and payment pass -> releaseCandidate', () {
      expect(
        ProofTrailPositioning.resolve(_input()).decision,
        ProofTrailPositioningDecision.releaseCandidate,
      );
    });
  });

  group('ProofTrailPositioningCopy', () {
    test('headline says Not a chat box. A proof trail.', () {
      expect(
        ProofTrailPositioningCopy.headline,
        'Not a chat box. A proof trail.',
      );
    });

    test('body says ArchiveMe is not where you store everything', () {
      expect(
        ProofTrailPositioningCopy.body,
        contains('ArchiveMe is not where you store everything'),
      );
    });

    test('body says save small real moments', () {
      expect(
        ProofTrailPositioningCopy.body,
        contains('save small real moments'),
      );
    });

    test('body says archive shows what keeps coming back', () {
      expect(
        ProofTrailPositioningCopy.body,
        contains('show what keeps coming back'),
      );
    });

    test('notChatLine distinguishes ChatGPT from ArchiveMe evidence trail', () {
      expect(
        ProofTrailPositioningCopy.notChatLine,
        contains('ChatGPT can suggest what to do'),
      );
      expect(
        ProofTrailPositioningCopy.notChatLine,
        contains('ArchiveMe shows what you already said before'),
      );
    });

    test('notStorageLine says notes store what happened', () {
      expect(
        ProofTrailPositioningCopy.notStorageLine,
        contains('Notes store what happened'),
      );
    });

    test('notStorageLine says ArchiveMe checks what returns', () {
      expect(
        ProofTrailPositioningCopy.notStorageLine,
        contains('ArchiveMe checks what returns'),
      );
    });

    test('proofTrailLine includes first repeat', () {
      expect(
        ProofTrailPositioningCopy.proofTrailLine,
        contains('first repeat'),
      );
    });

    test('proofTrailLine includes why it appeared', () {
      expect(
        ProofTrailPositioningCopy.proofTrailLine,
        contains('why it appeared'),
      );
    });

    test('proofTrailLine includes confirmed or corrected', () {
      expect(
        ProofTrailPositioningCopy.proofTrailLine,
        contains('confirmed or corrected'),
      );
    });

    test('proofTrailLine includes what changed later', () {
      expect(
        ProofTrailPositioningCopy.proofTrailLine,
        contains('what changed later'),
      );
    });

    test('resurfacingLine says meaningful resurfacing', () {
      expect(
        ProofTrailPositioningCopy.resurfacingLine,
        contains('meaningful resurfacing'),
      );
    });

    test('resurfacingLine rejects more notes/dashboards/AI', () {
      final line = ProofTrailPositioningCopy.resurfacingLine.toLowerCase();
      expect(line, contains('not more notes'));
      expect(line, contains('more dashboards'));
      expect(line, contains('more ai'));
    });

    test('saveRepeatLine says use ArchiveMe when something repeats', () {
      expect(
        ProofTrailPositioningCopy.saveRepeatLine,
        contains('Use ArchiveMe when something repeats'),
      );
    });

    test('lowEffortLine says one real sentence is enough', () {
      expect(
        ProofTrailPositioningCopy.lowEffortLine,
        contains('One real sentence is enough'),
      );
    });

    test('lowEffortLine says no daily homework', () {
      expect(
        ProofTrailPositioningCopy.lowEffortLine,
        contains('No daily homework'),
      );
    });

    test('lowEffortLine says no dashboard to maintain', () {
      expect(
        ProofTrailPositioningCopy.lowEffortLine,
        contains('No dashboard to maintain'),
      );
    });

    test('proLine says Free shows first useful proof', () {
      expect(
        ProofTrailPositioningCopy.proLine,
        contains('Free shows the first useful proof'),
      );
    });

    test('proLine says Pro keeps longer proof trail', () {
      expect(
        ProofTrailPositioningCopy.proLine,
        contains('Pro keeps the longer proof trail'),
      );
    });

    test('guardrail blocks chat box positioning', () {
      expect(ProofTrailPositioningCopy.guardrail, contains('chat box'));
      expect(ProofTrailPositioningCopy.guardrail, contains('not a chat box'));
    });

    test('guardrail blocks storage app positioning', () {
      expect(ProofTrailPositioningCopy.guardrail, contains('storage app'));
    });

    test('guardrail blocks second brain positioning', () {
      expect(ProofTrailPositioningCopy.guardrail, contains('second brain'));
    });

    test('guardrail blocks dashboard maintenance positioning', () {
      expect(
        ProofTrailPositioningCopy.guardrail,
        contains('dashboard to maintain'),
      );
    });

    test('copy does not say better than ChatGPT', () {
      for (final text in ProofTrailPositioningCopy.allVisibleStrings()) {
        final lower = text.toLowerCase();
        expect(lower.contains('better than chatgpt'), isFalse, reason: text);
        expect(lower.contains('better chatgpt'), isFalse, reason: text);
      }
    });

    test('copy does not position ArchiveMe as voice chat', () {
      for (final text in ProofTrailPositioningCopy.allVisibleStrings()) {
        final lower = text.toLowerCase();
        expect(lower.contains('voice chat'), isFalse, reason: text);
        expect(lower.contains('voice assistant'), isFalse, reason: text);
      }
    });

    test('copy does not introduce ranking or importance scoring', () {
      for (final text in ProofTrailPositioningCopy.allVisibleStrings()) {
        final lower = text.toLowerCase();
        expect(lower.contains('ranking'), isFalse, reason: text);
        expect(lower.contains('importance score'), isFalse, reason: text);
      }
    });

    test('copy avoids therapy diagnosis coaching and advice claims', () {
      for (final text in ProofTrailPositioningCopy.allVisibleStrings()) {
        expect(ProofSurfaceAdviceGuard.passes(text), isTrue, reason: text);
        final lower = text.toLowerCase();
        expect(lower.contains('advice'), isFalse, reason: text);
        expect(lower.contains('coaching'), isFalse, reason: text);
        expect(lower.contains('therapy'), isFalse, reason: text);
        expect(lower.contains('diagnosis'), isFalse, reason: text);
      }
    });
  });

  group('ProofTrailPositioningGuardrail', () {
    test('guardrail helper disallows chat box positioning', () {
      expect(
        ProofTrailPositioningGuardrail.allowsChatBoxPositioning(),
        isFalse,
      );
    });

    test('guardrail helper disallows storage positioning', () {
      expect(
        ProofTrailPositioningGuardrail.allowsStoragePositioning(),
        isFalse,
      );
    });

    test('guardrail helper disallows second brain positioning', () {
      expect(
        ProofTrailPositioningGuardrail.allowsSecondBrainPositioning(),
        isFalse,
      );
    });

    test('guardrail helper disallows dashboard maintenance positioning', () {
      expect(
        ProofTrailPositioningGuardrail.allowsDashboardMaintenancePositioning(),
        isFalse,
      );
    });

    test('guardrail helper allows proof trail positioning', () {
      expect(
        ProofTrailPositioningGuardrail.allowsProofTrailPositioning(),
        isTrue,
      );
    });

    test('guardrail helper allows meaningful resurfacing positioning', () {
      expect(
        ProofTrailPositioningGuardrail.allowsMeaningfulResurfacingPositioning(),
        isTrue,
      );
    });

    test('guardrail helper allows save-a-repeat positioning', () {
      expect(
        ProofTrailPositioningGuardrail.allowsSaveARepeatPositioning(),
        isTrue,
      );
    });
  });

  group('Protected areas', () {
    test('module does not import billing entitlements or ranking UI', () {
      for (final path in [
        'lib/features/proof_trail_positioning/proof_trail_positioning.dart',
        'lib/features/proof_trail_positioning/proof_trail_positioning_copy.dart',
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
