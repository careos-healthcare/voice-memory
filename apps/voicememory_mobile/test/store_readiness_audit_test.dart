import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/production_candidate/production_candidate_checklist.dart';
import 'package:voicememory_mobile/features/store_readiness/store_readiness_audit.dart';
import 'package:voicememory_mobile/features/store_readiness/store_readiness_copy.dart';

StoreReadinessAudit _audit({
  bool testFlightBuildUploaded = true,
  bool appStoreSupportUrlReady = true,
  bool privacyPolicyReady = true,
  bool appStoreScreenshotsReady = true,
  bool appStoreMetadataReady = true,
  bool revenueCatProductsVerified = true,
  bool restorePurchasesVerified = true,
  bool physicalDeviceSmokeTestPassed = true,
  bool productionSecretsRotated = true,
}) => StoreReadinessAudit(
  testFlightBuildUploaded: testFlightBuildUploaded,
  appStoreSupportUrlReady: appStoreSupportUrlReady,
  privacyPolicyReady: privacyPolicyReady,
  appStoreScreenshotsReady: appStoreScreenshotsReady,
  appStoreMetadataReady: appStoreMetadataReady,
  revenueCatProductsVerified: revenueCatProductsVerified,
  restorePurchasesVerified: restorePurchasesVerified,
  physicalDeviceSmokeTestPassed: physicalDeviceSmokeTestPassed,
  productionSecretsRotated: productionSecretsRotated,
);

ProductionCandidateChecklist _productionChecklist({
  bool testFlightBuildUploaded = true,
  bool appStoreSupportUrlReady = true,
  bool privacyPolicyReady = true,
  bool appStoreScreenshotsReady = true,
  bool appStoreMetadataReady = true,
  bool revenueCatProductsVerified = true,
  bool restorePurchasesVerified = true,
  bool physicalDeviceSmokeTestPassed = true,
  bool productionSecretsRotated = true,
}) => ProductionCandidateChecklist(
  betaResultsPassed: true,
  proofProtectionBaselineActive: true,
  usefulProofStable: true,
  tooVagueNotRelevantLow: true,
  firstSessionTargetMet: true,
  evidenceTrailClearTargetMet: true,
  proUnderstandingTargetMet: true,
  pricingSignalAcceptable: true,
  restorePurchasesVerified: restorePurchasesVerified,
  revenueCatProductsVerified: revenueCatProductsVerified,
  appStoreSupportUrlReady: appStoreSupportUrlReady,
  privacyPolicyReady: privacyPolicyReady,
  appStoreScreenshotsReady: appStoreScreenshotsReady,
  appStoreMetadataReady: appStoreMetadataReady,
  productionSecretsRotated: productionSecretsRotated,
  physicalDeviceSmokeTestPassed: physicalDeviceSmokeTestPassed,
  testFlightBuildUploaded: testFlightBuildUploaded,
);

