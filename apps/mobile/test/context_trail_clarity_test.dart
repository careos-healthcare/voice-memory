import 'dart:io';

import 'package:archiveme_mobile/features/archive_prompt_assist/archive_prompt_assist.dart';
import 'package:archiveme_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:archiveme_mobile/features/change_trail_clarity/change_trail_clarity.dart';
import 'package:archiveme_mobile/features/context_trail_clarity/context_trail_clarity.dart';
import 'package:archiveme_mobile/features/context_trail_clarity/context_trail_clarity_copy.dart';
import 'package:archiveme_mobile/features/core_archive_journey/core_archive_journey.dart';
import 'package:archiveme_mobile/features/low_effort_archive_capture/low_effort_archive_capture.dart';
import 'package:archiveme_mobile/features/positive_archive_reinforcement/positive_archive_reinforcement.dart';
import 'package:archiveme_mobile/features/proof_detail_repair/proof_detail_repair_copy.dart';
import 'package:archiveme_mobile/features/proof_selection/proof_selection_principle.dart';
import 'package:archiveme_mobile/features/release_candidate_comprehension/release_candidate_comprehension.dart';
import 'package:archiveme_mobile/features/surface_priority/surface_priority_engine.dart';
import 'package:archiveme_mobile/features/surface_priority/surface_priority_model.dart';
import 'package:flutter_test/flutter_test.dart';

ContextTrailClarityInput _input({
  int eligibleEntryCount = 4,
  int taggedContextCount = 1,
  int distinctContextCount = 1,
  bool hasStrongProof = true,
  bool hasUserCorrection = false,
  bool isFirstSession = false,
  bool isRecordScreen = false,
  bool userAskedForContext = false,
}) => ContextTrailClarityInput(
  eligibleEntryCount: eligibleEntryCount,
  taggedContextCount: taggedContextCount,
  distinctContextCount: distinctContextCount,
  hasStrongProof: hasStrongProof,
  hasUserCorrection: hasUserCorrection,
  isFirstSession: isFirstSession,
  isRecordScreen: isRecordScreen,
  userAskedForContext: userAskedForContext,
);

