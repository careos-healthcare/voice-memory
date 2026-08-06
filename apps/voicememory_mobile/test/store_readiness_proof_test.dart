import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/change_trail_clarity/change_trail_clarity.dart';
import 'package:voicememory_mobile/features/context_trail_clarity/context_trail_clarity.dart';
import 'package:voicememory_mobile/features/core_archive_journey/core_archive_journey.dart';
import 'package:voicememory_mobile/features/low_effort_archive_capture/low_effort_archive_capture.dart';
import 'package:voicememory_mobile/features/positive_archive_reinforcement/positive_archive_reinforcement.dart';
import 'package:voicememory_mobile/features/preserved_proof_value/preserved_proof_value.dart';
import 'package:voicememory_mobile/features/production_candidate/production_candidate_checklist.dart';
import 'package:voicememory_mobile/features/proof_detail_repair/proof_detail_repair_copy.dart';
import 'package:voicememory_mobile/features/proof_selection/proof_selection_principle.dart';
import 'package:voicememory_mobile/features/proof_trail_positioning/proof_trail_positioning.dart';
import 'package:voicememory_mobile/features/save_a_repeat_habit/save_a_repeat_habit.dart';
import 'package:voicememory_mobile/features/store_readiness/store_readiness_audit.dart';
import 'package:voicememory_mobile/features/store_readiness_proof/store_readiness_proof.dart';
import 'package:voicememory_mobile/features/store_readiness_proof/store_readiness_proof_copy.dart';
import 'package:voicememory_mobile/features/trail_language_guard/trail_language_guard.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_engine.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_model.dart';

StoreReadinessProofInput _input({
  bool revenueCatApiKeyProvided = true,
  bool revenueCatConfigured = true,
  bool productsLoaded = true,
  bool proEntitlementConfigured = true,
  bool purchaseFlowReachable = true,
  bool restorePurchasesReachable = true,
  bool restoreNoCrashVerified = true,
  bool purchasesUnavailableFallbackVerified = true,
  bool proStateCanBeRead = true,
  bool supportUrlSet = true,
  bool privacyUrlSet = true,
  bool appStoreMetadataReady = true,
  bool screenshotsReady = true,
  bool physicalDeviceSmokePassed = true,
  bool testFlightUploadReady = true,
  bool secretsRotated = true,
}) => StoreReadinessProofInput(
  revenueCatApiKeyProvided: revenueCatApiKeyProvided,
  revenueCatConfigured: revenueCatConfigured,
  productsLoaded: productsLoaded,
  proEntitlementConfigured: proEntitlementConfigured,
  purchaseFlowReachable: purchaseFlowReachable,
  restorePurchasesReachable: restorePurchasesReachable,
  restoreNoCrashVerified: restoreNoCrashVerified,
  purchasesUnavailableFallbackVerified: purchasesUnavailableFallbackVerified,
  proStateCanBeRead: proStateCanBeRead,
  supportUrlSet: supportUrlSet,
  privacyUrlSet: privacyUrlSet,
  appStoreMetadataReady: appStoreMetadataReady,
  screenshotsReady: screenshotsReady,
  physicalDeviceSmokePassed: physicalDeviceSmokePassed,
  testFlightUploadReady: testFlightUploadReady,
  secretsRotated: secretsRotated,
);

