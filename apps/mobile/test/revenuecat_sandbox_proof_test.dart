import 'dart:io';

import 'package:archiveme_mobile/billing/archive_loop_entitlement_ids.dart';
import 'package:archiveme_mobile/billing/revenuecat_diagnostics.dart';
import 'package:archiveme_mobile/billing/revenuecat_purchase_journey.dart';
import 'package:archiveme_mobile/billing/revenuecat_service.dart';
import 'package:archiveme_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:archiveme_mobile/features/change_trail_clarity/change_trail_clarity.dart';
import 'package:archiveme_mobile/features/core_archive_journey/core_archive_journey.dart';
import 'package:archiveme_mobile/features/pro_single_promise/pro_single_promise.dart';
import 'package:archiveme_mobile/features/proof_detail_repair/proof_detail_repair_copy.dart';
import 'package:archiveme_mobile/features/proof_selection/proof_selection_principle.dart';
import 'package:archiveme_mobile/features/release_blocker_priority/release_blocker_priority.dart';
import 'package:archiveme_mobile/features/release_candidate_freeze/release_candidate_freeze.dart';
import 'package:archiveme_mobile/features/revenuecat_sandbox_proof/revenuecat_sandbox_proof.dart';
import 'package:archiveme_mobile/features/revenuecat_sandbox_proof/revenuecat_sandbox_proof_copy.dart';
import 'package:archiveme_mobile/features/surface_priority/surface_priority_engine.dart';
import 'package:archiveme_mobile/features/surface_priority/surface_priority_model.dart';
import 'package:flutter_test/flutter_test.dart';

RevenueCatSandboxProofInput _input({
  bool iosApiKeyPresent = true,
  bool offeringLoads = true,
  bool productTitlePriceVisible = true,
  bool? storeKitSheetAppears = true,
  bool? sandboxPurchaseSucceeds = true,
  bool? proEntitlementActive = true,
  bool? proGateUnlocks = true,
  bool? restorePurchasesSucceeds = true,
  bool? entitlementPersistsAfterRestart = true,
  bool? missingKeyNoCrash,
}) => RevenueCatSandboxProofInput(
  iosApiKeyPresent: iosApiKeyPresent,
  offeringLoads: offeringLoads,
  productTitlePriceVisible: productTitlePriceVisible,
  storeKitSheetAppears: storeKitSheetAppears,
  sandboxPurchaseSucceeds: sandboxPurchaseSucceeds,
  proEntitlementActive: proEntitlementActive,
  proGateUnlocks: proGateUnlocks,
  restorePurchasesSucceeds: restorePurchasesSucceeds,
  entitlementPersistsAfterRestart: entitlementPersistsAfterRestart,
  missingKeyNoCrash: missingKeyNoCrash,
);

RevenueCatSandboxProofCheck _check(
  RevenueCatSandboxProofResult result,
  RevenueCatSandboxProofCheckId id,
) => result.checks.firstWhere((check) => check.id == id);

