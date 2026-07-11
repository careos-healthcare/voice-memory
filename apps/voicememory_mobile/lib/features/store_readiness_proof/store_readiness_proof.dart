import '../production_candidate/production_candidate_checklist.dart';
import '../store_readiness/store_readiness_audit.dart';
import 'store_readiness_proof_copy.dart';

/// Store readiness proof — earliest blocker first, TestFlight before submission.
abstract final class StoreReadinessProof {
  StoreReadinessProof._();

  static StoreReadinessProofResult resolve(StoreReadinessProofInput input) {
    final status = _resolveStatus(input);
    return StoreReadinessProofResult(
      status: status,
      message: _messageFor(status),
    );
  }

  static StoreReadinessProofReport report(StoreReadinessProofResult result) =>
      StoreReadinessProofReport(
        headline: StoreReadinessProofCopy.headline,
        body: StoreReadinessProofCopy.body,
        revenueCatLine: StoreReadinessProofCopy.revenueCatLine,
        restoreLine: StoreReadinessProofCopy.restoreLine,
        entitlementLine: StoreReadinessProofCopy.entitlementLine,
        fallbackLine: StoreReadinessProofCopy.fallbackLine,
        metadataLine: StoreReadinessProofCopy.metadataLine,
        deviceLine: StoreReadinessProofCopy.deviceLine,
        secretsLine: StoreReadinessProofCopy.secretsLine,
        guardrail: StoreReadinessProofCopy.guardrail,
        result: result,
      );

  static StoreReadinessProofInput fromProductionCandidateChecklist(
    ProductionCandidateChecklist checklist, {
    bool revenueCatApiKeyProvided = false,
    bool revenueCatConfigured = false,
    bool productsLoaded = false,
    bool proEntitlementConfigured = false,
    bool purchaseFlowReachable = false,
    bool restorePurchasesReachable = false,
    bool restoreNoCrashVerified = false,
    bool purchasesUnavailableFallbackVerified = false,
    bool proStateCanBeRead = false,
  }) =>
      StoreReadinessProofInput(
        revenueCatApiKeyProvided: revenueCatApiKeyProvided,
        revenueCatConfigured:
            revenueCatConfigured || checklist.revenueCatProductsVerified,
        productsLoaded: productsLoaded || checklist.revenueCatProductsVerified,
        proEntitlementConfigured:
            proEntitlementConfigured || checklist.revenueCatProductsVerified,
        purchaseFlowReachable:
            purchaseFlowReachable || checklist.revenueCatProductsVerified,
        restorePurchasesReachable:
            restorePurchasesReachable || checklist.restorePurchasesVerified,
        restoreNoCrashVerified:
            restoreNoCrashVerified || checklist.restorePurchasesVerified,
        purchasesUnavailableFallbackVerified: purchasesUnavailableFallbackVerified,
        proStateCanBeRead: proStateCanBeRead || checklist.revenueCatProductsVerified,
        supportUrlSet: checklist.appStoreSupportUrlReady,
        privacyUrlSet: checklist.privacyPolicyReady,
        appStoreMetadataReady: checklist.appStoreMetadataReady,
        screenshotsReady: checklist.appStoreScreenshotsReady,
        physicalDeviceSmokePassed: checklist.physicalDeviceSmokeTestPassed,
        testFlightUploadReady: checklist.testFlightBuildUploaded,
        secretsRotated: checklist.productionSecretsRotated,
      );

  static StoreReadinessProofInput fromStoreReadinessAudit(
    StoreReadinessAudit audit, {
    bool revenueCatApiKeyProvided = false,
    bool revenueCatConfigured = false,
    bool productsLoaded = false,
    bool proEntitlementConfigured = false,
    bool purchaseFlowReachable = false,
    bool restorePurchasesReachable = false,
    bool restoreNoCrashVerified = false,
    bool purchasesUnavailableFallbackVerified = false,
    bool proStateCanBeRead = false,
  }) =>
      StoreReadinessProofInput(
        revenueCatApiKeyProvided: revenueCatApiKeyProvided,
        revenueCatConfigured:
            revenueCatConfigured || audit.revenueCatProductsVerified,
        productsLoaded: productsLoaded || audit.revenueCatProductsVerified,
        proEntitlementConfigured:
            proEntitlementConfigured || audit.revenueCatProductsVerified,
        purchaseFlowReachable:
            purchaseFlowReachable || audit.revenueCatProductsVerified,
        restorePurchasesReachable:
            restorePurchasesReachable || audit.restorePurchasesVerified,
        restoreNoCrashVerified:
            restoreNoCrashVerified || audit.restorePurchasesVerified,
        purchasesUnavailableFallbackVerified: purchasesUnavailableFallbackVerified,
        proStateCanBeRead: proStateCanBeRead || audit.revenueCatProductsVerified,
        supportUrlSet: audit.appStoreSupportUrlReady,
        privacyUrlSet: audit.privacyPolicyReady,
        appStoreMetadataReady: audit.appStoreMetadataReady,
        screenshotsReady: audit.appStoreScreenshotsReady,
        physicalDeviceSmokePassed: audit.physicalDeviceSmokeTestPassed,
        testFlightUploadReady: audit.testFlightBuildUploaded,
        secretsRotated: audit.productionSecretsRotated,
      );

  static StoreReadinessProofStatus submissionBlocker(
    StoreReadinessProofInput input,
  ) {
    final status = resolve(input).status;
    if (status == StoreReadinessProofStatus.readyForTestFlight &&
        !input.secretsRotated) {
      return StoreReadinessProofStatus.secretsNotRotated;
    }
    return status;
  }

