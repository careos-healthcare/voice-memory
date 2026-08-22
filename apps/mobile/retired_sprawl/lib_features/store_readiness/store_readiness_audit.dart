import 'package:archiveme_mobile/features/production_candidate/production_candidate_checklist.dart';

/// App Store submission readiness audit — store prep only, no product changes.
class StoreReadinessAudit {
  const StoreReadinessAudit({
    required this.testFlightBuildUploaded,
    required this.appStoreSupportUrlReady,
    required this.privacyPolicyReady,
    required this.appStoreScreenshotsReady,
    required this.appStoreMetadataReady,
    required this.revenueCatProductsVerified,
    required this.restorePurchasesVerified,
    required this.physicalDeviceSmokeTestPassed,
    required this.productionSecretsRotated,
  });

  factory StoreReadinessAudit.fromProductionCandidateChecklist(
    ProductionCandidateChecklist checklist,
  ) => StoreReadinessAudit(
    testFlightBuildUploaded: checklist.testFlightBuildUploaded,
    appStoreSupportUrlReady: checklist.appStoreSupportUrlReady,
    privacyPolicyReady: checklist.privacyPolicyReady,
    appStoreScreenshotsReady: checklist.appStoreScreenshotsReady,
    appStoreMetadataReady: checklist.appStoreMetadataReady,
    revenueCatProductsVerified: checklist.revenueCatProductsVerified,
    restorePurchasesVerified: checklist.restorePurchasesVerified,
    physicalDeviceSmokeTestPassed: checklist.physicalDeviceSmokeTestPassed,
    productionSecretsRotated: checklist.productionSecretsRotated,
  );

  final bool testFlightBuildUploaded;
  final bool appStoreSupportUrlReady;
  final bool privacyPolicyReady;
  final bool appStoreScreenshotsReady;
  final bool appStoreMetadataReady;
  final bool revenueCatProductsVerified;
  final bool restorePurchasesVerified;
  final bool physicalDeviceSmokeTestPassed;
  final bool productionSecretsRotated;

  StoreReadinessStatus resolveStatus() {
    if (!_storeAssetsReady) return StoreReadinessStatus.storeAssetsMissing;
    if (!_revenueCatOrRestoreReady) {
      return StoreReadinessStatus.revenueCatOrRestoreMissing;
    }
    if (!physicalDeviceSmokeTestPassed || !testFlightBuildUploaded) {
      return StoreReadinessStatus.notReady;
    }
    if (!productionSecretsRotated) {
      return StoreReadinessStatus.secretsNotRotated;
    }
    return StoreReadinessStatus.readyForSubmission;
  }

  Iterable<String> missingItems() sync* {
    for (final item in _AuditItem.values) {
      if (!_valueFor(item)) {
        yield item.label;
      }
    }
  }

  bool get _storeAssetsReady =>
      appStoreScreenshotsReady &&
      appStoreMetadataReady &&
      appStoreSupportUrlReady &&
      privacyPolicyReady;

  bool get _revenueCatOrRestoreReady =>
      revenueCatProductsVerified && restorePurchasesVerified;

  bool _valueFor(_AuditItem item) => switch (item) {
    _AuditItem.testFlightBuildUploaded => testFlightBuildUploaded,
    _AuditItem.appStoreSupportUrlReady => appStoreSupportUrlReady,
    _AuditItem.privacyPolicyReady => privacyPolicyReady,
    _AuditItem.appStoreScreenshotsReady => appStoreScreenshotsReady,
    _AuditItem.appStoreMetadataReady => appStoreMetadataReady,
    _AuditItem.revenueCatProductsVerified => revenueCatProductsVerified,
    _AuditItem.restorePurchasesVerified => restorePurchasesVerified,
    _AuditItem.physicalDeviceSmokeTestPassed => physicalDeviceSmokeTestPassed,
    _AuditItem.productionSecretsRotated => productionSecretsRotated,
  };
}

enum StoreReadinessStatus {
  notReady,
  storeAssetsMissing,
  revenueCatOrRestoreMissing,
  secretsNotRotated,
  readyForSubmission,
}

enum _AuditItem {
  testFlightBuildUploaded('TestFlight build uploaded'),
  appStoreSupportUrlReady('App Store support URL ready'),
  privacyPolicyReady('Privacy policy ready'),
  appStoreScreenshotsReady('App Store screenshots ready'),
  appStoreMetadataReady('App Store metadata ready'),
  revenueCatProductsVerified('RevenueCat products verified'),
  restorePurchasesVerified('Restore purchases verified'),
  physicalDeviceSmokeTestPassed('Physical device smoke test passed'),
  productionSecretsRotated('Production secrets rotated');

  const _AuditItem(this.label);

  final String label;
}