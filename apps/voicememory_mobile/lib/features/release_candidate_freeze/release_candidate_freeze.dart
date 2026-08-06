import 'release_candidate_freeze_copy.dart';

/// Release candidate freeze — allow blocker fixes only during release prep.
abstract final class ReleaseCandidateFreeze {
  ReleaseCandidateFreeze._();

  static ReleaseCandidateFreezeResult build(ReleaseCandidateFreezeInput input) {
    if (input.affectsSecuritySecrets ||
        input.changeType == ReleaseCandidateChangeType.securitySecretsBlocker) {
      return _allowed(ReleaseCandidateFreezeReason.allowSecuritySecretsFix);
    }
    if (input.causesCrash ||
        input.changeType == ReleaseCandidateChangeType.crash) {
      return _allowed(ReleaseCandidateFreezeReason.allowCrashFix);
    }
    if (input.blocksRelease ||
        _isReleaseInfrastructureChange(input.changeType)) {
      return _allowReleaseInfrastructure(input.changeType);
    }
    if (input.blocksPurchase ||
        input.changeType == ReleaseCandidateChangeType.purchaseBlocker) {
      return _allowed(ReleaseCandidateFreezeReason.allowPurchaseBlocker);
    }
    if (input.blocksRestore ||
        input.changeType == ReleaseCandidateChangeType.restoreBlocker) {
      return _allowed(ReleaseCandidateFreezeReason.allowRestoreBlocker);
    }
    if (input.blocksEntitlement ||
        input.changeType == ReleaseCandidateChangeType.entitlementBlocker) {
      return _allowed(ReleaseCandidateFreezeReason.allowEntitlementBlocker);
    }
    if (input.risksAppStoreRejection ||
        input.changeType == ReleaseCandidateChangeType.appStoreRejectionRisk) {
      return _allowed(ReleaseCandidateFreezeReason.allowAppStoreRiskFix);
    }
    if (input.fixesFirstJourneyComprehension &&
        !input.addsNewUserFacingSurface) {
      return _allowed(ReleaseCandidateFreezeReason.allowFirstJourneyFix);
    }
    if (input.fixesCriticalProofTrust &&
        input.changeType != ReleaseCandidateChangeType.proofVolumeExpansion) {
      return _allowed(ReleaseCandidateFreezeReason.allowCriticalProofTrustFix);
    }

    if (input.changeType == ReleaseCandidateChangeType.newProductFeature) {
      return _blocked(ReleaseCandidateFreezeReason.blockNewProductFeature);
    }
    if (input.changeType == ReleaseCandidateChangeType.newProBenefit) {
      return _blocked(ReleaseCandidateFreezeReason.blockNewProBenefit);
    }
    if (input.changeType == ReleaseCandidateChangeType.newReport) {
      return _blocked(ReleaseCandidateFreezeReason.blockNewReport);
    }
    if (input.changeType == ReleaseCandidateChangeType.newDashboard) {
      return _blocked(ReleaseCandidateFreezeReason.blockNewDashboard);
    }
    if (input.changeType == ReleaseCandidateChangeType.newRanking) {
      return _blocked(ReleaseCandidateFreezeReason.blockNewRanking);
    }
    if (input.changeType == ReleaseCandidateChangeType.newContextExpansion) {
      return _blocked(ReleaseCandidateFreezeReason.blockNewContextExpansion);
    }
    if (input.changeType == ReleaseCandidateChangeType.newActionItems) {
      return _blocked(ReleaseCandidateFreezeReason.blockNewActionItems);
    }
    if (input.changeType == ReleaseCandidateChangeType.newOnboardingFlow &&
        !input.fixesFirstJourneyComprehension) {
      return _blocked(ReleaseCandidateFreezeReason.blockNewOnboardingFlow);
    }
    if (input.changeType == ReleaseCandidateChangeType.newChatMode) {
      return _blocked(ReleaseCandidateFreezeReason.blockNewChatMode);
    }
    if (input.changeType == ReleaseCandidateChangeType.newPricingExperiment) {
      return _blocked(ReleaseCandidateFreezeReason.blockNewPricingExperiment);
    }
    if (input.changeType == ReleaseCandidateChangeType.newFeatureSurface ||
        input.addsNewUserFacingSurface) {
      return _blocked(ReleaseCandidateFreezeReason.blockNewFeatureSurface);
    }
    if (input.changeType == ReleaseCandidateChangeType.proofVolumeExpansion) {
      return _blocked(ReleaseCandidateFreezeReason.blockProofVolumeExpansion);
    }
    if ((input.changeType == ReleaseCandidateChangeType.anchorThresholdChange ||
            input.changesProofThresholds) &&
        !input.fixesCriticalProofTrust) {
      return _blocked(ReleaseCandidateFreezeReason.blockAnchorThresholdChange);
    }
    if ((input.changeType == ReleaseCandidateChangeType.recordLayoutChange ||
            input.changesRecordLayout) &&
        !input.fixesFirstJourneyComprehension) {
      return _blocked(ReleaseCandidateFreezeReason.blockRecordLayoutChange);
    }
    if ((input.changeType ==
                ReleaseCandidateChangeType.paywallMechanicsChange ||
            input.changesPricingOrPaywall) &&
        !_isPurchasePathBlocker(input)) {
      return _blocked(ReleaseCandidateFreezeReason.blockPaywallMechanicsChange);
    }
    if (input.changeType == ReleaseCandidateChangeType.revenueCatChange &&
        !_isStoreOrPurchasePathBlocker(input)) {
      return _blocked(ReleaseCandidateFreezeReason.blockRevenueCatChange);
    }
    if (input.changeType == ReleaseCandidateChangeType.backendSyncChange &&
        !input.blocksRelease) {
      return _blocked(ReleaseCandidateFreezeReason.blockBackendSyncChange);
    }

    return _blocked(ReleaseCandidateFreezeReason.blockReleaseFreezeDefault);
  }