  static StoreReadinessProofStatus _resolveStatus(
    StoreReadinessProofInput input,
  ) {
    if (!input.revenueCatApiKeyProvided || !input.revenueCatConfigured) {
      return StoreReadinessProofStatus.revenueCatMissing;
    }
    if (!input.productsLoaded) {
      return StoreReadinessProofStatus.productsMissing;
    }
    if (!input.proEntitlementConfigured || !input.proStateCanBeRead) {
      return StoreReadinessProofStatus.entitlementMissing;
    }
    if (!input.purchaseFlowReachable) {
      return StoreReadinessProofStatus.purchasePathMissing;
    }
    if (!input.restorePurchasesReachable || !input.restoreNoCrashVerified) {
      return StoreReadinessProofStatus.restorePathMissing;
    }
    if (!input.purchasesUnavailableFallbackVerified) {
      return StoreReadinessProofStatus.fallbackMissing;
    }
    if (!input.supportUrlSet ||
        !input.privacyUrlSet ||
        !input.appStoreMetadataReady) {
      return StoreReadinessProofStatus.metadataMissing;
    }
    if (!input.screenshotsReady) {
      return StoreReadinessProofStatus.screenshotsMissing;
    }
    if (!input.physicalDeviceSmokePassed) {
      return StoreReadinessProofStatus.deviceSmokeMissing;
    }
    if (!input.testFlightUploadReady) {
      return StoreReadinessProofStatus.testFlightMissing;
    }
    if (!input.secretsRotated) {
      return StoreReadinessProofStatus.readyForTestFlight;
    }
    return StoreReadinessProofStatus.readyForSubmission;
  }

  static String _messageFor(StoreReadinessProofStatus status) =>
      switch (status) {
        StoreReadinessProofStatus.revenueCatMissing =>
          StoreReadinessProofCopy.revenueCatLine,
        StoreReadinessProofStatus.productsMissing =>
          StoreReadinessProofCopy.revenueCatLine,
        StoreReadinessProofStatus.entitlementMissing =>
          StoreReadinessProofCopy.entitlementLine,
        StoreReadinessProofStatus.purchasePathMissing =>
          StoreReadinessProofCopy.revenueCatLine,
        StoreReadinessProofStatus.restorePathMissing =>
          StoreReadinessProofCopy.restoreLine,
        StoreReadinessProofStatus.fallbackMissing =>
          StoreReadinessProofCopy.fallbackLine,
        StoreReadinessProofStatus.metadataMissing =>
          StoreReadinessProofCopy.metadataLine,
        StoreReadinessProofStatus.screenshotsMissing =>
          StoreReadinessProofCopy.metadataLine,
        StoreReadinessProofStatus.deviceSmokeMissing =>
          StoreReadinessProofCopy.deviceLine,
        StoreReadinessProofStatus.testFlightMissing =>
          StoreReadinessProofCopy.deviceLine,
        StoreReadinessProofStatus.secretsNotRotated =>
          StoreReadinessProofCopy.secretsLine,
        StoreReadinessProofStatus.readyForTestFlight =>
          StoreReadinessProofCopy.headline,
        StoreReadinessProofStatus.readyForSubmission =>
          StoreReadinessProofCopy.headline,
      };
}

enum StoreReadinessProofStatus {
  revenueCatMissing,
  productsMissing,
  entitlementMissing,
  purchasePathMissing,
  restorePathMissing,
  fallbackMissing,
  metadataMissing,
  screenshotsMissing,
  deviceSmokeMissing,
  testFlightMissing,
  secretsNotRotated,
  readyForTestFlight,
  readyForSubmission,
}

class StoreReadinessProofInput {
  const StoreReadinessProofInput({
    required this.revenueCatApiKeyProvided,
    required this.revenueCatConfigured,
    required this.productsLoaded,
    required this.proEntitlementConfigured,
    required this.purchaseFlowReachable,
    required this.restorePurchasesReachable,
    required this.restoreNoCrashVerified,
    required this.purchasesUnavailableFallbackVerified,
    required this.proStateCanBeRead,
    required this.supportUrlSet,
    required this.privacyUrlSet,
    required this.appStoreMetadataReady,
    required this.screenshotsReady,
    required this.physicalDeviceSmokePassed,
    required this.testFlightUploadReady,
    required this.secretsRotated,
  });

  final bool revenueCatApiKeyProvided;
  final bool revenueCatConfigured;
  final bool productsLoaded;
  final bool proEntitlementConfigured;
  final bool purchaseFlowReachable;
  final bool restorePurchasesReachable;
  final bool restoreNoCrashVerified;
  final bool purchasesUnavailableFallbackVerified;
  final bool proStateCanBeRead;
  final bool supportUrlSet;
  final bool privacyUrlSet;
  final bool appStoreMetadataReady;
  final bool screenshotsReady;
  final bool physicalDeviceSmokePassed;
  final bool testFlightUploadReady;
  final bool secretsRotated;
}

class StoreReadinessProofResult {
  const StoreReadinessProofResult({
    required this.status,
    required this.message,
  });

  final StoreReadinessProofStatus status;
  final String message;
}

class StoreReadinessProofReport {
  const StoreReadinessProofReport({
    required this.headline,
    required this.body,
    required this.revenueCatLine,
    required this.restoreLine,
    required this.entitlementLine,
    required this.fallbackLine,
    required this.metadataLine,
    required this.deviceLine,
    required this.secretsLine,
    required this.guardrail,
    required this.result,
  });

  final String headline;
  final String body;
  final String revenueCatLine;
  final String restoreLine;
  final String entitlementLine;
  final String fallbackLine;
  final String metadataLine;
  final String deviceLine;
  final String secretsLine;
  final String guardrail;
  final StoreReadinessProofResult result;
}