void main() {
  group('ContextTrailClarity.build', () {
    test('first session hides context', () {
      final result = ContextTrailClarity.build(_input(isFirstSession: true));
      expect(result.shouldSurfaceContext, isFalse);
      expect(result.shouldKeepQuiet, isTrue);
      expect(result.reason, ContextTrailClarityReason.hiddenFirstSession);
    });

    test('record screen hides context', () {
      final result = ContextTrailClarity.build(_input(isRecordScreen: true));
      expect(result.shouldSurfaceContext, isFalse);
      expect(result.shouldKeepQuiet, isTrue);
      expect(result.reason, ContextTrailClarityReason.hiddenRecordScreen);
    });

    test('not enough evidence hides context', () {
      final result = ContextTrailClarity.build(_input(eligibleEntryCount: 2));
      expect(result.shouldSurfaceContext, isFalse);
      expect(result.shouldKeepQuiet, isTrue);
      expect(result.reason, ContextTrailClarityReason.hiddenNotEnoughEvidence);
    });

    test('recent correction hides context', () {
      final result = ContextTrailClarity.build(_input(hasUserCorrection: true));
      expect(result.shouldSurfaceContext, isFalse);
      expect(result.shouldKeepQuiet, isTrue);
      expect(result.reason, ContextTrailClarityReason.hiddenAfterCorrection);
    });

    test('user asked for context with enough evidence surfaces context', () {
      final result = ContextTrailClarity.build(
        _input(eligibleEntryCount: 2, userAskedForContext: true),
      );
      expect(result.shouldSurfaceContext, isTrue);
      expect(result.shouldKeepQuiet, isFalse);
      expect(result.reason, ContextTrailClarityReason.surfaceWhenUserAsked);
    });

    test('no tagged context stays quiet optional', () {
      final result = ContextTrailClarity.build(_input(taggedContextCount: 0));
      expect(result.shouldSurfaceContext, isFalse);
      expect(result.shouldKeepQuiet, isTrue);
      expect(result.reason, ContextTrailClarityReason.quietOptionalContext);
    });

    test('one context with strong proof surfaces single context evidence', () {
      final result = ContextTrailClarity.build(
        _input(
          taggedContextCount: 2,
        ),
      );
      expect(result.shouldSurfaceContext, isTrue);
      expect(result.shouldKeepQuiet, isFalse);
      expect(
        result.reason,
        ContextTrailClarityReason.surfaceSingleContextEvidence,
      );
    });

    test(
      'varied contexts with strong proof surfaces varied context evidence',
      () {
        final result = ContextTrailClarity.build(
          _input(
            taggedContextCount: 3,
            distinctContextCount: 2,
          ),
        );
        expect(result.shouldSurfaceContext, isTrue);
        expect(result.shouldKeepQuiet, isFalse);
        expect(
          result.reason,
          ContextTrailClarityReason.surfaceVariedContextEvidence,
        );
      },
    );
  });

  group('ContextTrailClarityCopy', () {
    test('headline says where the repeat shows up', () {
      expect(ContextTrailClarityCopy.headline, 'Where the repeat shows up');
    });

    test(
      'body includes work/home/family/money/health/decisions/relationships/other',
      () {
        final body = ContextTrailClarityCopy.body.toLowerCase();
        for (final context in [
          'work',
          'home',
          'family',
          'money',
          'health',
          'decisions',
          'relationships',
          'somewhere else',
        ]) {
          expect(body, contains(context), reason: context);
        }
      },
    );

    test('body says user does not need to tag everything', () {
      expect(
        ContextTrailClarityCopy.body,
        contains('You do not need to tag everything'),
      );
    });

    test('optionalLine says context is optional', () {
      expect(
        ContextTrailClarityCopy.optionalLine,
        contains('Context is optional'),
      );
    });

    test('optionalLine says proof trail still works from saved moments', () {
      expect(
        ContextTrailClarityCopy.optionalLine,
        contains('proof trail still works from saved moments'),
      );
    });

    test('evidenceLine says context explains where evidence came from', () {
      expect(
        ContextTrailClarityCopy.evidenceLine,
        contains('explain where the evidence came from'),
      );
    });

    test('notMaintenanceLine says no manual map maintenance', () {
      expect(
        ContextTrailClarityCopy.notMaintenanceLine,
        contains('No manual map maintenance'),
      );
    });

    test('notMaintenanceLine says no tagging homework', () {
      expect(
        ContextTrailClarityCopy.notMaintenanceLine,
        contains('No tagging homework'),
      );
    });

    test('trailLine says context makes repeat clearer', () {
      expect(
        ContextTrailClarityCopy.trailLine,
        contains('makes the repeat clearer'),
      );
    });

    test('proLaterLine says Pro can keep longer context trail', () {
      expect(
        ContextTrailClarityCopy.proLaterLine,
        contains('Pro can keep a longer context trail'),
      );
    });

    test('proLaterLine includes returns/changes/fades/corrected', () {
      final line = ContextTrailClarityCopy.proLaterLine.toLowerCase();
      expect(line, contains('returns'));
      expect(line, contains('changes'));
      expect(line, contains('fades'));
      expect(line, contains('corrected'));
    });

    test('guardrail blocks required tagging', () {
      expect(
        ContextTrailClarityCopy.guardrail,
        contains('required tagging system'),
      );
    });

    test('guardrail blocks dashboard', () {
      expect(ContextTrailClarityCopy.guardrail, contains('dashboard'));
    });

    test('guardrail blocks ranking tool', () {
      expect(ContextTrailClarityCopy.guardrail, contains('ranking tool'));
    });

    test('guardrail blocks mind-map maintenance task', () {
      expect(
        ContextTrailClarityCopy.guardrail,
        contains('mind-map maintenance task'),
      );
    });

    test('copy does not position ArchiveMe as storage', () {
      for (final text in ContextTrailClarityCopy.allVisibleStrings()) {
        final lower = text.toLowerCase();
        expect(lower.contains('storage app'), isFalse, reason: text);
        expect(lower.contains('just storage'), isFalse, reason: text);
        expect(lower.contains('store everything'), isFalse, reason: text);
      }
    });

    test('copy does not position ArchiveMe as chat', () {
      for (final text in ContextTrailClarityCopy.allVisibleStrings()) {
        final lower = text.toLowerCase();
        expect(lower.contains('voice chat'), isFalse, reason: text);
        expect(lower.contains('chat box'), isFalse, reason: text);
        expect(lower.contains('voice assistant'), isFalse, reason: text);
      }
    });

    test('copy does not introduce ranking or importance scoring', () {
      for (final text in ContextTrailClarityCopy.allVisibleStrings()) {
        final lower = text.toLowerCase();
        expect(lower.contains('ranking'), isFalse, reason: text);
        expect(lower.contains('importance score'), isFalse, reason: text);
      }
    });

    test('copy avoids therapy diagnosis coaching and advice claims', () {
      for (final text in ContextTrailClarityCopy.allVisibleStrings()) {
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
        'lib/features/context_trail_clarity/context_trail_clarity.dart',
        'lib/features/context_trail_clarity/context_trail_clarity_copy.dart',
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