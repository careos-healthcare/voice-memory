import 'dart:io';

import 'package:archiveme_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:archiveme_mobile/features/change_trail_clarity/change_trail_clarity.dart';
import 'package:archiveme_mobile/features/context_trail_clarity/context_trail_clarity.dart';
import 'package:archiveme_mobile/features/core_archive_journey/core_archive_journey.dart';
import 'package:archiveme_mobile/features/evidence_trail_pro_understanding/evidence_trail_pro_understanding.dart';
import 'package:archiveme_mobile/features/feature_noise_reduction/feature_noise_reduction.dart';
import 'package:archiveme_mobile/features/first_five_minutes/first_five_minutes_simplification.dart';
import 'package:archiveme_mobile/features/post_save_reinforcement/post_save_reinforcement_placement.dart';
import 'package:archiveme_mobile/features/preserved_proof_value/preserved_proof_value.dart';
import 'package:archiveme_mobile/features/pricing_offer_validation/pricing_offer_validation_v2.dart';
import 'package:archiveme_mobile/features/pricing_validation/pricing_validation_copy.dart';
import 'package:archiveme_mobile/features/pro_single_promise/pro_single_promise.dart';
import 'package:archiveme_mobile/features/pro_single_promise/pro_single_promise_copy.dart';
import 'package:archiveme_mobile/features/prompt_assist_visibility/prompt_assist_visibility.dart';
import 'package:archiveme_mobile/features/proof_detail_repair/proof_detail_repair_copy.dart';
import 'package:archiveme_mobile/features/proof_selection/proof_selection_principle.dart';
import 'package:archiveme_mobile/features/surface_priority/surface_priority_engine.dart';
import 'package:archiveme_mobile/features/surface_priority/surface_priority_model.dart';
import 'package:flutter_test/flutter_test.dart';

ProSinglePromiseInput _input({
  bool userUnderstandsFirstProof = true,
  bool userUnderstandsProKeepsLongerTrail = true,
  bool userThinksProMeansMoreAi = false,
  bool userThinksProMeansStorage = false,
  bool userThinksProMeansMoreFeatures = false,
  bool userThinksProMeansReports = false,
  bool userThinksProMeansRanking = false,
  bool userUnderstandsContinuityValue = true,
  bool userFeelsPressureOrManipulation = false,
  bool wouldPayYes = false,
  bool wouldPayMaybe = false,
}) => ProSinglePromiseInput(
  userUnderstandsFirstProof: userUnderstandsFirstProof,
  userUnderstandsProKeepsLongerTrail: userUnderstandsProKeepsLongerTrail,
  userThinksProMeansMoreAi: userThinksProMeansMoreAi,
  userThinksProMeansStorage: userThinksProMeansStorage,
  userThinksProMeansMoreFeatures: userThinksProMeansMoreFeatures,
  userThinksProMeansReports: userThinksProMeansReports,
  userThinksProMeansRanking: userThinksProMeansRanking,
  userUnderstandsContinuityValue: userUnderstandsContinuityValue,
  userFeelsPressureOrManipulation: userFeelsPressureOrManipulation,
  wouldPayYes: wouldPayYes,
  wouldPayMaybe: wouldPayMaybe,
);

