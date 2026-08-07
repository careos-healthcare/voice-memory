import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/change_trail_clarity/change_trail_clarity.dart';
import 'package:voicememory_mobile/features/context_trail_clarity/context_trail_clarity.dart';
import 'package:voicememory_mobile/features/core_archive_journey/core_archive_journey.dart';
import 'package:voicememory_mobile/features/feature_noise_reduction/feature_noise_reduction.dart';
import 'package:voicememory_mobile/features/first_five_minutes/first_five_minutes_simplification.dart';
import 'package:voicememory_mobile/features/post_save_reinforcement/post_save_reinforcement_placement.dart';
import 'package:voicememory_mobile/features/prompt_assist_visibility/prompt_assist_visibility.dart';
import 'package:voicememory_mobile/features/pro_single_promise/pro_single_promise.dart';
import 'package:voicememory_mobile/features/proof_detail_repair/proof_detail_repair_copy.dart';
import 'package:voicememory_mobile/features/proof_selection/proof_selection_principle.dart';
import 'package:voicememory_mobile/features/release_candidate_freeze/release_candidate_freeze.dart';
import 'package:voicememory_mobile/features/release_candidate_freeze/release_candidate_freeze_copy.dart';
import 'package:voicememory_mobile/features/store_readiness_proof/store_readiness_proof.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_engine.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_model.dart';

ReleaseCandidateFreezeInput _input({
  ReleaseCandidateChangeType changeType =
      ReleaseCandidateChangeType.newProductFeature,
  bool blocksRelease = false,
  bool blocksPurchase = false,
  bool blocksRestore = false,
  bool blocksEntitlement = false,
  bool causesCrash = false,
  bool risksAppStoreRejection = false,
  bool affectsSecuritySecrets = false,
  bool fixesFirstJourneyComprehension = false,
  bool fixesCriticalProofTrust = false,
  bool addsNewUserFacingSurface = false,
  bool changesPricingOrPaywall = false,
  bool changesProofThresholds = false,
  bool changesRecordLayout = false,
}) => ReleaseCandidateFreezeInput(
  changeType: changeType,
  blocksRelease: blocksRelease,
  blocksPurchase: blocksPurchase,
  blocksRestore: blocksRestore,
  blocksEntitlement: blocksEntitlement,
  causesCrash: causesCrash,
  risksAppStoreRejection: risksAppStoreRejection,
  affectsSecuritySecrets: affectsSecuritySecrets,
  fixesFirstJourneyComprehension: fixesFirstJourneyComprehension,
  fixesCriticalProofTrust: fixesCriticalProofTrust,
  addsNewUserFacingSurface: addsNewUserFacingSurface,
  changesPricingOrPaywall: changesPricingOrPaywall,
  changesProofThresholds: changesProofThresholds,
  changesRecordLayout: changesRecordLayout,
);

