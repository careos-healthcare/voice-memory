import '../release_candidate_freeze/release_candidate_freeze.dart';
import 'freeze_drift_scanner_copy.dart';

/// Freeze drift scanner — detect risky product drift during release freeze.
abstract final class FreezeDriftScanner {
  FreezeDriftScanner._();

  static const riskyCategories = {
    FreezeDriftCategory.newFeatureSurface,
    FreezeDriftCategory.newDashboard,
    FreezeDriftCategory.newReport,
    FreezeDriftCategory.newRanking,
    FreezeDriftCategory.actionItemExpansion,
    FreezeDriftCategory.contextExpansion,
    FreezeDriftCategory.chatMode,
    FreezeDriftCategory.storagePositioning,
    FreezeDriftCategory.extraProPromise,
    FreezeDriftCategory.proofVolumeExpansion,
    FreezeDriftCategory.recordLayoutChange,
    FreezeDriftCategory.anchorThresholdChange,
  };

  static const allowedCategories = {
    FreezeDriftCategory.crashFix,
    FreezeDriftCategory.storeReadiness,
    FreezeDriftCategory.purchase,
    FreezeDriftCategory.restore,
    FreezeDriftCategory.entitlement,
    FreezeDriftCategory.metadata,
    FreezeDriftCategory.privacySupport,
    FreezeDriftCategory.securitySecrets,
    FreezeDriftCategory.firstJourneyComprehensionBlocker,
    FreezeDriftCategory.criticalProofTrustBug,
  };

  static FreezeDriftScannerResult scan(FreezeDriftScannerInput input) {
    if (!input.freezeActive) {
      return FreezeDriftScannerResult(
        category: input.category,
        decision: FreezeDriftDecision.freezeInactive,
        message: FreezeDriftScannerCopy.freezeInactiveLine,
        freezeAllowed: true,
      );
    }

    final freezeResult = ReleaseCandidateFreeze.build(toFreezeInput(input));
    if (freezeResult.allowed) {
      return FreezeDriftScannerResult(
        category: input.category,
        decision: FreezeDriftDecision.allowed,
        message: FreezeDriftScannerCopy.allowedChangeLine,
        freezeAllowed: true,
        freezeReason: freezeResult.reason,
      );
    }

    return FreezeDriftScannerResult(
      category: input.category,
      decision: FreezeDriftDecision.blocked,
      message: FreezeDriftScannerCopy.blockedLine,
      freezeAllowed: false,
      freezeReason: freezeResult.reason,
      isRiskyDrift: isRiskyCategory(input.category),
    );
  }

  static FreezeDriftScannerResult fromFreezeInput(
    ReleaseCandidateFreezeInput input, {
    required bool freezeActive,
    FreezeDriftCategory? category,
  }) =>
      scan(
        FreezeDriftScannerInput(
          freezeActive: freezeActive,
          category: category ?? categoryForChangeType(input.changeType),
          fixesFirstJourneyComprehension: input.fixesFirstJourneyComprehension,
          fixesCriticalProofTrust: input.fixesCriticalProofTrust,
          addsNewUserFacingSurface: input.addsNewUserFacingSurface,
          blocksRelease: input.blocksRelease,
          blocksPurchase: input.blocksPurchase,
          blocksRestore: input.blocksRestore,
          blocksEntitlement: input.blocksEntitlement,
          causesCrash: input.causesCrash,
          risksAppStoreRejection: input.risksAppStoreRejection,
          affectsSecuritySecrets: input.affectsSecuritySecrets,
          changesPricingOrPaywall: input.changesPricingOrPaywall,
          changesProofThresholds: input.changesProofThresholds,
          changesRecordLayout: input.changesRecordLayout,
        ),
      );

  static ReleaseCandidateFreezeInput toFreezeInput(FreezeDriftScannerInput input) {
    final changeType = _changeTypeForCategory(input.category);
    return ReleaseCandidateFreezeInput(
      changeType: changeType,
      blocksRelease: input.blocksRelease || _storeReadinessCategory(input.category),
      blocksPurchase: input.blocksPurchase || input.category == FreezeDriftCategory.purchase,
      blocksRestore: input.blocksRestore || input.category == FreezeDriftCategory.restore,
      blocksEntitlement:
          input.blocksEntitlement || input.category == FreezeDriftCategory.entitlement,
      causesCrash: input.causesCrash || input.category == FreezeDriftCategory.crashFix,
      risksAppStoreRejection: input.risksAppStoreRejection,
      affectsSecuritySecrets:
          input.affectsSecuritySecrets ||
          input.category == FreezeDriftCategory.securitySecrets,
      fixesFirstJourneyComprehension: input.fixesFirstJourneyComprehension ||
          input.category == FreezeDriftCategory.firstJourneyComprehensionBlocker,
      fixesCriticalProofTrust: input.fixesCriticalProofTrust ||
          input.category == FreezeDriftCategory.criticalProofTrustBug,
      addsNewUserFacingSurface: input.addsNewUserFacingSurface ||
          input.category == FreezeDriftCategory.newFeatureSurface,
      changesPricingOrPaywall: input.changesPricingOrPaywall,
      changesProofThresholds: input.changesProofThresholds ||
          input.category == FreezeDriftCategory.anchorThresholdChange,
      changesRecordLayout: input.changesRecordLayout ||
          input.category == FreezeDriftCategory.recordLayoutChange,
    );
  }

