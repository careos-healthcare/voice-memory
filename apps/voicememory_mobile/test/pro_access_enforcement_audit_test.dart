import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/freeze_drift_scanner/freeze_drift_scanner.dart';
import 'package:voicememory_mobile/features/paid_intent_beta_proof/paid_intent_beta_proof_copy.dart';
import 'package:voicememory_mobile/billing/revenuecat_diagnostics.dart';
import 'package:voicememory_mobile/features/pro_access_enforcement/pro_access_enforcement_audit.dart';
import 'package:voicememory_mobile/features/pro_access_enforcement/pro_access_enforcement_audit_v2.dart';
import 'package:voicememory_mobile/features/pro_access_enforcement/pro_access_enforcement_audit_v2_copy.dart';
import 'package:voicememory_mobile/features/pro_access_enforcement/pro_access_enforcement_audit_v3.dart';
import 'package:voicememory_mobile/features/pro_access_enforcement/pro_access_enforcement_audit_v3_copy.dart';
import 'package:voicememory_mobile/features/pro_access_enforcement/pro_access_enforcement_audit_copy.dart';
import 'package:voicememory_mobile/features/proof_detail_repair/proof_detail_repair_copy.dart';
import 'package:voicememory_mobile/features/proof_selection/proof_selection_principle.dart';
import 'package:voicememory_mobile/features/release_candidate_freeze/release_candidate_freeze.dart';
import 'package:voicememory_mobile/features/release_candidate_freeze/release_candidate_freeze_copy.dart';
import 'package:voicememory_mobile/features/revenuecat_sandbox_proof/revenuecat_sandbox_proof_copy.dart';
import 'package:voicememory_mobile/features/store_readiness_single_source/store_readiness_single_source.dart';
import 'package:voicememory_mobile/features/store_readiness_single_source/store_readiness_single_source_copy.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_engine.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_model.dart';

const _docsPath = 'docs/pro_access_enforcement_audit.md';

ProAccessEnforcementAuditInput _input({
  bool revenueCatConfigured = true,
  bool proEntitlementReadable = true,
  bool restorePurchasesReachable = true,
  bool restoreNoCrashVerified = true,
  bool localCachePreventsStalePro = true,
  bool entitlementPersistsAfterRestart = true,
  bool revenueCatLinkedToAccount = false,
  bool serverSideEntitlementCheckPresent = true,
  bool privacyLockIndependentOfPro = true,
  bool deviceSharingPrevented = false,
}) =>
    ProAccessEnforcementAuditInput(
      revenueCatConfigured: revenueCatConfigured,
      proEntitlementReadable: proEntitlementReadable,
      restorePurchasesReachable: restorePurchasesReachable,
      restoreNoCrashVerified: restoreNoCrashVerified,
      localCachePreventsStalePro: localCachePreventsStalePro,
      entitlementPersistsAfterRestart: entitlementPersistsAfterRestart,
      revenueCatLinkedToAccount: revenueCatLinkedToAccount,
      serverSideEntitlementCheckPresent: serverSideEntitlementCheckPresent,
      privacyLockIndependentOfPro: privacyLockIndependentOfPro,
      deviceSharingPrevented: deviceSharingPrevented,
    );

ProAccessEnforcementAuditItem _item(
  ProAccessEnforcementAuditResult result,
  ProAccessEnforcementAuditItemId id,
) =>
    result.items.firstWhere((item) => item.id == id);