void main() {
  group('ReleaseCandidateFreeze.build', () {
    test('security secrets blocker allowed', () {
      final result = ReleaseCandidateFreeze.build(
        _input(
          changeType: ReleaseCandidateChangeType.securitySecretsBlocker,
          affectsSecuritySecrets: true,
        ),
      );
      expect(result.allowed, isTrue);
      expect(
        result.reason,
        ReleaseCandidateFreezeReason.allowSecuritySecretsFix,
      );
    });

    test('crash allowed', () {
      final result = ReleaseCandidateFreeze.build(
        _input(changeType: ReleaseCandidateChangeType.crash, causesCrash: true),
      );
      expect(result.allowed, isTrue);
      expect(result.reason, ReleaseCandidateFreezeReason.allowCrashFix);
    });

    test('store readiness blocker allowed', () {
      final result = ReleaseCandidateFreeze.build(
        _input(changeType: ReleaseCandidateChangeType.storeReadinessBlocker),
      );
      expect(result.allowed, isTrue);
      expect(
        result.reason,
        ReleaseCandidateFreezeReason.allowStoreReadinessBlocker,
      );
    });

    test('build/signing blocker allowed', () {
      final result = ReleaseCandidateFreeze.build(
        _input(changeType: ReleaseCandidateChangeType.buildSigningBlocker),
      );
      expect(result.allowed, isTrue);
      expect(result.reason, ReleaseCandidateFreezeReason.allowBuildSigningFix);
    });

    test('TestFlight blocker allowed', () {
      final result = ReleaseCandidateFreeze.build(
        _input(changeType: ReleaseCandidateChangeType.testFlightBlocker),
      );
      expect(result.allowed, isTrue);
      expect(result.reason, ReleaseCandidateFreezeReason.allowTestFlightFix);
    });

    test('metadata/privacy/support blocker allowed', () {
      final metadata = ReleaseCandidateFreeze.build(
        _input(changeType: ReleaseCandidateChangeType.metadataBlocker),
      );
      final privacy = ReleaseCandidateFreeze.build(
        _input(changeType: ReleaseCandidateChangeType.privacySupportBlocker),
      );
      expect(metadata.allowed, isTrue);
      expect(
        metadata.reason,
        ReleaseCandidateFreezeReason.allowMetadataPrivacySupportFix,
      );
      expect(privacy.allowed, isTrue);
      expect(
        privacy.reason,
        ReleaseCandidateFreezeReason.allowMetadataPrivacySupportFix,
      );
    });

    test('purchase blocker allowed', () {
      final result = ReleaseCandidateFreeze.build(
        _input(changeType: ReleaseCandidateChangeType.purchaseBlocker),
      );
      expect(result.allowed, isTrue);
      expect(result.reason, ReleaseCandidateFreezeReason.allowPurchaseBlocker);
    });

    test('restore blocker allowed', () {
      final result = ReleaseCandidateFreeze.build(
        _input(changeType: ReleaseCandidateChangeType.restoreBlocker),
      );
      expect(result.allowed, isTrue);
      expect(result.reason, ReleaseCandidateFreezeReason.allowRestoreBlocker);
    });

    test('entitlement blocker allowed', () {
      final result = ReleaseCandidateFreeze.build(
        _input(changeType: ReleaseCandidateChangeType.entitlementBlocker),
      );
      expect(result.allowed, isTrue);
      expect(
        result.reason,
        ReleaseCandidateFreezeReason.allowEntitlementBlocker,
      );
    });

    test('App Store rejection risk allowed', () {
      final result = ReleaseCandidateFreeze.build(
        _input(
          changeType: ReleaseCandidateChangeType.appStoreRejectionRisk,
          risksAppStoreRejection: true,
        ),
      );
      expect(result.allowed, isTrue);
      expect(result.reason, ReleaseCandidateFreezeReason.allowAppStoreRiskFix);
    });

    test('first journey comprehension fix allowed', () {
      final result = ReleaseCandidateFreeze.build(
        _input(
          changeType:
              ReleaseCandidateChangeType.firstJourneyComprehensionFailure,
          fixesFirstJourneyComprehension: true,
        ),
      );
      expect(result.allowed, isTrue);
      expect(result.reason, ReleaseCandidateFreezeReason.allowFirstJourneyFix);
    });

    test('critical proof trust fix allowed', () {
      final result = ReleaseCandidateFreeze.build(
        _input(
          changeType: ReleaseCandidateChangeType.criticalProofTrustBug,
          fixesCriticalProofTrust: true,
        ),
      );
      expect(result.allowed, isTrue);
      expect(
        result.reason,
        ReleaseCandidateFreezeReason.allowCriticalProofTrustFix,
      );
    });

    test('new product feature blocked', () {
      final result = ReleaseCandidateFreeze.build(_input());
      expect(result.allowed, isFalse);
      expect(
        result.reason,
        ReleaseCandidateFreezeReason.blockNewProductFeature,
      );
    });

    test('new Pro benefit blocked', () {
      final result = ReleaseCandidateFreeze.build(
        _input(changeType: ReleaseCandidateChangeType.newProBenefit),
      );
      expect(result.allowed, isFalse);
      expect(result.reason, ReleaseCandidateFreezeReason.blockNewProBenefit);
    });

    test('new report blocked', () {
      final result = ReleaseCandidateFreeze.build(
        _input(changeType: ReleaseCandidateChangeType.newReport),
      );
      expect(result.allowed, isFalse);
      expect(result.reason, ReleaseCandidateFreezeReason.blockNewReport);
    });

    test('new dashboard blocked', () {
      final result = ReleaseCandidateFreeze.build(
        _input(changeType: ReleaseCandidateChangeType.newDashboard),
      );
      expect(result.allowed, isFalse);
      expect(result.reason, ReleaseCandidateFreezeReason.blockNewDashboard);
    });

    test('new ranking blocked', () {
      final result = ReleaseCandidateFreeze.build(
        _input(changeType: ReleaseCandidateChangeType.newRanking),
      );
      expect(result.allowed, isFalse);
      expect(result.reason, ReleaseCandidateFreezeReason.blockNewRanking);
    });

    test('context expansion blocked', () {
      final result = ReleaseCandidateFreeze.build(
        _input(changeType: ReleaseCandidateChangeType.newContextExpansion),
      );
      expect(result.allowed, isFalse);
      expect(
        result.reason,
        ReleaseCandidateFreezeReason.blockNewContextExpansion,
      );
    });

    test('action items blocked', () {
      final result = ReleaseCandidateFreeze.build(
        _input(changeType: ReleaseCandidateChangeType.newActionItems),
      );
      expect(result.allowed, isFalse);
      expect(result.reason, ReleaseCandidateFreezeReason.blockNewActionItems);
    });

    test('new onboarding flow blocked by default', () {
      final result = ReleaseCandidateFreeze.build(
        _input(changeType: ReleaseCandidateChangeType.newOnboardingFlow),
      );
      expect(result.allowed, isFalse);
      expect(
        result.reason,
        ReleaseCandidateFreezeReason.blockNewOnboardingFlow,
      );
    });

    test('new chat mode always blocked', () {
      final result = ReleaseCandidateFreeze.build(
        _input(changeType: ReleaseCandidateChangeType.newChatMode),
      );
      expect(result.allowed, isFalse);
      expect(result.reason, ReleaseCandidateFreezeReason.blockNewChatMode);
    });

    test('new pricing experiment blocked', () {
      final result = ReleaseCandidateFreeze.build(
        _input(changeType: ReleaseCandidateChangeType.newPricingExperiment),
      );
      expect(result.allowed, isFalse);
      expect(
        result.reason,
        ReleaseCandidateFreezeReason.blockNewPricingExperiment,
      );
    });

    test('new feature surface blocked', () {
      final result = ReleaseCandidateFreeze.build(
        _input(changeType: ReleaseCandidateChangeType.newFeatureSurface),
      );
      expect(result.allowed, isFalse);
      expect(
        result.reason,
        ReleaseCandidateFreezeReason.blockNewFeatureSurface,
      );
    });

    test('proof volume expansion blocked', () {
      final result = ReleaseCandidateFreeze.build(
        _input(changeType: ReleaseCandidateChangeType.proofVolumeExpansion),
      );
      expect(result.allowed, isFalse);
      expect(
        result.reason,
        ReleaseCandidateFreezeReason.blockProofVolumeExpansion,
      );
    });

    test('anchor/threshold change blocked unless critical proof trust bug', () {
      final blocked = ReleaseCandidateFreeze.build(
        _input(changeType: ReleaseCandidateChangeType.anchorThresholdChange),
      );
      final allowed = ReleaseCandidateFreeze.build(
        _input(
          changeType: ReleaseCandidateChangeType.anchorThresholdChange,
          fixesCriticalProofTrust: true,
        ),
      );
      expect(blocked.allowed, isFalse);
      expect(
        blocked.reason,
        ReleaseCandidateFreezeReason.blockAnchorThresholdChange,
      );
      expect(allowed.allowed, isTrue);
      expect(
        allowed.reason,
        ReleaseCandidateFreezeReason.allowCriticalProofTrustFix,
      );
    });

    test(
      'record layout change blocked unless first journey comprehension failure',
      () {
        final blocked = ReleaseCandidateFreeze.build(
          _input(changeType: ReleaseCandidateChangeType.recordLayoutChange),
        );
        final allowed = ReleaseCandidateFreeze.build(
          _input(
            changeType: ReleaseCandidateChangeType.recordLayoutChange,
            fixesFirstJourneyComprehension: true,
          ),
        );
        expect(blocked.allowed, isFalse);
        expect(
          blocked.reason,
          ReleaseCandidateFreezeReason.blockRecordLayoutChange,
        );
        expect(allowed.allowed, isTrue);
        expect(
          allowed.reason,
          ReleaseCandidateFreezeReason.allowFirstJourneyFix,
        );
      },
    );

    test(
      'paywall mechanics change blocked unless purchase/restore/entitlement blocker',
      () {
        final blocked = ReleaseCandidateFreeze.build(
          _input(changeType: ReleaseCandidateChangeType.paywallMechanicsChange),
        );
        final allowed = ReleaseCandidateFreeze.build(
          _input(
            changeType: ReleaseCandidateChangeType.paywallMechanicsChange,
            blocksPurchase: true,
          ),
        );
        expect(blocked.allowed, isFalse);
        expect(
          blocked.reason,
          ReleaseCandidateFreezeReason.blockPaywallMechanicsChange,
        );
        expect(allowed.allowed, isTrue);
        expect(
          allowed.reason,
          ReleaseCandidateFreezeReason.allowPurchaseBlocker,
        );
      },
    );

    test(
      'RevenueCat change blocked unless store/purchase/restore/entitlement blocker',
      () {
        final blocked = ReleaseCandidateFreeze.build(
          _input(changeType: ReleaseCandidateChangeType.revenueCatChange),
        );
        final allowed = ReleaseCandidateFreeze.build(
          _input(
            changeType: ReleaseCandidateChangeType.revenueCatChange,
            blocksRestore: true,
          ),
        );
        expect(blocked.allowed, isFalse);
        expect(
          blocked.reason,
          ReleaseCandidateFreezeReason.blockRevenueCatChange,
        );
        expect(allowed.allowed, isTrue);
        expect(
          allowed.reason,
          ReleaseCandidateFreezeReason.allowRestoreBlocker,
        );
      },
    );

    test('backend/sync change blocked unless release blocker', () {
      final blocked = ReleaseCandidateFreeze.build(
        _input(changeType: ReleaseCandidateChangeType.backendSyncChange),
      );
      final allowed = ReleaseCandidateFreeze.build(
        _input(
          changeType: ReleaseCandidateChangeType.backendSyncChange,
          blocksRelease: true,
        ),
      );
      expect(blocked.allowed, isFalse);
      expect(
        blocked.reason,
        ReleaseCandidateFreezeReason.blockBackendSyncChange,
      );
      expect(allowed.allowed, isTrue);
      expect(
        allowed.reason,
        ReleaseCandidateFreezeReason.allowStoreReadinessBlocker,
      );
    });

    test('fallback blocked', () {
      final result = ReleaseCandidateFreeze.build(
        _input(
          changeType:
              ReleaseCandidateChangeType.firstJourneyComprehensionFailure,
        ),
      );
      expect(result.allowed, isFalse);
      expect(
        result.reason,
        ReleaseCandidateFreezeReason.blockReleaseFreezeDefault,
      );
    });
  });

  group('ReleaseCandidateFreezeCopy', () {
    test('headline says Release candidate freeze', () {
      expect(ReleaseCandidateFreezeCopy.headline, 'Release candidate freeze');
    });

    test('body says stop adding product features', () {
      expect(
        ReleaseCandidateFreezeCopy.body.toLowerCase(),
        contains('stop adding product features'),
      );
    });

    test(
      'body says only fix blockers affecting release/purchase/restore/trust/safety/first journey',
      () {
        final lower = ReleaseCandidateFreezeCopy.body.toLowerCase();
        expect(lower, contains('release'));
        expect(lower, contains('purchase'));
        expect(lower, contains('restore'));
        expect(lower, contains('trust'));
        expect(lower, contains('safety'));
        expect(lower, contains('first journey'));
      },
    );

    test(
      'allowedLine includes store readiness/purchase/restore/entitlement/crash/signing/TestFlight/metadata/privacy/support/security/App Store risk',
      () {
        final lower = ReleaseCandidateFreezeCopy.allowedLine.toLowerCase();
        expect(lower, contains('store readiness'));
        expect(lower, contains('purchase'));
        expect(lower, contains('restore'));
        expect(lower, contains('entitlement'));
        expect(lower, contains('crash'));
        expect(lower, contains('signing'));
        expect(lower, contains('testflight'));
        expect(lower, contains('metadata'));
        expect(lower, contains('privacy'));
        expect(lower, contains('support'));
        expect(lower, contains('security'));
        expect(lower, contains('app store risk'));
      },
    );

    test(
      'blockedLine includes new features/dashboards/rankings/reports/action items/context expansion/chat/storage/extra Pro promises',
      () {
        final lower = ReleaseCandidateFreezeCopy.blockedLine.toLowerCase();
        expect(lower, contains('new features'));
        expect(lower, contains('dashboards'));
        expect(lower, contains('rankings'));
        expect(lower, contains('reports'));
        expect(lower, contains('action items'));
        expect(lower, contains('context expansion'));
        expect(lower, contains('chat mode'));
        expect(lower, contains('storage positioning'));
        expect(lower, contains('extra pro promises'));
      },
    );

    test(
      'firstJourneyLine includes save one repeat / feel it mattered / compares later / first useful proof',
      () {
        final lower = ReleaseCandidateFreezeCopy.firstJourneyLine.toLowerCase();
        expect(lower, contains('save one repeat'));
        expect(lower, contains('feel it mattered'));
        expect(lower, contains('compares later'));
        expect(lower, contains('first useful proof'));
      },
    );

    test('proLine says Free shows first useful proof', () {
      expect(
        ReleaseCandidateFreezeCopy.proLine.toLowerCase(),
        contains('free shows the first useful proof'),
      );
    });

    test('proLine says Pro keeps longer proof trail', () {
      expect(
        ReleaseCandidateFreezeCopy.proLine.toLowerCase(),
        contains('pro keeps the longer proof trail'),
      );
    });

    test('guardrail says do not build more product', () {
      expect(
        ReleaseCandidateFreezeCopy.guardrail.toLowerCase(),
        contains('do not build more product'),
      );
    });

    test('copy does not say better than ChatGPT', () {
      for (final text in ReleaseCandidateFreezeCopy.allVisibleStrings()) {
        final lower = text.toLowerCase();
        expect(lower.contains('better than chatgpt'), isFalse, reason: text);
        expect(lower.contains('better chatgpt'), isFalse, reason: text);
      }
    });

    test('copy does not position ArchiveMe as voice chat', () {
      for (final text in ReleaseCandidateFreezeCopy.allVisibleStrings()) {
        final lower = text.toLowerCase();
        expect(lower.contains('voice chat'), isFalse, reason: text);
        expect(lower.contains('voice assistant'), isFalse, reason: text);
      }
    });

    test('copy does not introduce ranking or importance scoring', () {
      for (final text in ReleaseCandidateFreezeCopy.allVisibleStrings()) {
        final lower = text.toLowerCase();
        expect(lower.contains('importance score'), isFalse, reason: text);
      }
    });

    test('copy avoids therapy diagnosis coaching and advice claims', () {
      for (final text in ReleaseCandidateFreezeCopy.allVisibleStrings()) {
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
        'lib/features/release_candidate_freeze/release_candidate_freeze.dart',
        'lib/features/release_candidate_freeze/release_candidate_freeze_copy.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source.contains('package:purchases_flutter'), isFalse);
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
        ProSinglePromise.build(_proInput()).decision,
        ProSinglePromiseDecision.releaseCandidate,
      );
      expect(
        PostSaveReinforcementPlacement.build(
          PostSaveReinforcementPlacementInput(
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
        StoreReadinessProof.resolve(_storeReadinessInput()).status,
        StoreReadinessProofStatus.readyForSubmission,
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

ProSinglePromiseInput _proInput() => const ProSinglePromiseInput(
  userUnderstandsFirstProof: true,
  userUnderstandsProKeepsLongerTrail: true,
  userThinksProMeansMoreAi: false,
  userThinksProMeansStorage: false,
  userThinksProMeansMoreFeatures: false,
  userThinksProMeansReports: false,
  userThinksProMeansRanking: false,
  userUnderstandsContinuityValue: true,
  userFeelsPressureOrManipulation: false,
  wouldPayYes: true,
  wouldPayMaybe: false,
);

StoreReadinessProofInput _storeReadinessInput() =>
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