  static bool isRiskyCategory(FreezeDriftCategory category) =>
      riskyCategories.contains(category);

  static bool isAllowedCategory(FreezeDriftCategory category) =>
      allowedCategories.contains(category);

  static FreezeDriftCategory categoryForChangeType(
    ReleaseCandidateChangeType changeType,
  ) =>
      switch (changeType) {
        ReleaseCandidateChangeType.newFeatureSurface ||
        ReleaseCandidateChangeType.newProductFeature =>
          FreezeDriftCategory.newFeatureSurface,
        ReleaseCandidateChangeType.newDashboard => FreezeDriftCategory.newDashboard,
        ReleaseCandidateChangeType.newReport => FreezeDriftCategory.newReport,
        ReleaseCandidateChangeType.newRanking => FreezeDriftCategory.newRanking,
        ReleaseCandidateChangeType.newActionItems =>
          FreezeDriftCategory.actionItemExpansion,
        ReleaseCandidateChangeType.newContextExpansion =>
          FreezeDriftCategory.contextExpansion,
        ReleaseCandidateChangeType.newChatMode => FreezeDriftCategory.chatMode,
        ReleaseCandidateChangeType.newProBenefit =>
          FreezeDriftCategory.extraProPromise,
        ReleaseCandidateChangeType.proofVolumeExpansion =>
          FreezeDriftCategory.proofVolumeExpansion,
        ReleaseCandidateChangeType.recordLayoutChange =>
          FreezeDriftCategory.recordLayoutChange,
        ReleaseCandidateChangeType.anchorThresholdChange =>
          FreezeDriftCategory.anchorThresholdChange,
        ReleaseCandidateChangeType.crash => FreezeDriftCategory.crashFix,
        ReleaseCandidateChangeType.storeReadinessBlocker ||
        ReleaseCandidateChangeType.buildSigningBlocker ||
        ReleaseCandidateChangeType.testFlightBlocker =>
          FreezeDriftCategory.storeReadiness,
        ReleaseCandidateChangeType.purchaseBlocker => FreezeDriftCategory.purchase,
        ReleaseCandidateChangeType.restoreBlocker => FreezeDriftCategory.restore,
        ReleaseCandidateChangeType.entitlementBlocker =>
          FreezeDriftCategory.entitlement,
        ReleaseCandidateChangeType.metadataBlocker => FreezeDriftCategory.metadata,
        ReleaseCandidateChangeType.privacySupportBlocker =>
          FreezeDriftCategory.privacySupport,
        ReleaseCandidateChangeType.securitySecretsBlocker =>
          FreezeDriftCategory.securitySecrets,
        ReleaseCandidateChangeType.firstJourneyComprehensionFailure =>
          FreezeDriftCategory.firstJourneyComprehensionBlocker,
        ReleaseCandidateChangeType.criticalProofTrustBug =>
          FreezeDriftCategory.criticalProofTrustBug,
        _ => FreezeDriftCategory.newFeatureSurface,
      };