void main() {
  group('ProSinglePromise.build', () {
    test('weak first proof understanding -> clarifyFirstProof', () {
      final result = ProSinglePromise.build(
        _input(userUnderstandsFirstProof: false),
      );
      expect(result.decision, ProSinglePromiseDecision.clarifyFirstProof);
    });

    test('weak longer trail understanding -> clarifyLongerTrail', () {
      final result = ProSinglePromise.build(
        _input(userUnderstandsProKeepsLongerTrail: false),
      );
      expect(result.decision, ProSinglePromiseDecision.clarifyLongerTrail);
    });

    test('more AI confusion -> removeMoreAiConfusion', () {
      final result = ProSinglePromise.build(
        _input(userThinksProMeansMoreAi: true),
      );
      expect(result.decision, ProSinglePromiseDecision.removeMoreAiConfusion);
    });

    test('storage confusion -> removeStorageConfusion', () {
      final result = ProSinglePromise.build(
        _input(userThinksProMeansStorage: true),
      );
      expect(result.decision, ProSinglePromiseDecision.removeStorageConfusion);
    });

    test('more features confusion -> removeFeatureVolumeConfusion', () {
      final result = ProSinglePromise.build(
        _input(userThinksProMeansMoreFeatures: true),
      );
      expect(
        result.decision,
        ProSinglePromiseDecision.removeFeatureVolumeConfusion,
      );
    });

    test('reports confusion -> removeReportsConfusion', () {
      final result = ProSinglePromise.build(
        _input(userThinksProMeansReports: true),
      );
      expect(result.decision, ProSinglePromiseDecision.removeReportsConfusion);
    });

    test('ranking confusion -> removeRankingConfusion', () {
      final result = ProSinglePromise.build(
        _input(userThinksProMeansRanking: true),
      );
      expect(result.decision, ProSinglePromiseDecision.removeRankingConfusion);
    });

    test('pressure/manipulation feeling -> reducePressure', () {
      final result = ProSinglePromise.build(
        _input(userFeelsPressureOrManipulation: true),
      );
      expect(result.decision, ProSinglePromiseDecision.reducePressure);
    });

    test('weak continuity value understanding -> clarifyContinuityValue', () {
      final result = ProSinglePromise.build(
        _input(userUnderstandsContinuityValue: false),
      );
      expect(result.decision, ProSinglePromiseDecision.clarifyContinuityValue);
    });

    test('comprehension passes but payment weak -> pricingValidation', () {
      final result = ProSinglePromise.build(_input());
      expect(result.decision, ProSinglePromiseDecision.pricingValidation);
    });

    test('comprehension and payment pass -> releaseCandidate', () {
      final result = ProSinglePromise.build(_input(wouldPayYes: true));
      expect(result.decision, ProSinglePromiseDecision.releaseCandidate);
    });
  });

  group('ProSinglePromiseCopy', () {
    test(
      'headline says Keep the longer proof trail',
      () {
        expect(
          ProSinglePromiseCopy.headline,
          'Keep the longer proof trail',
        );
      },
    );

    test('body says Free shows first useful proof', () {
      expect(
        ProSinglePromiseCopy.body.toLowerCase(),
        contains('free shows the first useful proof'),
      );
    });

    test('body says Pro keeps tracking what happens after', () {
      expect(
        ProSinglePromiseCopy.body.toLowerCase(),
        contains('pro keeps tracking what happens after'),
      );
    });

    test('body includes returns changes fades corrected', () {
      final lower = ProSinglePromiseCopy.body.toLowerCase();
      expect(lower, contains('returns'));
      expect(lower, contains('changes'));
      expect(lower, contains('fades'));
      expect(lower, contains('corrected'));
    });

    test('freeLine says Free: first useful proof', () {
      expect(ProSinglePromiseCopy.freeLine, 'Free: first useful proof.');
    });

    test('proLine says Pro: longer proof trail', () {
      expect(ProSinglePromiseCopy.proLine, 'Pro: longer proof trail.');
    });

    test(
      'whyPayLine says keep seeing what happens to same repeat over time',
      () {
        expect(
          ProSinglePromiseCopy.whyPayLine.toLowerCase(),
          contains('keep seeing what happens to the same repeat over time'),
        );
      },
    );

    test('notMoreAiLine says not more chat or more AI', () {
      expect(
        ProSinglePromiseCopy.notMoreAiLine.toLowerCase(),
        contains('not more chat or more ai'),
      );
    });

    test('notMoreAiLine says keeps the trail', () {
      expect(
        ProSinglePromiseCopy.notMoreAiLine.toLowerCase(),
        contains('keeps the trail'),
      );
    });

    test('notStorageLine says not extra storage', () {
      expect(
        ProSinglePromiseCopy.notStorageLine.toLowerCase(),
        contains('not extra storage'),
      );
    });

    test('notStorageLine says preserves evidence trail', () {
      expect(
        ProSinglePromiseCopy.notStorageLine.toLowerCase(),
        contains('preserves the evidence trail'),
      );
    });

    test('notFeatureListLine says no long feature list', () {
      expect(
        ProSinglePromiseCopy.notFeatureListLine.toLowerCase(),
        contains('no long feature list'),
      );
    });

    test('notFeatureListLine says promise is keep the trail', () {
      expect(
        ProSinglePromiseCopy.notFeatureListLine.toLowerCase(),
        contains('promise is simple: keep the trail'),
      );
    });

    test('valueLine says continuity', () {
      expect(
        ProSinglePromiseCopy.valueLine.toLowerCase(),
        contains('continuity'),
      );
    });

    test('valueLine says archive proves later', () {
      expect(
        ProSinglePromiseCopy.valueLine.toLowerCase(),
        contains('archive proves later'),
      );
    });

    test('guardrail blocks more AI', () {
      expect(ProSinglePromiseCopy.guardrail.toLowerCase(), contains('more ai'));
    });

    test('guardrail blocks storage', () {
      expect(ProSinglePromiseCopy.guardrail.toLowerCase(), contains('storage'));
    });

    test('guardrail blocks dashboards', () {
      expect(
        ProSinglePromiseCopy.guardrail.toLowerCase(),
        contains('dashboards'),
      );
    });

    test('guardrail blocks rankings', () {
      expect(
        ProSinglePromiseCopy.guardrail.toLowerCase(),
        contains('rankings'),
      );
    });

    test('guardrail blocks reports', () {
      expect(ProSinglePromiseCopy.guardrail.toLowerCase(), contains('reports'));
    });

    test('guardrail blocks feature volume', () {
      expect(
        ProSinglePromiseCopy.guardrail.toLowerCase(),
        contains('feature volume'),
      );
    });

    test('copy does not use fear scarcity urgency tricks', () {
      const banned = [
        'limited time',
        'act now',
        "don't miss",
        'last chance',
        'urgent',
        'scarcity',
        'hurry',
        'expires',
        'only today',
      ];
      for (final text in ProSinglePromiseCopy.allVisibleStrings()) {
        final lower = text.toLowerCase();
        for (final phrase in banned) {
          expect(lower.contains(phrase), isFalse, reason: '$text -> $phrase');
        }
      }
    });

    test('copy does not say better than ChatGPT', () {
      for (final text in ProSinglePromiseCopy.allVisibleStrings()) {
        final lower = text.toLowerCase();
        expect(lower.contains('better than chatgpt'), isFalse, reason: text);
        expect(lower.contains('better chatgpt'), isFalse, reason: text);
      }
    });

    test('copy does not position ArchiveMe as voice chat', () {
      for (final text in ProSinglePromiseCopy.allVisibleStrings()) {
        final lower = text.toLowerCase();
        expect(lower.contains('voice chat'), isFalse, reason: text);
        expect(lower.contains('voice assistant'), isFalse, reason: text);
      }
    });

    test('copy does not introduce ranking or importance scoring', () {
      for (final text in ProSinglePromiseCopy.allVisibleStrings()) {
        final lower = text.toLowerCase();
        expect(lower.contains('ranking'), isFalse, reason: text);
        expect(lower.contains('importance score'), isFalse, reason: text);
      }
    });

    test('copy avoids therapy diagnosis coaching and advice claims', () {
      for (final text in ProSinglePromiseCopy.allVisibleStrings()) {
        expect(ProofSurfaceAdviceGuard.passes(text), isTrue, reason: text);
        final lower = text.toLowerCase();
        expect(lower.contains('advice'), isFalse, reason: text);
        expect(lower.contains('coaching'), isFalse, reason: text);
        expect(lower.contains('therapy'), isFalse, reason: text);
        expect(lower.contains('diagnosis'), isFalse, reason: text);
      }
    });
  });

  group('ProSinglePromiseGuardrail', () {
    test('allows longer trail promise', () {
      expect(ProSinglePromiseGuardrail.allowsLongerTrailPromise(), isTrue);
    });

    test('blocks more AI promise', () {
      expect(ProSinglePromiseGuardrail.allowsMoreAiPromise(), isFalse);
    });

    test('blocks storage promise', () {
      expect(ProSinglePromiseGuardrail.allowsStoragePromise(), isFalse);
    });

    test('blocks dashboard promise', () {
      expect(ProSinglePromiseGuardrail.allowsDashboardPromise(), isFalse);
    });

    test('blocks ranking promise', () {
      expect(ProSinglePromiseGuardrail.allowsRankingPromise(), isFalse);
    });

    test('blocks reports as primary promise', () {
      expect(
        ProSinglePromiseGuardrail.allowsReportsAsPrimaryPromise(),
        isFalse,
      );
    });

    test('blocks feature volume promise', () {
      expect(ProSinglePromiseGuardrail.allowsFeatureVolumePromise(), isFalse);
    });
  });

  group('Protected areas', () {
    test('module does not import billing entitlements or ranking UI', () {
      for (final path in [
        'lib/features/pro_single_promise/pro_single_promise.dart',
        'lib/features/pro_single_promise/pro_single_promise_copy.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source.contains('RevenueCat'), isFalse);
        expect(source.contains('restorePurchases'), isFalse);
        expect(source.contains('billing/'), isFalse);
        expect(source.contains('importance_scoring'), isFalse);
        expect(source.contains('anchor_specificity_guard'), isFalse);
        expect(source.contains('journal_storage'), isFalse);
        expect(source.contains('paywall_source'), isFalse);
        expect(source.contains('pricing_validation_engine'), isFalse);
        expect(source.contains('entitlements'), isFalse);
      }
    });

    test('existing modules behaviour unchanged', () {
      expect(
        PostSaveReinforcementPlacement.build(
          const PostSaveReinforcementPlacementInput(
            surface: PostSaveReinforcementPlacementSurface.afterFirstSave,
            savedMoment: true,
            isFirstMoment: true,
            isRelatedToPreviousRepeat: false,
            hasSafeRepeat: true,
            hasEnoughArchiveSignal: true,
            userCorrectedProofRecently: false,
            isWatchOnly: false,
            isPrivateRawText: false,
            isPostSave: true,
            isRecordScreen: false,
            wouldCompeteWithFirstProof: false,
            wouldPressureMoreRecording: false,
          ),
        ).reason,
        PostSaveReinforcementPlacementReason.showFirstMomentSaved,
      );
      expect(
        PromptAssistVisibility.build(
          const PromptAssistVisibilityInput(
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
        PreservedProofValue.resolve(
          const PreservedProofValueInput(
            userUnderstandsFirstProof: true,
            userUnderstandsProKeepsTrail: true,
            userUnderstandsPreservedProof: true,
            userUnderstandsWhatWouldBeLost: true,
            userThinksProMeansMoreAi: false,
            userThinksProMeansStorage: false,
            userThinksPaymentFeelsOptional: false,
            userFeelsPressureOrManipulation: false,
            wouldPayYes: true,
            wouldPayMaybe: false,
          ),
        ).decision,
        PreservedProofValueDecision.releaseCandidate,
      );
      expect(
        PricingOfferValidationV2.resolve(
          const PricingOfferValidationSummary(
            totalTesters: 30,
            usefulProofCount: 7,
            understoodLongerTrailCount: 6,
            understoodNotMoreAiCount: 6,
            payYesCount: 2,
            payMaybeCount: 1,
            payNoCount: 2,
            priceTooHighCount: 1,
            needStrongerProofCount: 1,
            needRankingCount: 1,
            ctaTapCount: 2,
          ),
        ),
        PricingOfferValidationDecision.pricingAcceptedProductionCandidate,
      );
      expect(PricingValidationCopy.title, 'What would feel fair?');
      expect(
        EvidenceTrailProUnderstanding.resolve(
          const EvidenceTrailProUnderstandingSummary(
            totalTesters: 30,
            usefulProofCount: 7,
            understoodFirstProofCount: 7,
            understoodLongerTrailCount: 6,
            understoodProKeepsChangesCount: 6,
            thoughtProWasMoreAiCount: 2,
            wantedRankingCount: 2,
            paywallCtaTapCount: 2,
            wouldPayYesMaybeCount: 4,
          ),
        ),
        EvidenceTrailProUnderstandingDecision.productionCandidate,
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