void main() {
  group('ProAccessEnforcementAudit.build', () {
    test('audit has eight canonical items', () {
      final result = ProAccessEnforcementAudit.build(_input());
      expect(result.items.length, ProAccessEnforcementAudit.auditItemCount);
      expect(
        result.items.map((item) => item.id).toList(),
        [
          ProAccessEnforcementAuditItemId.revenueCatEntitlement,
          ProAccessEnforcementAuditItemId.restoreEntitlement,
          ProAccessEnforcementAuditItemId.localCache,
          ProAccessEnforcementAuditItemId.reinstallBehavior,
          ProAccessEnforcementAuditItemId.accountIdentity,
          ProAccessEnforcementAuditItemId.deviceSharing,
          ProAccessEnforcementAuditItemId.serverSideEntitlement,
          ProAccessEnforcementAuditItemId.privacyLockSeparate,
        ],
      );
    });

    test('RevenueCat not configured -> acceptableForTestFlight on entitlement',
        () {
      final result = ProAccessEnforcementAudit.build(
        _input(revenueCatConfigured: false),
      );
      expect(
        _item(result, ProAccessEnforcementAuditItemId.revenueCatEntitlement)
            .classification,
        ProAccessEnforcementClassification.acceptableForTestFlight,
      );
      expect(result.decision, ProAccessEnforcementAuditDecision.testFlightAcceptable);
      expect(result.hasProductionBlocker, isFalse);
    });

    test('RevenueCat configured but entitlement unreadable -> productionBlocker',
        () {
      final result = ProAccessEnforcementAudit.build(
        _input(proEntitlementReadable: false),
      );
      expect(result.decision, ProAccessEnforcementAuditDecision.productionBlocked);
      expect(
        result.earliestBlocker,
        ProAccessEnforcementAuditItemId.revenueCatEntitlement,
      );
      expect(
        _item(result, ProAccessEnforcementAuditItemId.revenueCatEntitlement)
            .classification,
        ProAccessEnforcementClassification.productionBlocker,
      );
    });

    test('restore broken when RevenueCat live -> productionBlocker', () {
      final result = ProAccessEnforcementAudit.build(
        _input(restorePurchasesReachable: false),
      );
      expect(result.decision, ProAccessEnforcementAuditDecision.productionBlocked);
      expect(
        _item(result, ProAccessEnforcementAuditItemId.restoreEntitlement)
            .classification,
        ProAccessEnforcementClassification.productionBlocker,
      );
    });

    test('stale local cache when RevenueCat live -> productionBlocker', () {
      final result = ProAccessEnforcementAudit.build(
        _input(localCachePreventsStalePro: false),
      );
      expect(
        _item(result, ProAccessEnforcementAuditItemId.localCache).classification,
        ProAccessEnforcementClassification.productionBlocker,
      );
    });

    test('local cache enforced when merge policy honored', () {
      final result = ProAccessEnforcementAudit.build(_input());
      expect(
        _item(result, ProAccessEnforcementAuditItemId.localCache).classification,
        ProAccessEnforcementClassification.enforcedLocally,
      );
    });

    test('reinstall relies on restore when persistence missing', () {
      final result = ProAccessEnforcementAudit.build(
        _input(entitlementPersistsAfterRestart: false),
      );
      expect(
        _item(result, ProAccessEnforcementAuditItemId.reinstallBehavior)
            .classification,
        ProAccessEnforcementClassification.enforcedByRevenueCat,
      );
      expect(result.decision, ProAccessEnforcementAuditDecision.testFlightAcceptable);
    });

    test('reinstall blocked when persistence and restore both missing', () {
      final result = ProAccessEnforcementAudit.build(
        _input(
          entitlementPersistsAfterRestart: false,
          restoreNoCrashVerified: false,
        ),
      );
      expect(
        _item(result, ProAccessEnforcementAuditItemId.reinstallBehavior)
            .classification,
        ProAccessEnforcementClassification.productionBlocker,
      );
    });

    test('account identity not linked -> notEnforcedYet', () {
      final result = ProAccessEnforcementAudit.build(_input());
      expect(
        _item(result, ProAccessEnforcementAuditItemId.accountIdentity)
            .classification,
        ProAccessEnforcementClassification.notEnforcedYet,
      );
      expect(result.hasDocumentedGaps, isTrue);
    });

    test('account identity linked -> enforcedByRevenueCat', () {
      final result = ProAccessEnforcementAudit.build(
        _input(revenueCatLinkedToAccount: true),
      );
      expect(
        _item(result, ProAccessEnforcementAuditItemId.accountIdentity)
            .classification,
        ProAccessEnforcementClassification.enforcedByRevenueCat,
      );
    });

    test('device sharing not prevented -> notEnforcedYet', () {
      final result = ProAccessEnforcementAudit.build(_input());
      expect(
        _item(result, ProAccessEnforcementAuditItemId.deviceSharing)
            .classification,
        ProAccessEnforcementClassification.notEnforcedYet,
      );
    });

    test('server-side check present with RevenueCat live -> supplementary locally',
        () {
      final result = ProAccessEnforcementAudit.build(_input());
      expect(
        _item(result, ProAccessEnforcementAuditItemId.serverSideEntitlement)
            .classification,
        ProAccessEnforcementClassification.enforcedLocally,
      );
    });

    test('server-side check absent -> notEnforcedYet', () {
      final result = ProAccessEnforcementAudit.build(
        _input(serverSideEntitlementCheckPresent: false),
      );
      expect(
        _item(result, ProAccessEnforcementAuditItemId.serverSideEntitlement)
            .classification,
        ProAccessEnforcementClassification.notEnforcedYet,
      );
    });

    test('privacy lock separate from Pro -> enforcedLocally', () {
      final result = ProAccessEnforcementAudit.build(_input());
      expect(
        _item(result, ProAccessEnforcementAuditItemId.privacyLockSeparate)
            .classification,
        ProAccessEnforcementClassification.enforcedLocally,
      );
    });

    test('privacy lock coupled to Pro -> productionBlocker', () {
      final result = ProAccessEnforcementAudit.build(
        _input(privacyLockIndependentOfPro: false),
      );
      expect(
        _item(result, ProAccessEnforcementAuditItemId.privacyLockSeparate)
            .classification,
        ProAccessEnforcementClassification.productionBlocker,
      );
    });

    test('all mechanics verified with identity linked -> enforcementDocumented',
        () {
      final result = ProAccessEnforcementAudit.build(
        _input(
          revenueCatLinkedToAccount: true,
          deviceSharingPrevented: true,
        ),
      );
      expect(
        result.decision,
        ProAccessEnforcementAuditDecision.enforcementDocumented,
      );
      expect(result.hasProductionBlocker, isFalse);
    });
  });

  group('ProAccessEnforcementAudit bridges', () {
    test('fromStoreReadinessInput maps store readiness signals', () {
      final storeInput = StoreReadinessSingleSourceInput(
        signingConfigured: true,
        appStoreMetadataReady: true,
        supportUrlSet: true,
        privacyUrlSet: true,
        termsUrlSet: true,
        screenshotsReady: true,
        revenueCatApiKeyProvided: true,
        revenueCatConfigured: true,
        productsLoaded: true,
        proEntitlementConfigured: true,
        purchaseFlowReachable: true,
        restorePurchasesReachable: true,
        restoreNoCrashVerified: true,
        purchasesUnavailableFallbackVerified: true,
        proStateCanBeRead: true,
        entitlementPersistsAfterRestart: true,
        physicalDeviceSmokePassed: true,
        testFlightUploadReady: true,
        paidIntentBetaReady: true,
        secretsRotated: true,
      );
      final auditInput =
          ProAccessEnforcementAudit.fromStoreReadinessInput(storeInput);
      final result = ProAccessEnforcementAudit.build(auditInput);

      expect(auditInput.revenueCatConfigured, isTrue);
      expect(auditInput.proEntitlementReadable, isTrue);
      expect(
        _item(result, ProAccessEnforcementAuditItemId.revenueCatEntitlement)
            .classification,
        ProAccessEnforcementClassification.enforcedByRevenueCat,
      );
    });

    test('report exposes canonical copy', () {
      final report = ProAccessEnforcementAudit.report(
        ProAccessEnforcementAudit.build(_input()),
      );
      expect(report.headline, ProAccessEnforcementAuditCopy.headline);
      expect(report.orderLine, ProAccessEnforcementAuditCopy.orderLine);
      expect(report.guardrail, ProAccessEnforcementAuditCopy.guardrail);
    });
  });

  group('ProAccessEnforcementAuditCopy', () {
    test('headline says Pro access enforcement audit', () {
      expect(
        ProAccessEnforcementAuditCopy.headline,
        'Pro access enforcement audit',
      );
    });

    test('guardrail blocks account system backend sync and TestFlight over-blocking',
        () {
      expect(
        ProAccessEnforcementAuditCopy.guardrail,
        contains('Do not build account system'),
      );
      expect(
        ProAccessEnforcementAuditCopy.guardrail,
        contains('add backend sync'),
      );
      expect(
        ProAccessEnforcementAuditCopy.guardrail,
        contains('purchase, restore, or entitlement is broken'),
      );
    });

    test('copy avoids therapy diagnosis coaching and advice claims', () {
      for (final text in ProAccessEnforcementAuditCopy.allVisibleStrings()) {
        expect(ProofSurfaceAdviceGuard.passes(text), isTrue, reason: text);
        final lower = text.toLowerCase();
        expect(lower.contains('advice'), isFalse, reason: text);
        expect(lower.contains('coaching'), isFalse, reason: text);
        expect(lower.contains('therapy'), isFalse, reason: text);
        expect(lower.contains('diagnosis'), isFalse, reason: text);
      }
    });

    test('docs file exists and references audit dimensions', () {
      final docs = File(_docsPath).readAsStringSync();
      expect(docs.toLowerCase(), contains('revenuecat'));
      expect(docs.toLowerCase(), contains('privacy lock'));
      expect(docs, contains('notEnforcedYet'));
      expect(docs, contains('productionBlocker'));
      expect(docs.toLowerCase(), contains('developer-diagnostics'));
      expect(docs.toLowerCase(), contains('run_pro_access_enforcement_audit.sh'));
      expect(docs.toLowerCase(), contains('validate_core.sh'));
    });
  });

  group('ProAccessEnforcementAuditV3', () {
    StoreReadinessSingleSourceInput _storeInput({
      bool revenueCatConfigured = true,
      bool productsLoaded = true,
      bool purchaseFlowReachable = true,
      bool restorePurchasesReachable = true,
      bool restoreNoCrashVerified = true,
      bool proStateCanBeRead = true,
      bool entitlementPersistsAfterRestart = true,
    }) =>
        StoreReadinessSingleSourceInput(
          signingConfigured: true,
          appStoreMetadataReady: true,
          supportUrlSet: true,
          privacyUrlSet: true,
          termsUrlSet: true,
          screenshotsReady: true,
          revenueCatApiKeyProvided: true,
          revenueCatConfigured: revenueCatConfigured,
          productsLoaded: productsLoaded,
          proEntitlementConfigured: true,
          purchaseFlowReachable: purchaseFlowReachable,
          restorePurchasesReachable: restorePurchasesReachable,
          restoreNoCrashVerified: restoreNoCrashVerified,
          purchasesUnavailableFallbackVerified: true,
          proStateCanBeRead: proStateCanBeRead,
          entitlementPersistsAfterRestart: entitlementPersistsAfterRestart,
          physicalDeviceSmokePassed: true,
          testFlightUploadReady: true,
          paidIntentBetaReady: true,
          secretsRotated: true,
        );

    test('fromStoreReadiness tags four billing store steps', () {
      final bridge = ProAccessEnforcementAuditV3.fromStoreReadiness(
        _storeInput(),
      );

      expect(bridge.tags.length, 4);
      expect(bridge.aligned, isTrue);
    });

    test('misaligned when store billing passes but enforcement blocks', () {
      final bridge = ProAccessEnforcementAuditV3.fromStoreReadiness(
        _storeInput(),
        localCachePreventsStalePro: false,
      );

      expect(bridge.enforcementResult.hasProductionBlocker, isTrue);
      expect(bridge.aligned, isFalse);
    });

    test('fromLocalSignals builds bridge without duplicating store logic', () {
      final bridge = ProAccessEnforcementAuditV3.fromLocalSignals(
        const ProAccessEnforcementLocalSignals(
          revenueCatConfigured: true,
          revenueCatApiKeyMissing: false,
          productsLoaded: true,
          proStateReadable: true,
          proEntitlementActive: true,
          entitlementPersistsAfterRestart: true,
        ),
      );

      expect(bridge.storeResult.submissionReady, isTrue);
      expect(
        bridge.enforcementDecision,
        ProAccessEnforcementAuditDecision.testFlightAcceptable,
      );
    });

    test('ciEnforcementPasses requires green bundle', () {
      expect(
        ProAccessEnforcementAuditV3.ciEnforcementPasses(bundleTestsGreen: true),
        isTrue,
      );
      expect(
        ProAccessEnforcementAuditV3.ciEnforcementPasses(bundleTestsGreen: false),
        isFalse,
      );
      expect(ProAccessEnforcementAuditV3.ciTestBundle, hasLength(3));
    });

    test('v3 copy avoids therapy diagnosis coaching and advice claims', () {
      for (final text in ProAccessEnforcementAuditV3Copy.allVisibleStrings()) {
        expect(ProofSurfaceAdviceGuard.passes(text), isTrue, reason: text);
      }
    });
  });

  group('ProAccessEnforcementAuditV2', () {
    test('buildFromLocalSignals delegates to v1 classifier', () {
      final dashboard = ProAccessEnforcementAuditV2.buildFromLocalSignals(
        const ProAccessEnforcementLocalSignals(
          revenueCatConfigured: true,
          revenueCatApiKeyMissing: false,
          productsLoaded: true,
          proStateReadable: true,
          proEntitlementActive: true,
          backendConfigured: true,
          appLockEnabled: true,
        ),
      );

      expect(dashboard.rows.length, ProAccessEnforcementAudit.auditItemCount);
      expect(
        dashboard.decision,
        ProAccessEnforcementAuditDecision.testFlightAcceptable,
      );
      expect(dashboard.proEntitlementActive, isTrue);
      expect(dashboard.appLockEnabled, isTrue);
    });

    test('stale cached Pro with live RevenueCat free -> productionBlocked', () {
      final dashboard = ProAccessEnforcementAuditV2.buildFromLocalSignals(
        const ProAccessEnforcementLocalSignals(
          revenueCatConfigured: true,
          revenueCatApiKeyMissing: false,
          productsLoaded: true,
          proStateReadable: true,
          proEntitlementActive: false,
          cachedProOnDisk: true,
        ),
      );

      expect(
        dashboard.decision,
        ProAccessEnforcementAuditDecision.productionBlocked,
      );
      expect(dashboard.productionBlockerCount, greaterThan(0));
    });

    test('fromDiagnostics maps RevenueCat diagnostics without SDK import', () {
      final signals = ProAccessEnforcementAuditV2.fromDiagnostics(
        const RevenueCatDiagnostics(
          revenueCatConfigured: false,
          apiKeyMissing: true,
          offeringsLoaded: false,
          offeringCount: 0,
          packageCount: 0,
        ),
      );
      final dashboard = ProAccessEnforcementAuditV2.buildFromLocalSignals(signals);

      expect(dashboard.revenueCatConfigured, isFalse);
      expect(
        dashboard.decision,
        ProAccessEnforcementAuditDecision.testFlightAcceptable,
      );
    });

    test('toAuditInput detects stale cache risk', () {
      final input = ProAccessEnforcementAuditV2.toAuditInput(
        const ProAccessEnforcementLocalSignals(
          revenueCatConfigured: true,
          revenueCatApiKeyMissing: false,
          productsLoaded: true,
          proStateReadable: true,
          proEntitlementActive: false,
          cachedProOnDisk: true,
        ),
      );

      expect(input.localCachePreventsStalePro, isFalse);
    });

    test('v2 copy avoids therapy diagnosis coaching and advice claims', () {
      for (final text in ProAccessEnforcementAuditV2Copy.allVisibleStrings()) {
        expect(ProofSurfaceAdviceGuard.passes(text), isTrue, reason: text);
      }
    });
  });

  group('Protected areas', () {
    test('validate_core.sh enforces pro access audit CI bundle', () {
      final source = File('tool/validate_core.sh').readAsStringSync();
      expect(source, contains('run_pro_access_enforcement_audit.sh'));
    });

    test('v3 module does not import purchases_flutter or billing_service', () {
      for (final path in [
        'lib/features/pro_access_enforcement/pro_access_enforcement_audit_v3.dart',
        'lib/features/pro_access_enforcement/pro_access_enforcement_audit_v3_copy.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source.contains('package:purchases_flutter'), isFalse);
        expect(source.contains('billing_service'), isFalse);
        expect(source.contains('paywall_source'), isFalse);
      }
    });

    test('developer diagnostics wires store readiness bridge to card', () {
      final source =
          File('lib/screens/developer_diagnostics_screen.dart').readAsStringSync();
      expect(source, contains('ProAccessEnforcementAuditV3.fromLocalSignals'));
      expect(source, contains('storeReadinessBridge'));
    });

    test('v2 module does not import purchases_flutter or billing_service', () {
      for (final path in [
        'lib/features/pro_access_enforcement/pro_access_enforcement_audit_v2.dart',
        'lib/features/pro_access_enforcement/pro_access_enforcement_audit_v2_copy.dart',
        'lib/widgets/debug/pro_access_enforcement_audit_card.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source.contains('package:purchases_flutter'), isFalse);
        expect(source.contains('billing_service'), isFalse);
        expect(source.contains('paywall_source'), isFalse);
      }
    });

    test('developer diagnostics screen wires pro access enforcement card', () {
      final source =
          File('lib/screens/developer_diagnostics_screen.dart').readAsStringSync();
      expect(source, contains('ProAccessEnforcementAuditCard'));
      expect(source, contains('ProAccessEnforcementAuditV2.buildFromLocalSignals'));
    });
    test('module does not import purchase paywall or RevenueCat SDK paths', () {
      for (final path in [
        'lib/features/pro_access_enforcement/pro_access_enforcement_audit.dart',
        'lib/features/pro_access_enforcement/pro_access_enforcement_audit_copy.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source.contains('paywall_source'), isFalse);
        expect(source.contains('purchases_flutter'), isFalse);
        expect(source.contains('billing_service'), isFalse);
      }
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

    test('store readiness single source and sandbox proof regressions unchanged',
        () {
      expect(StoreReadinessSingleSourceCopy.headline, isNotEmpty);
      expect(RevenueCatSandboxProofCopy.headline, isNotEmpty);
      expect(ReleaseCandidateFreezeCopy.headline, isNotEmpty);
      expect(PaidIntentBetaProofCopy.headline, isNotEmpty);
    });

    test('proof selection principle still blocks ranking', () {
      expect(ProofSelectionPrinciple.allowsRankingUi(), isFalse);
      expect(
        ProofDetailRepairCopy.whyThisOneLine,
        contains('clearest specific repeat'),
      );
    });

    test('record screen remains capture-first without stacking extra cards', () {
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
  });
}