  static ReleaseCandidateChangeType _changeTypeForCategory(
    FreezeDriftCategory category,
  ) =>
      switch (category) {
        FreezeDriftCategory.newFeatureSurface =>
          ReleaseCandidateChangeType.newFeatureSurface,
        FreezeDriftCategory.newDashboard => ReleaseCandidateChangeType.newDashboard,
        FreezeDriftCategory.newReport => ReleaseCandidateChangeType.newReport,
        FreezeDriftCategory.newRanking => ReleaseCandidateChangeType.newRanking,
        FreezeDriftCategory.actionItemExpansion =>
          ReleaseCandidateChangeType.newActionItems,
        FreezeDriftCategory.contextExpansion =>
          ReleaseCandidateChangeType.newContextExpansion,
        FreezeDriftCategory.chatMode => ReleaseCandidateChangeType.newChatMode,
        FreezeDriftCategory.storagePositioning =>
          ReleaseCandidateChangeType.newProBenefit,
        FreezeDriftCategory.extraProPromise =>
          ReleaseCandidateChangeType.newProBenefit,
        FreezeDriftCategory.proofVolumeExpansion =>
          ReleaseCandidateChangeType.proofVolumeExpansion,
        FreezeDriftCategory.recordLayoutChange =>
          ReleaseCandidateChangeType.recordLayoutChange,
        FreezeDriftCategory.anchorThresholdChange =>
          ReleaseCandidateChangeType.anchorThresholdChange,
        FreezeDriftCategory.crashFix => ReleaseCandidateChangeType.crash,
        FreezeDriftCategory.storeReadiness =>
          ReleaseCandidateChangeType.storeReadinessBlocker,
        FreezeDriftCategory.purchase => ReleaseCandidateChangeType.purchaseBlocker,
        FreezeDriftCategory.restore => ReleaseCandidateChangeType.restoreBlocker,
        FreezeDriftCategory.entitlement =>
          ReleaseCandidateChangeType.entitlementBlocker,
        FreezeDriftCategory.metadata => ReleaseCandidateChangeType.metadataBlocker,
        FreezeDriftCategory.privacySupport =>
          ReleaseCandidateChangeType.privacySupportBlocker,
        FreezeDriftCategory.securitySecrets =>
          ReleaseCandidateChangeType.securitySecretsBlocker,
        FreezeDriftCategory.firstJourneyComprehensionBlocker =>
          ReleaseCandidateChangeType.firstJourneyComprehensionFailure,
        FreezeDriftCategory.criticalProofTrustBug =>
          ReleaseCandidateChangeType.criticalProofTrustBug,
      };

  static bool _storeReadinessCategory(FreezeDriftCategory category) =>
      category == FreezeDriftCategory.storeReadiness;
}

enum FreezeDriftCategory {
  newFeatureSurface,
  newDashboard,
  newReport,
  newRanking,
  actionItemExpansion,
  contextExpansion,
  chatMode,
  storagePositioning,
  extraProPromise,
  proofVolumeExpansion,
  recordLayoutChange,
  anchorThresholdChange,
  crashFix,
  storeReadiness,
  purchase,
  restore,
  entitlement,
  metadata,
  privacySupport,
  securitySecrets,
  firstJourneyComprehensionBlocker,
  criticalProofTrustBug,
}

enum FreezeDriftDecision {
  freezeInactive,
  allowed,
  blocked,
}

class FreezeDriftScannerInput {
  const FreezeDriftScannerInput({
    required this.freezeActive,
    required this.category,
    this.fixesFirstJourneyComprehension = false,
    this.fixesCriticalProofTrust = false,
    this.addsNewUserFacingSurface = false,
    this.blocksRelease = false,
    this.blocksPurchase = false,
    this.blocksRestore = false,
    this.blocksEntitlement = false,
    this.causesCrash = false,
    this.risksAppStoreRejection = false,
    this.affectsSecuritySecrets = false,
    this.changesPricingOrPaywall = false,
    this.changesProofThresholds = false,
    this.changesRecordLayout = false,
  });

  final bool freezeActive;
  final FreezeDriftCategory category;
  final bool fixesFirstJourneyComprehension;
  final bool fixesCriticalProofTrust;
  final bool addsNewUserFacingSurface;
  final bool blocksRelease;
  final bool blocksPurchase;
  final bool blocksRestore;
  final bool blocksEntitlement;
  final bool causesCrash;
  final bool risksAppStoreRejection;
  final bool affectsSecuritySecrets;
  final bool changesPricingOrPaywall;
  final bool changesProofThresholds;
  final bool changesRecordLayout;
}

class FreezeDriftScannerResult {
  const FreezeDriftScannerResult({
    required this.category,
    required this.decision,
    required this.message,
    required this.freezeAllowed,
    this.freezeReason,
    this.isRiskyDrift = false,
  });

  final FreezeDriftCategory category;
  final FreezeDriftDecision decision;
  final String message;
  final bool freezeAllowed;
  final ReleaseCandidateFreezeReason? freezeReason;
  final bool isRiskyDrift;

  bool get blocksByDefault =>
      decision == FreezeDriftDecision.blocked && isRiskyDrift;
}

class FreezeDriftScannerReport {
  const FreezeDriftScannerReport({
    required this.headline,
    required this.body,
    required this.riskyLine,
    required this.allowedLine,
    required this.blockedLine,
    required this.allowedChangeLine,
    required this.freezeInactiveLine,
    required this.guardrail,
    required this.result,
  });

  final String headline;
  final String body;
  final String riskyLine;
  final String allowedLine;
  final String blockedLine;
  final String allowedChangeLine;
  final String freezeInactiveLine;
  final String guardrail;
  final FreezeDriftScannerResult result;
}