  static ReleaseCandidateFreezeReport report(
    ReleaseCandidateFreezeResult result,
  ) => ReleaseCandidateFreezeReport(
    headline: ReleaseCandidateFreezeCopy.headline,
    body: ReleaseCandidateFreezeCopy.body,
    allowedLine: ReleaseCandidateFreezeCopy.allowedLine,
    blockedLine: ReleaseCandidateFreezeCopy.blockedLine,
    firstJourneyLine: ReleaseCandidateFreezeCopy.firstJourneyLine,
    proLine: ReleaseCandidateFreezeCopy.proLine,
    guardrail: ReleaseCandidateFreezeCopy.guardrail,
    result: result,
  );

  static bool _isReleaseInfrastructureChange(
    ReleaseCandidateChangeType changeType,
  ) =>
      changeType == ReleaseCandidateChangeType.storeReadinessBlocker ||
      changeType == ReleaseCandidateChangeType.buildSigningBlocker ||
      changeType == ReleaseCandidateChangeType.testFlightBlocker ||
      changeType == ReleaseCandidateChangeType.metadataBlocker ||
      changeType == ReleaseCandidateChangeType.privacySupportBlocker;

  static ReleaseCandidateFreezeResult _allowReleaseInfrastructure(
    ReleaseCandidateChangeType changeType,
  ) => switch (changeType) {
    ReleaseCandidateChangeType.buildSigningBlocker => _allowed(
      ReleaseCandidateFreezeReason.allowBuildSigningFix,
    ),
    ReleaseCandidateChangeType.testFlightBlocker => _allowed(
      ReleaseCandidateFreezeReason.allowTestFlightFix,
    ),
    ReleaseCandidateChangeType.metadataBlocker ||
    ReleaseCandidateChangeType.privacySupportBlocker => _allowed(
      ReleaseCandidateFreezeReason.allowMetadataPrivacySupportFix,
    ),
    _ => _allowed(ReleaseCandidateFreezeReason.allowStoreReadinessBlocker),
  };

  static bool _isPurchasePathBlocker(ReleaseCandidateFreezeInput input) =>
      input.blocksPurchase ||
      input.blocksRestore ||
      input.blocksEntitlement ||
      input.changeType == ReleaseCandidateChangeType.purchaseBlocker ||
      input.changeType == ReleaseCandidateChangeType.restoreBlocker ||
      input.changeType == ReleaseCandidateChangeType.entitlementBlocker;

  static bool _isStoreOrPurchasePathBlocker(
    ReleaseCandidateFreezeInput input,
  ) =>
      input.blocksRelease ||
      _isPurchasePathBlocker(input) ||
      input.changeType == ReleaseCandidateChangeType.storeReadinessBlocker;