void main() {
  group('StoreReadinessProof.resolve', () {
    test('missing RevenueCat API key -> revenueCatMissing', () {
      expect(
        StoreReadinessProof.resolve(
          _input(revenueCatApiKeyProvided: false),
        ).status,
        StoreReadinessProofStatus.revenueCatMissing,
      );
    });

    test('products missing -> productsMissing', () {
      expect(
        StoreReadinessProof.resolve(_input(productsLoaded: false)).status,
        StoreReadinessProofStatus.productsMissing,
      );
    });

    test('entitlement missing -> entitlementMissing', () {
      expect(
        StoreReadinessProof.resolve(
          _input(proEntitlementConfigured: false),
        ).status,
        StoreReadinessProofStatus.entitlementMissing,
      );
    });

    test('pro state unreadable -> entitlementMissing', () {
      expect(
        StoreReadinessProof.resolve(_input(proStateCanBeRead: false)).status,
        StoreReadinessProofStatus.entitlementMissing,
      );
    });

    test('purchase path missing -> purchasePathMissing', () {
      expect(
        StoreReadinessProof.resolve(
          _input(purchaseFlowReachable: false),
        ).status,
        StoreReadinessProofStatus.purchasePathMissing,
      );
    });

    test('restore path missing -> restorePathMissing', () {
      expect(
        StoreReadinessProof.resolve(
          _input(restorePurchasesReachable: false),
        ).status,
        StoreReadinessProofStatus.restorePathMissing,
      );
    });

    test('restore crash not verified -> restorePathMissing', () {
      expect(
        StoreReadinessProof.resolve(
          _input(restoreNoCrashVerified: false),
        ).status,
        StoreReadinessProofStatus.restorePathMissing,
      );
    });

    test('unavailable fallback missing -> fallbackMissing', () {
      expect(
        StoreReadinessProof.resolve(
          _input(purchasesUnavailableFallbackVerified: false),
        ).status,
        StoreReadinessProofStatus.fallbackMissing,
      );
    });

    test('support/privacy/metadata missing -> metadataMissing', () {
      expect(
        StoreReadinessProof.resolve(_input(supportUrlSet: false)).status,
        StoreReadinessProofStatus.metadataMissing,
      );
    });

    test('screenshots missing -> screenshotsMissing', () {
      expect(
        StoreReadinessProof.resolve(_input(screenshotsReady: false)).status,
        StoreReadinessProofStatus.screenshotsMissing,
      );
    });

    test('physical device smoke missing -> deviceSmokeMissing', () {
      expect(
        StoreReadinessProof.resolve(
          _input(physicalDeviceSmokePassed: false),
        ).status,
        StoreReadinessProofStatus.deviceSmokeMissing,
      );
    });

    test('TestFlight upload missing -> testFlightMissing', () {
      expect(
        StoreReadinessProof.resolve(
          _input(testFlightUploadReady: false),
        ).status,
        StoreReadinessProofStatus.testFlightMissing,
      );
    });

    test(
      'all store items pass but secrets not rotated -> readyForTestFlight',
      () {
        expect(
          StoreReadinessProof.resolve(_input(secretsRotated: false)).status,
          StoreReadinessProofStatus.readyForTestFlight,
        );
      },
    );

    test('all store items and secrets rotated -> readyForSubmission', () {
      expect(
        StoreReadinessProof.resolve(_input()).status,
        StoreReadinessProofStatus.readyForSubmission,
      );
    });
  });

  group('StoreReadinessProofCopy', () {
    test('headline says Store readiness proof', () {
      expect(StoreReadinessProofCopy.headline, 'Store readiness proof');
    });

    test('body blocks new product features until store readiness proven', () {
      expect(
        StoreReadinessProofCopy.body,
        contains('should not add more product features'),
      );
      expect(StoreReadinessProofCopy.body, contains('device smoke are proven'));
    });

    test('revenueCatLine says real API key', () {
      expect(StoreReadinessProofCopy.revenueCatLine, contains('real API key'));
    });

    test('restoreLine says reachable and must not crash', () {
      expect(StoreReadinessProofCopy.restoreLine, contains('reachable'));
      expect(StoreReadinessProofCopy.restoreLine, contains('must not crash'));
    });

    test('entitlementLine says Pro state readable', () {
      expect(
        StoreReadinessProofCopy.entitlementLine,
        contains('Pro state must be readable'),
      );
    });

    test('fallbackLine says purchases unavailable keeps app usable', () {
      expect(
        StoreReadinessProofCopy.fallbackLine,
        contains('purchases are unavailable'),
      );
      expect(
        StoreReadinessProofCopy.fallbackLine,
        contains('keep the app usable'),
      );
    });

    test(
      'metadataLine mentions support URL/privacy URL/screenshots/App Store metadata',
      () {
        final line = StoreReadinessProofCopy.metadataLine;
        expect(line, contains('Support URL'));
        expect(line, contains('privacy URL'));
        expect(line, contains('screenshots'));
        expect(line, contains('App Store metadata'));
      },
    );

    test('deviceLine says physical-device smoke test', () {
      expect(
        StoreReadinessProofCopy.deviceLine,
        contains('physical-device smoke test'),
      );
    });

    test('secretsLine says rotate exposed Stripe secrets', () {
      expect(
        StoreReadinessProofCopy.secretsLine,
        contains('rotate exposed Stripe secrets'),
      );
    });

    test('guardrail says no new product features before blockers cleared', () {
      expect(
        StoreReadinessProofCopy.guardrail,
        contains('No new product features before store readiness blockers'),
      );
    });

    test('copy does not introduce ranking', () {
      for (final text in StoreReadinessProofCopy.allVisibleStrings()) {
        expect(text.toLowerCase().contains('ranking'), isFalse, reason: text);
      }
    });

    test('copy does not introduce chat/storage positioning', () {
      for (final text in StoreReadinessProofCopy.allVisibleStrings()) {
        final lower = text.toLowerCase();
        expect(lower.contains('voice chat'), isFalse, reason: text);
        expect(lower.contains('storage app'), isFalse, reason: text);
        expect(lower.contains('chat box'), isFalse, reason: text);
      }
    });

    test('copy avoids therapy diagnosis coaching and advice claims', () {
      for (final text in StoreReadinessProofCopy.allVisibleStrings()) {
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
    test('module does not rewrite purchase entitlement or paywall logic', () {
      for (final path in [
        'lib/features/store_readiness_proof/store_readiness_proof.dart',
        'lib/features/store_readiness_proof/store_readiness_proof_copy.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source.contains('importance_scoring'), isFalse);
        expect(source.contains('anchor_specificity_guard'), isFalse);
        expect(source.contains('journal_storage'), isFalse);
        expect(source.contains('paywall_source'), isFalse);
      }
    });

    test('existing store readiness modules behaviour unchanged', () {
      final checklist = ProductionCandidateChecklist(
        betaResultsPassed: true,
        proofProtectionBaselineActive: true,
        usefulProofStable: true,
        tooVagueNotRelevantLow: true,
        firstSessionTargetMet: true,
        evidenceTrailClearTargetMet: true,
        proUnderstandingTargetMet: true,
        pricingSignalAcceptable: true,
        restorePurchasesVerified: true,
        revenueCatProductsVerified: true,
        appStoreSupportUrlReady: true,
        privacyPolicyReady: true,
        appStoreScreenshotsReady: true,
        appStoreMetadataReady: true,
        productionSecretsRotated: true,
        physicalDeviceSmokeTestPassed: true,
        testFlightBuildUploaded: true,
      );
      expect(
        checklist.resolveStatus(),
        ProductionCandidateStatus.readyForSubmission,
      );
      expect(
        StoreReadinessAudit.fromProductionCandidateChecklist(
          checklist,
        ).resolveStatus(),
        StoreReadinessStatus.readyForSubmission,
      );
    });

    test('existing interpretation modules behaviour unchanged', () {
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
