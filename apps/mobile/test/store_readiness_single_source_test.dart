import 'dart:io';

import 'package:archiveme_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:archiveme_mobile/features/freeze_drift_scanner/freeze_drift_scanner.dart';
import 'package:archiveme_mobile/features/paid_intent_beta_proof/paid_intent_beta_proof_copy.dart';
import 'package:archiveme_mobile/features/production_candidate/production_candidate_checklist.dart';
import 'package:archiveme_mobile/features/proof_detail_repair/proof_detail_repair_copy.dart';
import 'package:archiveme_mobile/features/proof_selection/proof_selection_principle.dart';
import 'package:archiveme_mobile/features/release_candidate_freeze/release_candidate_freeze_copy.dart';
import 'package:archiveme_mobile/features/revenuecat_sandbox_proof/revenuecat_sandbox_proof_copy.dart';
import 'package:archiveme_mobile/features/store_readiness/store_readiness_audit.dart';
import 'package:archiveme_mobile/features/store_readiness_proof/store_readiness_proof.dart';
import 'package:archiveme_mobile/features/store_readiness_single_source/store_readiness_single_source.dart';
import 'package:archiveme_mobile/features/store_readiness_single_source/store_readiness_single_source_copy.dart';
import 'package:archiveme_mobile/features/surface_priority/surface_priority_engine.dart';
import 'package:archiveme_mobile/features/surface_priority/surface_priority_model.dart';
import 'package:flutter_test/flutter_test.dart';

const _docsPath = 'docs/architecture/store_readiness_single_source.md';

StoreReadinessSingleSourceInput _input({
  bool signingConfigured = true,
  bool appStoreMetadataReady = true,
  bool supportUrlSet = true,
  bool privacyUrlSet = true,
  bool termsUrlSet = true,
  bool screenshotsReady = true,
  bool revenueCatApiKeyProvided = true,
  bool revenueCatConfigured = true,
  bool productsLoaded = true,
  bool proEntitlementConfigured = true,
  bool purchaseFlowReachable = true,
  bool restorePurchasesReachable = true,
  bool restoreNoCrashVerified = true,
  bool purchasesUnavailableFallbackVerified = true,
  bool proStateCanBeRead = true,
  bool entitlementPersistsAfterRestart = true,
  bool physicalDeviceSmokePassed = true,
  bool testFlightUploadReady = true,
  bool paidIntentBetaReady = true,
  bool secretsRotated = true,
  ProductionCandidateChecklist? productionChecklist,
}) => StoreReadinessSingleSourceInput(
  signingConfigured: signingConfigured,
  appStoreMetadataReady: appStoreMetadataReady,
  supportUrlSet: supportUrlSet,
  privacyUrlSet: privacyUrlSet,
  termsUrlSet: termsUrlSet,
  screenshotsReady: screenshotsReady,
  revenueCatApiKeyProvided: revenueCatApiKeyProvided,
  revenueCatConfigured: revenueCatConfigured,
  productsLoaded: productsLoaded,
  proEntitlementConfigured: proEntitlementConfigured,
  purchaseFlowReachable: purchaseFlowReachable,
  restorePurchasesReachable: restorePurchasesReachable,
  restoreNoCrashVerified: restoreNoCrashVerified,
  purchasesUnavailableFallbackVerified: purchasesUnavailableFallbackVerified,
  proStateCanBeRead: proStateCanBeRead,
  entitlementPersistsAfterRestart: entitlementPersistsAfterRestart,
  physicalDeviceSmokePassed: physicalDeviceSmokePassed,
  testFlightUploadReady: testFlightUploadReady,
  paidIntentBetaReady: paidIntentBetaReady,
  secretsRotated: secretsRotated,
  productionChecklist: productionChecklist,
);

StoreReadinessSingleSourceStep _step(
  StoreReadinessSingleSourceResult result,
  StoreReadinessSingleSourceStepId id,
) => result.steps.firstWhere((step) => step.id == id);