  static ReleaseCandidateFreezeResult _allowed(
    ReleaseCandidateFreezeReason reason,
  ) => ReleaseCandidateFreezeResult(allowed: true, reason: reason);

  static ReleaseCandidateFreezeResult _blocked(
    ReleaseCandidateFreezeReason reason,
  ) => ReleaseCandidateFreezeResult(allowed: false, reason: reason);
}

enum ReleaseCandidateChangeType {
  storeReadinessBlocker,
  purchaseBlocker,
  restoreBlocker,
  entitlementBlocker,
  crash,
  buildSigningBlocker,
  testFlightBlocker,
  metadataBlocker,
  privacySupportBlocker,
  appStoreRejectionRisk,
  firstJourneyComprehensionFailure,
  criticalProofTrustBug,
  securitySecretsBlocker,
  newProductFeature,
  newProBenefit,
  newReport,
  newDashboard,
  newRanking,
  newContextExpansion,
  newActionItems,
  newOnboardingFlow,
  newChatMode,
  newPricingExperiment,
  newFeatureSurface,
  proofVolumeExpansion,
  anchorThresholdChange,
  recordLayoutChange,
  paywallMechanicsChange,
  revenueCatChange,
  backendSyncChange,
}

enum ReleaseCandidateFreezeReason {
  allowStoreReadinessBlocker,
  allowPurchaseBlocker,
  allowRestoreBlocker,
  allowEntitlementBlocker,
  allowCrashFix,
  allowBuildSigningFix,
  allowTestFlightFix,
  allowMetadataPrivacySupportFix,
  allowAppStoreRiskFix,
  allowFirstJourneyFix,
  allowCriticalProofTrustFix,
  allowSecuritySecretsFix,
  blockNewProductFeature,
  blockNewProBenefit,
  blockNewReport,
  blockNewDashboard,
  blockNewRanking,
  blockNewContextExpansion,
  blockNewActionItems,
  blockNewOnboardingFlow,
  blockNewChatMode,
  blockNewPricingExperiment,
  blockNewFeatureSurface,
  blockProofVolumeExpansion,
  blockAnchorThresholdChange,
  blockRecordLayoutChange,
  blockPaywallMechanicsChange,
  blockRevenueCatChange,
  blockBackendSyncChange,
  blockReleaseFreezeDefault,
}

class ReleaseCandidateFreezeInput {
  const ReleaseCandidateFreezeInput({
    required this.changeType,
    required this.blocksRelease,
    required this.blocksPurchase,
    required this.blocksRestore,
    required this.blocksEntitlement,
    required this.causesCrash,
    required this.risksAppStoreRejection,
    required this.affectsSecuritySecrets,
    required this.fixesFirstJourneyComprehension,
    required this.fixesCriticalProofTrust,
    required this.addsNewUserFacingSurface,
    required this.changesPricingOrPaywall,
    required this.changesProofThresholds,
    required this.changesRecordLayout,
  });

  final ReleaseCandidateChangeType changeType;
  final bool blocksRelease;
  final bool blocksPurchase;
  final bool blocksRestore;
  final bool blocksEntitlement;
  final bool causesCrash;
  final bool risksAppStoreRejection;
  final bool affectsSecuritySecrets;
  final bool fixesFirstJourneyComprehension;
  final bool fixesCriticalProofTrust;
  final bool addsNewUserFacingSurface;
  final bool changesPricingOrPaywall;
  final bool changesProofThresholds;
  final bool changesRecordLayout;
}

class ReleaseCandidateFreezeResult {
  const ReleaseCandidateFreezeResult({
    required this.allowed,
    required this.reason,
  });

  final bool allowed;
  final ReleaseCandidateFreezeReason reason;
}

class ReleaseCandidateFreezeReport {
  const ReleaseCandidateFreezeReport({
    required this.headline,
    required this.body,
    required this.allowedLine,
    required this.blockedLine,
    required this.firstJourneyLine,
    required this.proLine,
    required this.guardrail,
    required this.result,
  });

  final String headline;
  final String body;
  final String allowedLine;
  final String blockedLine;
  final String firstJourneyLine;
  final String proLine;
  final String guardrail;
  final ReleaseCandidateFreezeResult result;
}
