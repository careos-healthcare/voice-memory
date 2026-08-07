/// Production candidate readiness checklist — release prep only, no product changes.
class ProductionCandidateChecklist {
  const ProductionCandidateChecklist({
    required this.betaResultsPassed,
    required this.proofProtectionBaselineActive,
    required this.usefulProofStable,
    required this.tooVagueNotRelevantLow,
    required this.firstSessionTargetMet,
    required this.evidenceTrailClearTargetMet,
    required this.proUnderstandingTargetMet,
    required this.pricingSignalAcceptable,
    required this.restorePurchasesVerified,
    required this.revenueCatProductsVerified,
    required this.appStoreSupportUrlReady,
    required this.privacyPolicyReady,
    required this.appStoreScreenshotsReady,
    required this.appStoreMetadataReady,
    required this.productionSecretsRotated,
    required this.physicalDeviceSmokeTestPassed,
    required this.testFlightBuildUploaded,
  });

  final bool betaResultsPassed;
  final bool proofProtectionBaselineActive;
  final bool usefulProofStable;
  final bool tooVagueNotRelevantLow;
  final bool firstSessionTargetMet;
  final bool evidenceTrailClearTargetMet;
  final bool proUnderstandingTargetMet;
  final bool pricingSignalAcceptable;
  final bool restorePurchasesVerified;
  final bool revenueCatProductsVerified;
  final bool appStoreSupportUrlReady;
  final bool privacyPolicyReady;
  final bool appStoreScreenshotsReady;
  final bool appStoreMetadataReady;
  final bool productionSecretsRotated;
  final bool physicalDeviceSmokeTestPassed;
  final bool testFlightBuildUploaded;

  static const betaSignalItems = [
    _ChecklistItem.betaResultsPassed,
    _ChecklistItem.proofProtectionBaselineActive,
    _ChecklistItem.usefulProofStable,
    _ChecklistItem.tooVagueNotRelevantLow,
    _ChecklistItem.firstSessionTargetMet,
    _ChecklistItem.evidenceTrailClearTargetMet,
    _ChecklistItem.proUnderstandingTargetMet,
    _ChecklistItem.pricingSignalAcceptable,
  ];

  static const storeReadinessItems = [
    _ChecklistItem.restorePurchasesVerified,
    _ChecklistItem.revenueCatProductsVerified,
    _ChecklistItem.appStoreSupportUrlReady,
    _ChecklistItem.privacyPolicyReady,
    _ChecklistItem.appStoreScreenshotsReady,
    _ChecklistItem.appStoreMetadataReady,
    _ChecklistItem.physicalDeviceSmokeTestPassed,
    _ChecklistItem.testFlightBuildUploaded,
  ];

  static const secretsItems = [_ChecklistItem.productionSecretsRotated];

  ProductionCandidateStatus resolveStatus() {
    if (!betaResultsPassed) return ProductionCandidateStatus.notReady;
    if (!_betaSignalReady) return ProductionCandidateStatus.notReady;
    if (!_storeReadinessReady) {
      return ProductionCandidateStatus.betaReadyButStoreNotReady;
    }
    if (!productionSecretsRotated) {
      return ProductionCandidateStatus.storeReadyButSecretsNotReady;
    }
    return ProductionCandidateStatus.readyForSubmission;
  }

  Iterable<String> missingItems() sync* {
    for (final item in _ChecklistItem.values) {
      if (!_valueFor(item)) {
        yield item.label;
      }
    }
  }

  bool get _betaSignalReady =>
      proofProtectionBaselineActive &&
      usefulProofStable &&
      tooVagueNotRelevantLow &&
      firstSessionTargetMet &&
      evidenceTrailClearTargetMet &&
      proUnderstandingTargetMet &&
      pricingSignalAcceptable;

  bool get _storeReadinessReady =>
      restorePurchasesVerified &&
      revenueCatProductsVerified &&
      appStoreSupportUrlReady &&
      privacyPolicyReady &&
      appStoreScreenshotsReady &&
      appStoreMetadataReady &&
      physicalDeviceSmokeTestPassed &&
      testFlightBuildUploaded;

  bool _valueFor(_ChecklistItem item) => switch (item) {
    _ChecklistItem.betaResultsPassed => betaResultsPassed,
    _ChecklistItem.proofProtectionBaselineActive =>
      proofProtectionBaselineActive,
    _ChecklistItem.usefulProofStable => usefulProofStable,
    _ChecklistItem.tooVagueNotRelevantLow => tooVagueNotRelevantLow,
    _ChecklistItem.firstSessionTargetMet => firstSessionTargetMet,
    _ChecklistItem.evidenceTrailClearTargetMet => evidenceTrailClearTargetMet,
    _ChecklistItem.proUnderstandingTargetMet => proUnderstandingTargetMet,
    _ChecklistItem.pricingSignalAcceptable => pricingSignalAcceptable,
    _ChecklistItem.restorePurchasesVerified => restorePurchasesVerified,
    _ChecklistItem.revenueCatProductsVerified => revenueCatProductsVerified,
    _ChecklistItem.appStoreSupportUrlReady => appStoreSupportUrlReady,
    _ChecklistItem.privacyPolicyReady => privacyPolicyReady,
    _ChecklistItem.appStoreScreenshotsReady => appStoreScreenshotsReady,
    _ChecklistItem.appStoreMetadataReady => appStoreMetadataReady,
    _ChecklistItem.productionSecretsRotated => productionSecretsRotated,
    _ChecklistItem.physicalDeviceSmokeTestPassed =>
      physicalDeviceSmokeTestPassed,
    _ChecklistItem.testFlightBuildUploaded => testFlightBuildUploaded,
  };
}

enum ProductionCandidateStatus {
  notReady,
  betaReadyButStoreNotReady,
  storeReadyButSecretsNotReady,
  readyForSubmission,
}

enum _ChecklistItem {
  betaResultsPassed('Beta results reader passed'),
  proofProtectionBaselineActive('Proof protection baseline active'),
  usefulProofStable('Useful proof stable'),
  tooVagueNotRelevantLow('Too vague / not relevant feedback low'),
  firstSessionTargetMet('First session target met'),
  evidenceTrailClearTargetMet('Evidence trail clarity target met'),
  proUnderstandingTargetMet('Pro understanding target met'),
  pricingSignalAcceptable('Pricing signal acceptable'),
  restorePurchasesVerified('Restore purchases verified'),
  revenueCatProductsVerified('RevenueCat products verified'),
  appStoreSupportUrlReady('App Store support URL ready'),
  privacyPolicyReady('Privacy policy ready'),
  appStoreScreenshotsReady('App Store screenshots ready'),
  appStoreMetadataReady('App Store metadata ready'),
  productionSecretsRotated('Production secrets rotated'),
  physicalDeviceSmokeTestPassed('Physical device smoke test passed'),
  testFlightBuildUploaded('TestFlight build uploaded');

  const _ChecklistItem(this.label);

  final String label;
}