ProductionCandidateChecklist _fullChecklist() =>
    const ProductionCandidateChecklist(
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

void main() {
  group('StoreReadinessSingleSource.build', () {
    test('canonical order has 12 steps', () {
      final result = StoreReadinessSingleSource.build(_input());
      expect(
        result.steps.length,
        StoreReadinessSingleSource.canonicalStepCount,
      );
      expect(result.steps.map((step) => step.id).toList(), [
        StoreReadinessSingleSourceStepId.signing,
        StoreReadinessSingleSourceStepId.metadata,
        StoreReadinessSingleSourceStepId.supportPrivacyTerms,
        StoreReadinessSingleSourceStepId.screenshots,
        StoreReadinessSingleSourceStepId.revenueCatProducts,
        StoreReadinessSingleSourceStepId.purchasePath,
        StoreReadinessSingleSourceStepId.restorePath,
        StoreReadinessSingleSourceStepId.entitlementPersistence,
        StoreReadinessSingleSourceStepId.physicalDeviceSmoke,
        StoreReadinessSingleSourceStepId.testFlightUpload,
        StoreReadinessSingleSourceStepId.paidIntentBeta,
        StoreReadinessSingleSourceStepId.secretsRotation,
      ]);
    });

    test('signing missing -> notReady', () {
      final result = StoreReadinessSingleSource.build(
        _input(signingConfigured: false),
      );
      expect(result.decision, StoreReadinessSingleSourceDecision.notReady);
      expect(result.earliestGap, StoreReadinessSingleSourceStepId.signing);
      expect(result.testFlightReady, isFalse);
    });

    test('metadata missing -> notReady', () {
      final result = StoreReadinessSingleSource.build(
        _input(appStoreMetadataReady: false),
      );
      expect(result.decision, StoreReadinessSingleSourceDecision.notReady);
      expect(result.earliestGap, StoreReadinessSingleSourceStepId.metadata);
    });

    test('support/privacy/terms missing -> notReady', () {
      final result = StoreReadinessSingleSource.build(
        _input(supportUrlSet: false),
      );
      expect(result.decision, StoreReadinessSingleSourceDecision.notReady);
      expect(
        result.earliestGap,
        StoreReadinessSingleSourceStepId.supportPrivacyTerms,
      );
    });

    test('screenshots missing -> notReady', () {
      final result = StoreReadinessSingleSource.build(
        _input(screenshotsReady: false),
      );
      expect(result.decision, StoreReadinessSingleSourceDecision.notReady);
      expect(result.earliestGap, StoreReadinessSingleSourceStepId.screenshots);
    });

    test('RevenueCat products missing -> notReady', () {
      final result = StoreReadinessSingleSource.build(
        _input(productsLoaded: false),
      );
      expect(result.decision, StoreReadinessSingleSourceDecision.notReady);
      expect(
        result.earliestGap,
        StoreReadinessSingleSourceStepId.revenueCatProducts,
      );
    });

    test('purchase path missing -> notReady', () {
      final result = StoreReadinessSingleSource.build(
        _input(purchaseFlowReachable: false),
      );
      expect(result.decision, StoreReadinessSingleSourceDecision.notReady);
      expect(result.earliestGap, StoreReadinessSingleSourceStepId.purchasePath);
    });

    test('restore path missing -> notReady', () {
      final result = StoreReadinessSingleSource.build(
        _input(restorePurchasesReachable: false),
      );
      expect(result.decision, StoreReadinessSingleSourceDecision.notReady);
      expect(result.earliestGap, StoreReadinessSingleSourceStepId.restorePath);
    });

    test('entitlement persistence missing -> notReady', () {
      final result = StoreReadinessSingleSource.build(
        _input(entitlementPersistsAfterRestart: false),
      );
      expect(result.decision, StoreReadinessSingleSourceDecision.notReady);
      expect(
        result.earliestGap,
        StoreReadinessSingleSourceStepId.entitlementPersistence,
      );
    });

    test('physical device smoke missing -> notReady', () {
      final result = StoreReadinessSingleSource.build(
        _input(physicalDeviceSmokePassed: false),
      );
      expect(result.decision, StoreReadinessSingleSourceDecision.notReady);
      expect(
        result.earliestGap,
        StoreReadinessSingleSourceStepId.physicalDeviceSmoke,
      );
    });

    test('TestFlight upload missing -> notReady', () {
      final result = StoreReadinessSingleSource.build(
        _input(testFlightUploadReady: false),
      );
      expect(result.decision, StoreReadinessSingleSourceDecision.notReady);
      expect(
        result.earliestGap,
        StoreReadinessSingleSourceStepId.testFlightUpload,
      );
    });

    test(
      'TestFlight block clear but paid intent pending -> paidIntentPending',
      () {
        final result = StoreReadinessSingleSource.build(
          _input(paidIntentBetaReady: false),
        );
        expect(
          result.decision,
          StoreReadinessSingleSourceDecision.paidIntentPending,
        );
        expect(result.testFlightReady, isTrue);
        expect(result.submissionReady, isFalse);
        expect(
          result.earliestGap,
          StoreReadinessSingleSourceStepId.paidIntentBeta,
        );
        expect(
          _step(
            result,
            StoreReadinessSingleSourceStepId.paidIntentBeta,
          ).detailLabel,
          StoreReadinessSingleSourceCopy.detailPending,
        );
      },
    );

    test('paid intent ready but secrets pending -> secretsPending', () {
      final result = StoreReadinessSingleSource.build(
        _input(secretsRotated: false),
      );
      expect(
        result.decision,
        StoreReadinessSingleSourceDecision.secretsPending,
      );
      expect(result.testFlightReady, isTrue);
      expect(result.submissionReady, isFalse);
      expect(
        result.earliestGap,
        StoreReadinessSingleSourceStepId.secretsRotation,
      );
    });

    test('all canonical steps pass -> submissionReady', () {
      final result = StoreReadinessSingleSource.build(_input());
      expect(
        result.decision,
        StoreReadinessSingleSourceDecision.submissionReady,
      );
      expect(result.testFlightReady, isTrue);
      expect(result.submissionReady, isTrue);
      expect(result.earliestGap, isNull);
    });
  });

  group('StoreReadinessSingleSource bridges', () {
    test(
      'toProofInput delegates to StoreReadinessProof without duplicating logic',
      () {
        final input = _input(secretsRotated: false);
        final proofInput = StoreReadinessSingleSource.toProofInput(input);
        final proofResult = StoreReadinessProof.resolve(proofInput);
        final result = StoreReadinessSingleSource.build(input);

        expect(result.proofResult.status, proofResult.status);
        expect(
          result.proofResult.status,
          StoreReadinessProofStatus.readyForTestFlight,
        );
      },
    );

    test('fromProofInput round-trips proof fields', () {
      const proofInput = StoreReadinessProofInput(
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
      final singleInput = StoreReadinessSingleSource.fromProofInput(
        proofInput,
        signingConfigured: true,
        entitlementPersistsAfterRestart: true,
        paidIntentBetaReady: true,
      );
      final roundTrip = StoreReadinessSingleSource.toProofInput(singleInput);

      expect(
        roundTrip.revenueCatApiKeyProvided,
        proofInput.revenueCatApiKeyProvided,
      );
      expect(roundTrip.productsLoaded, proofInput.productsLoaded);
      expect(roundTrip.testFlightUploadReady, proofInput.testFlightUploadReady);
      expect(roundTrip.secretsRotated, proofInput.secretsRotated);
    });

    test('fromProductionCandidateChecklist bridges checklist and proof', () {
      final checklist = _fullChecklist();
      final input = StoreReadinessSingleSource.fromProductionCandidateChecklist(
        checklist,
        signingConfigured: true,
        entitlementPersistsAfterRestart: true,
        paidIntentBetaReady: true,
      );
      final result = StoreReadinessSingleSource.build(input);

      expect(
        result.productionStatus,
        ProductionCandidateStatus.readyForSubmission,
      );
      expect(
        result.decision,
        StoreReadinessSingleSourceDecision.submissionReady,
      );
      expect(
        StoreReadinessProof.fromProductionCandidateChecklist(
          checklist,
        ).appStoreMetadataReady,
        isTrue,
      );
    });

    test('fromStoreReadinessAudit bridges audit status', () {
      final checklist = _fullChecklist();
      final audit = StoreReadinessAudit.fromProductionCandidateChecklist(
        checklist,
      );
      final input = StoreReadinessSingleSource.fromStoreReadinessAudit(
        audit,
        signingConfigured: true,
        entitlementPersistsAfterRestart: true,
        paidIntentBetaReady: true,
        productionChecklist: checklist,
      );
      final result = StoreReadinessSingleSource.build(input);

      expect(result.auditStatus, StoreReadinessStatus.readyForSubmission);
      expect(
        StoreReadinessSingleSource.toAudit(input).resolveStatus(),
        audit.resolveStatus(),
      );
    });

    test('report exposes canonical copy', () {
      final report = StoreReadinessSingleSource.report(
        StoreReadinessSingleSource.build(_input()),
      );
      expect(report.headline, StoreReadinessSingleSourceCopy.headline);
      expect(report.orderLine, StoreReadinessSingleSourceCopy.orderLine);
      expect(report.guardrail, StoreReadinessSingleSourceCopy.guardrail);
    });
  });

  group('StoreReadinessSingleSourceCopy', () {
    test('headline says single source', () {
      expect(
        StoreReadinessSingleSourceCopy.headline,
        'Store readiness single source',
      );
    });

    test('orderLine lists canonical release order', () {
      const order = StoreReadinessSingleSourceCopy.orderLine;
      expect(order, contains('signing'));
      expect(order, contains('metadata'));
      expect(order, contains('support/privacy/terms'));
      expect(order, contains('screenshots'));
      expect(order, contains('RevenueCat products'));
      expect(order, contains('purchase path'));
      expect(order, contains('restore path'));
      expect(order, contains('entitlement'));
      expect(order, contains('physical device smoke'));
      expect(order, contains('TestFlight upload'));
      expect(order, contains('paid intent'));
      expect(order, contains('secrets rotation'));
    });

    test('guardrail blocks purchase paywall RevenueCat behavior changes', () {
      expect(
        StoreReadinessSingleSourceCopy.guardrail,
        contains('Do not change'),
      );
      expect(StoreReadinessSingleSourceCopy.guardrail, contains('purchase'));
      expect(StoreReadinessSingleSourceCopy.guardrail, contains('RevenueCat'));
    });

    test('copy avoids therapy diagnosis coaching and advice claims', () {
      for (final text in StoreReadinessSingleSourceCopy.allVisibleStrings()) {
        expect(ProofSurfaceAdviceGuard.passes(text), isTrue, reason: text);
        final lower = text.toLowerCase();
        expect(lower.contains('advice'), isFalse, reason: text);
        expect(lower.contains('coaching'), isFalse, reason: text);
        expect(lower.contains('therapy'), isFalse, reason: text);
        expect(lower.contains('diagnosis'), isFalse, reason: text);
      }
    });

    test('docs file exists and references canonical order', () {
      final docs = File(_docsPath).readAsStringSync();
      expect(docs, contains('12'));
      expect(docs.toLowerCase(), contains('signing'));
      expect(docs, contains('StoreReadinessProof'));
      expect(docs, contains('StoreReadinessAudit'));
    });
  });

  group('Protected areas', () {
    test('module does not import purchase paywall or RevenueCat SDK paths', () {
      for (final path in [
        'lib/features/store_readiness_single_source/store_readiness_single_source.dart',
        'lib/features/store_readiness_single_source/store_readiness_single_source_copy.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source.contains('paywall_source'), isFalse);
        expect(source.contains('purchases_flutter'), isFalse);
        expect(source.contains('importance_scoring'), isFalse);
      }
    });

    test('existing store readiness modules behaviour unchanged', () {
      final checklist = _fullChecklist();
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

    test('freeze drift scanner still blocks risky drift during freeze', () {
      final result = FreezeDriftScanner.scan(
        const FreezeDriftScannerInput(
          freezeActive: true,
          category: FreezeDriftCategory.newDashboard,
        ),
      );
      expect(result.decision, FreezeDriftDecision.blocked);
    });

    test('paid intent beta proof copy still registered in advice guard', () {
      expect(
        ProofSurfaceAdviceGuard.passes(PaidIntentBetaProofCopy.headline),
        isTrue,
      );
    });

    test(
      'revenuecat sandbox proof and release freeze regressions unchanged',
      () {
        expect(RevenueCatSandboxProofCopy.headline, isNotEmpty);
        expect(ReleaseCandidateFreezeCopy.headline, isNotEmpty);
      },
    );

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