void main() {
  group('RevenueCatSandboxProof.build', () {
    test('all checks pass -> proved', () {
      final result = RevenueCatSandboxProof.build(_input());
      expect(result.decision, RevenueCatSandboxProofDecision.proved);
      expect(result.allPassed, isTrue);
      expect(result.earliestBlocker, isNull);
    });

    test('missing API key blocks offering and later checks', () {
      final result = RevenueCatSandboxProof.build(
        const RevenueCatSandboxProofInput(
          missingKeyNoCrash: true,
        ),
      );

      expect(result.decision, RevenueCatSandboxProofDecision.fallbackVerified);
      expect(
        _check(result, RevenueCatSandboxProofCheckId.iosApiKeyPresent).status,
        RevenueCatSandboxProofStatus.fail,
      );
      expect(
        _check(result, RevenueCatSandboxProofCheckId.offeringLoads).status,
        RevenueCatSandboxProofStatus.blocked,
      );
      expect(
        _check(result, RevenueCatSandboxProofCheckId.missingKeyNoCrash).status,
        RevenueCatSandboxProofStatus.pass,
      );
    });

    test('offering missing -> blocked at offering step', () {
      final result = RevenueCatSandboxProof.build(
        _input(offeringLoads: false, productTitlePriceVisible: false),
      );

      expect(result.decision, RevenueCatSandboxProofDecision.blocked);
      expect(
        result.earliestBlocker,
        RevenueCatSandboxProofCheckId.offeringLoads,
      );
      expect(
        _check(
          result,
          RevenueCatSandboxProofCheckId.storeKitSheetAppears,
        ).status,
        RevenueCatSandboxProofStatus.blocked,
      );
    });

    test('product missing blocks manual purchase steps', () {
      final result = RevenueCatSandboxProof.build(
        _input(productTitlePriceVisible: false, storeKitSheetAppears: null),
      );

      expect(result.decision, RevenueCatSandboxProofDecision.blocked);
      expect(
        _check(
          result,
          RevenueCatSandboxProofCheckId.storeKitSheetAppears,
        ).status,
        RevenueCatSandboxProofStatus.blocked,
      );
    });

    test(
      'automated checks pass but manual steps pending -> manualRequired',
      () {
        final result = RevenueCatSandboxProof.build(
          _input(
            storeKitSheetAppears: null,
            sandboxPurchaseSucceeds: null,
            proEntitlementActive: null,
            proGateUnlocks: null,
            restorePurchasesSucceeds: null,
            entitlementPersistsAfterRestart: null,
          ),
        );

        expect(result.decision, RevenueCatSandboxProofDecision.manualRequired);
        expect(
          _check(
            result,
            RevenueCatSandboxProofCheckId.storeKitSheetAppears,
          ).status,
          RevenueCatSandboxProofStatus.pending,
        );
      },
    );

    test('sandbox purchase failure blocks entitlement checks', () {
      final result = RevenueCatSandboxProof.build(
        _input(sandboxPurchaseSucceeds: false, proEntitlementActive: null),
      );

      expect(result.decision, RevenueCatSandboxProofDecision.blocked);
      expect(
        result.earliestBlocker,
        RevenueCatSandboxProofCheckId.sandboxPurchaseSucceeds,
      );
      expect(
        _check(
          result,
          RevenueCatSandboxProofCheckId.proEntitlementActive,
        ).status,
        RevenueCatSandboxProofStatus.blocked,
      );
    });

    test('recognizes archive_loop_pro entitlement', () {
      expect(
        RevenueCatSandboxProof.recognizesProEntitlement([
          ArchiveLoopEntitlementIds.archiveLoopPro,
        ]),
        isTrue,
      );
    });

    test('recognizes legacy pro entitlement', () {
      expect(
        RevenueCatSandboxProof.recognizesProEntitlement([
          ArchiveLoopEntitlementIds.revenueCatLegacyPro,
        ]),
        isTrue,
      );
    });

    test('fromDiagnostics maps configured offering state', () {
      final input = RevenueCatSandboxProof.fromDiagnostics(
        const RevenueCatDiagnostics(
          revenueCatConfigured: true,
          apiKeyMissing: false,
          offeringsLoaded: true,
          offeringCount: 1,
          packageCount: 1,
          currentOfferingId: 'default',
        ),
        productTitlePriceVisible: true,
      );
      final result = RevenueCatSandboxProof.build(input);

      expect(
        _check(result, RevenueCatSandboxProofCheckId.iosApiKeyPresent).status,
        RevenueCatSandboxProofStatus.pass,
      );
      expect(
        _check(result, RevenueCatSandboxProofCheckId.offeringLoads).status,
        RevenueCatSandboxProofStatus.pass,
      );
    });

    test('fromPurchaseJourney maps purchase and restore success', () {
      final journey = RevenueCatPurchaseJourney()
        ..offeringLoaded = true
        ..purchaseCompleted = true
        ..entitlementReceived = true
        ..restoreCompleted = true
        ..entitlementIds = [ArchiveLoopEntitlementIds.archiveLoopPro];

      final input = RevenueCatSandboxProof.fromPurchaseJourney(
        journey,
        diagnostics: const RevenueCatDiagnostics(
          revenueCatConfigured: true,
          apiKeyMissing: false,
          offeringsLoaded: true,
          offeringCount: 1,
          packageCount: 1,
        ),
        productTitlePriceVisible: true,
        storeKitSheetAppears: true,
        proGateUnlocks: true,
        entitlementPersistsAfterRestart: true,
      );
      final result = RevenueCatSandboxProof.build(input);

      expect(result.decision, RevenueCatSandboxProofDecision.proved);
      expect(
        _check(
          result,
          RevenueCatSandboxProofCheckId.sandboxPurchaseSucceeds,
        ).status,
        RevenueCatSandboxProofStatus.pass,
      );
      expect(
        _check(
          result,
          RevenueCatSandboxProofCheckId.restorePurchasesSucceeds,
        ).status,
        RevenueCatSandboxProofStatus.pass,
      );
    });
  });

  group('RevenueCatSandboxProofCopy', () {
    test('lists all ten acceptance checks', () {
      final labels = [
        RevenueCatSandboxProofCopy.checkIosApiKeyPresent,
        RevenueCatSandboxProofCopy.checkOfferingLoads,
        RevenueCatSandboxProofCopy.checkProductTitlePriceVisible,
        RevenueCatSandboxProofCopy.checkStoreKitSheetAppears,
        RevenueCatSandboxProofCopy.checkSandboxPurchaseSucceeds,
        RevenueCatSandboxProofCopy.checkProEntitlementActive,
        RevenueCatSandboxProofCopy.checkProGateUnlocks,
        RevenueCatSandboxProofCopy.checkRestorePurchasesSucceeds,
        RevenueCatSandboxProofCopy.checkEntitlementPersistsAfterRestart,
        RevenueCatSandboxProofCopy.checkMissingKeyNoCrash,
      ];
      expect(labels, hasLength(10));
    });

    test('guardrail blocks product promise and pricing changes', () {
      final lower = RevenueCatSandboxProofCopy.guardrail.toLowerCase();
      expect(lower, contains('product promise'));
      expect(lower, contains('pricing copy'));
      expect(lower, contains('pro benefits'));
    });

    test('copy avoids therapy diagnosis coaching and advice claims', () {
      for (final text in RevenueCatSandboxProofCopy.allVisibleStrings()) {
        expect(ProofSurfaceAdviceGuard.passes(text), isTrue, reason: text);
      }
    });
  });

  group('Release smoke', () {
    test('missing RevenueCat key does not crash initialize', () async {
      final rc = RevenueCatService.instance;
      await rc.initialize();
      expect(rc.isConfigured, isFalse);
      expect(rc.diagnostics.apiKeyMissing, isTrue);
    });
  });

  group('Protected areas', () {
    test('module does not import purchases_flutter or billing UI', () {
      for (final path in [
        'lib/features/revenuecat_sandbox_proof/revenuecat_sandbox_proof.dart',
        'lib/features/revenuecat_sandbox_proof/revenuecat_sandbox_proof_copy.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source.contains('package:purchases_flutter'), isFalse);
        expect(source.contains('paywall_source'), isFalse);
        expect(source.contains('importance_scoring'), isFalse);
      }
    });

    test('release candidate freeze still blocks new product feature', () {
      expect(
        ReleaseCandidateFreeze.build(
          const ReleaseCandidateFreezeInput(
            changeType: ReleaseCandidateChangeType.newProductFeature,
            blocksRelease: false,
            blocksPurchase: false,
            blocksRestore: false,
            blocksEntitlement: false,
            causesCrash: false,
            risksAppStoreRejection: false,
            affectsSecuritySecrets: false,
            fixesFirstJourneyComprehension: false,
            fixesCriticalProofTrust: false,
            addsNewUserFacingSurface: false,
            changesPricingOrPaywall: false,
            changesProofThresholds: false,
            changesRecordLayout: false,
          ),
        ).allowed,
        isFalse,
      );
    });

    test('release blocker priority still puts purchase before proof trust', () {
      expect(
        ReleaseBlockerPriority.build(
          const ReleaseBlockerPriorityInput(
            freezeActive: true,
            hasSecuritySecretsBlocker: false,
            hasCrash: false,
            blocksStoreReadiness: false,
            risksAppStoreRejection: false,
            blocksPurchase: true,
            blocksRestore: false,
            blocksEntitlement: false,
            firstJourneyComprehensionWeak: false,
            criticalProofTrustWeak: true,
            paidIntentSignalWeak: false,
          ),
        ).decision,
        ReleaseBlockerPriorityDecision.fixPurchaseFirst,
      );
    });

    test('pro single promise still reaches release candidate', () {
      expect(
        ProSinglePromise.build(
          const ProSinglePromiseInput(
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
          ),
        ).decision,
        ProSinglePromiseDecision.releaseCandidate,
      );
    });

    test('proof selection principle still blocks ranking', () {
      expect(ProofSelectionPrinciple.allowsRankingUi(), isFalse);
      expect(
        ProofDetailRepairCopy.whyThisOneLine,
        contains('clearest specific repeat'),
      );
    });

    test('record screen remains capture-first', () {
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

    test('core archive journey still blocks voice assistant positioning', () {
      expect(
        CoreArchiveJourneyGuardrail.allowsVoiceAssistantPositioning(),
        isFalse,
      );
      expect(
        ChangeTrailClarity.resolve(_fullTrailSummary()),
        ChangeTrailClarityDecision.releaseCandidate,
      );
    });
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