void main() {
  group('StoreReadinessAudit.fromProductionCandidateChecklist', () {
    test('maps store readiness fields from production checklist', () {
      final audit = StoreReadinessAudit.fromProductionCandidateChecklist(
        _productionChecklist(
          appStoreMetadataReady: false,
          restorePurchasesVerified: false,
        ),
      );

      expect(audit.appStoreMetadataReady, isFalse);
      expect(audit.restorePurchasesVerified, isFalse);
      expect(audit.testFlightBuildUploaded, isTrue);
    });
  });

  group('StoreReadinessAudit.resolveStatus', () {
    test('store assets missing returns storeAssetsMissing', () {
      for (final audit in [
        _audit(appStoreScreenshotsReady: false),
        _audit(appStoreMetadataReady: false),
        _audit(appStoreSupportUrlReady: false),
        _audit(privacyPolicyReady: false),
      ]) {
        expect(audit.resolveStatus(), StoreReadinessStatus.storeAssetsMissing);
      }
    });

    test(
      'RevenueCat or restore missing returns revenueCatOrRestoreMissing',
      () {
        expect(
          _audit(revenueCatProductsVerified: false).resolveStatus(),
          StoreReadinessStatus.revenueCatOrRestoreMissing,
        );
        expect(
          _audit(restorePurchasesVerified: false).resolveStatus(),
          StoreReadinessStatus.revenueCatOrRestoreMissing,
        );
      },
    );

    test('TestFlight or device smoke missing returns notReady', () {
      expect(
        _audit(testFlightBuildUploaded: false).resolveStatus(),
        StoreReadinessStatus.notReady,
      );
      expect(
        _audit(physicalDeviceSmokeTestPassed: false).resolveStatus(),
        StoreReadinessStatus.notReady,
      );
    });

    test('secrets not rotated returns secretsNotRotated', () {
      expect(
        _audit(productionSecretsRotated: false).resolveStatus(),
        StoreReadinessStatus.secretsNotRotated,
      );
    });

    test('everything true returns readyForSubmission', () {
      expect(_audit().resolveStatus(), StoreReadinessStatus.readyForSubmission);
    });
  });

  group('StoreReadinessAudit priority order', () {
    test('store assets beat RevenueCat and device checks', () {
      expect(
        _audit(
          appStoreScreenshotsReady: false,
          revenueCatProductsVerified: false,
          testFlightBuildUploaded: false,
        ).resolveStatus(),
        StoreReadinessStatus.storeAssetsMissing,
      );
    });

    test('RevenueCat beats device checks', () {
      expect(
        _audit(
          restorePurchasesVerified: false,
          testFlightBuildUploaded: false,
        ).resolveStatus(),
        StoreReadinessStatus.revenueCatOrRestoreMissing,
      );
    });

    test('device checks beat secrets', () {
      expect(
        _audit(
          physicalDeviceSmokeTestPassed: false,
          productionSecretsRotated: false,
        ).resolveStatus(),
        StoreReadinessStatus.notReady,
      );
    });
  });

  group('StoreReadinessCopy.report', () {
    test('includes missing item labels', () {
      final audit = _audit(
        privacyPolicyReady: false,
        restorePurchasesVerified: false,
      );
      final status = audit.resolveStatus();
      final report = StoreReadinessCopy.report(audit, status);

      expect(status, StoreReadinessStatus.storeAssetsMissing);
      expect(report.missingItems, contains('Privacy policy ready'));
      expect(report.missingItems, contains('Restore purchases verified'));
    });

    test('returns correct nextAction for each status', () {
      final cases = <StoreReadinessStatus, String>{
        StoreReadinessStatus.notReady:
            'Upload the latest TestFlight build and complete a physical device smoke test.',
        StoreReadinessStatus.storeAssetsMissing:
            'Finish App Store support URL, privacy policy, screenshots, and metadata.',
        StoreReadinessStatus.revenueCatOrRestoreMissing:
            'Verify RevenueCat products, entitlement access, purchase, and restore purchases.',
        StoreReadinessStatus.secretsNotRotated:
            'Rotate exposed production secrets before launch.',
        StoreReadinessStatus.readyForSubmission:
            'Freeze scope and submit the production candidate.',
      };

      for (final entry in cases.entries) {
        final audit = switch (entry.key) {
          StoreReadinessStatus.notReady => _audit(
            testFlightBuildUploaded: false,
          ),
          StoreReadinessStatus.storeAssetsMissing => _audit(
            appStoreMetadataReady: false,
          ),
          StoreReadinessStatus.revenueCatOrRestoreMissing => _audit(
            restorePurchasesVerified: false,
          ),
          StoreReadinessStatus.secretsNotRotated => _audit(
            productionSecretsRotated: false,
          ),
          StoreReadinessStatus.readyForSubmission => _audit(),
        };
        final report = StoreReadinessCopy.report(audit, entry.key);
        expect(report.nextAction, entry.value);
        expect(report.title, StoreReadinessCopy.titleFor(entry.key));
        expect(report.guardrail, StoreReadinessCopy.guardrail);
      }
    });

    test('passes metadata-safe guard', () {
      for (final text in StoreReadinessCopy.allVisibleStrings()) {
        expect(ProofSurfaceAdviceGuard.passes(text), isTrue, reason: text);
      }
    });
  });

  group('Protected areas', () {
    test('no protected UI or product behavior files touched', () {
      for (final path in [
        'lib/features/store_readiness/store_readiness_audit.dart',
        'lib/features/store_readiness/store_readiness_copy.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source.contains('record_screen'), isFalse);
        expect(source.contains('PaywallSource'), isFalse);
        expect(source.contains('billing/'), isFalse);
        expect(source.contains('BetaRepairLab'), isFalse);
      }
    });
  });
}
