import 'release_evidence_pack_copy.dart';

/// Release evidence pack — one proof bundle for TestFlight or submission readiness.
abstract final class ReleaseEvidencePack {
  ReleaseEvidencePack._();

  static const requiredEvidenceItems = [
    ReleaseEvidenceItem.cleanGitStatus,
    ReleaseEvidenceItem.versionBuildCaptured,
    ReleaseEvidenceItem.physicalIphoneSmokeTest,
    ReleaseEvidenceItem.physicalIpadSmokeTest,
    ReleaseEvidenceItem.productionApiSmokeTest,
    ReleaseEvidenceItem.voiceSavePath,
    ReleaseEvidenceItem.typedSavePath,
    ReleaseEvidenceItem.firstProofPath,
    ReleaseEvidenceItem.proPaywallRoute,
    ReleaseEvidenceItem.revenueCatProductLoad,
    ReleaseEvidenceItem.sandboxPurchase,
    ReleaseEvidenceItem.restorePurchases,
    ReleaseEvidenceItem.entitlementPersistence,
    ReleaseEvidenceItem.supportUrl,
    ReleaseEvidenceItem.privacyUrl,
    ReleaseEvidenceItem.termsUrl,
    ReleaseEvidenceItem.screenshots,
    ReleaseEvidenceItem.testFlightUploaded,
  ];

  static ReleaseEvidencePackResult resolve(ReleaseEvidencePackInput input) {
    final missing = missingItems(input);
    if (missing.isNotEmpty) {
      return ReleaseEvidencePackResult(
        status: ReleaseEvidencePackStatus.notReady,
        message: ReleaseEvidencePackCopy.notReadyLine,
        missingItems: missing,
      );
    }
    if (!input.secretsRotated) {
      return ReleaseEvidencePackResult(
        status: ReleaseEvidencePackStatus.readyForTestFlight,
        message: ReleaseEvidencePackCopy.testFlightLine,
        missingItems: const [],
      );
    }
    return ReleaseEvidencePackResult(
      status: ReleaseEvidencePackStatus.readyForSubmission,
      message: ReleaseEvidencePackCopy.submissionLine,
      missingItems: const [],
    );
  }

  static List<ReleaseEvidenceItem> missingItems(ReleaseEvidencePackInput input) {
    final missing = <ReleaseEvidenceItem>[];
    for (final item in requiredEvidenceItems) {
      if (!_present(input, item)) {
        missing.add(item);
      }
    }
    return missing;
  }

  static ReleaseEvidencePackReport report(ReleaseEvidencePackResult result) =>
      ReleaseEvidencePackReport(
        headline: ReleaseEvidencePackCopy.headline,
        body: ReleaseEvidencePackCopy.body,
        notReadyLine: ReleaseEvidencePackCopy.notReadyLine,
        testFlightLine: ReleaseEvidencePackCopy.testFlightLine,
        submissionLine: ReleaseEvidencePackCopy.submissionLine,
        guardrail: ReleaseEvidencePackCopy.guardrail,
        result: result,
      );

  static String labelFor(ReleaseEvidenceItem item) => switch (item) {
        ReleaseEvidenceItem.cleanGitStatus =>
          ReleaseEvidencePackCopy.cleanGitStatusLabel,
        ReleaseEvidenceItem.versionBuildCaptured =>
          ReleaseEvidencePackCopy.versionBuildCapturedLabel,
        ReleaseEvidenceItem.physicalIphoneSmokeTest =>
          ReleaseEvidencePackCopy.physicalIphoneSmokeTestLabel,
        ReleaseEvidenceItem.physicalIpadSmokeTest =>
          ReleaseEvidencePackCopy.physicalIpadSmokeTestLabel,
        ReleaseEvidenceItem.productionApiSmokeTest =>
          ReleaseEvidencePackCopy.productionApiSmokeTestLabel,
        ReleaseEvidenceItem.voiceSavePath =>
          ReleaseEvidencePackCopy.voiceSavePathLabel,
        ReleaseEvidenceItem.typedSavePath =>
          ReleaseEvidencePackCopy.typedSavePathLabel,
        ReleaseEvidenceItem.firstProofPath =>
          ReleaseEvidencePackCopy.firstProofPathLabel,
        ReleaseEvidenceItem.proPaywallRoute =>
          ReleaseEvidencePackCopy.proPaywallRouteLabel,
        ReleaseEvidenceItem.revenueCatProductLoad =>
          ReleaseEvidencePackCopy.revenueCatProductLoadLabel,
        ReleaseEvidenceItem.sandboxPurchase =>
          ReleaseEvidencePackCopy.sandboxPurchaseLabel,
        ReleaseEvidenceItem.restorePurchases =>
          ReleaseEvidencePackCopy.restorePurchasesLabel,
        ReleaseEvidenceItem.entitlementPersistence =>
          ReleaseEvidencePackCopy.entitlementPersistenceLabel,
        ReleaseEvidenceItem.supportUrl => ReleaseEvidencePackCopy.supportUrlLabel,
        ReleaseEvidenceItem.privacyUrl => ReleaseEvidencePackCopy.privacyUrlLabel,
        ReleaseEvidenceItem.termsUrl => ReleaseEvidencePackCopy.termsUrlLabel,
        ReleaseEvidenceItem.screenshots => ReleaseEvidencePackCopy.screenshotsLabel,
        ReleaseEvidenceItem.testFlightUploaded =>
          ReleaseEvidencePackCopy.testFlightUploadedLabel,
        ReleaseEvidenceItem.secretsRotated =>
          ReleaseEvidencePackCopy.secretsRotatedLabel,
      };

  static bool _present(ReleaseEvidencePackInput input, ReleaseEvidenceItem item) =>
      switch (item) {
        ReleaseEvidenceItem.cleanGitStatus => input.cleanGitStatus,
        ReleaseEvidenceItem.versionBuildCaptured => input.versionBuildCaptured,
        ReleaseEvidenceItem.physicalIphoneSmokeTest =>
          input.physicalIphoneSmokeTest,
        ReleaseEvidenceItem.physicalIpadSmokeTest => input.physicalIpadSmokeTest,
        ReleaseEvidenceItem.productionApiSmokeTest =>
          input.productionApiSmokeTest,
        ReleaseEvidenceItem.voiceSavePath => input.voiceSavePath,
        ReleaseEvidenceItem.typedSavePath => input.typedSavePath,
        ReleaseEvidenceItem.firstProofPath => input.firstProofPath,
        ReleaseEvidenceItem.proPaywallRoute => input.proPaywallRoute,
        ReleaseEvidenceItem.revenueCatProductLoad => input.revenueCatProductLoad,
        ReleaseEvidenceItem.sandboxPurchase => input.sandboxPurchase,
        ReleaseEvidenceItem.restorePurchases => input.restorePurchases,
        ReleaseEvidenceItem.entitlementPersistence =>
          input.entitlementPersistence,
        ReleaseEvidenceItem.supportUrl => input.supportUrl,
        ReleaseEvidenceItem.privacyUrl => input.privacyUrl,
        ReleaseEvidenceItem.termsUrl => input.termsUrl,
        ReleaseEvidenceItem.screenshots => input.screenshots,
        ReleaseEvidenceItem.testFlightUploaded => input.testFlightUploaded,
        ReleaseEvidenceItem.secretsRotated => input.secretsRotated,
      };
}

enum ReleaseEvidenceItem {
  cleanGitStatus,
  versionBuildCaptured,
  physicalIphoneSmokeTest,
  physicalIpadSmokeTest,
  productionApiSmokeTest,
  voiceSavePath,
  typedSavePath,
  firstProofPath,
  proPaywallRoute,
  revenueCatProductLoad,
  sandboxPurchase,
  restorePurchases,
  entitlementPersistence,
  supportUrl,
  privacyUrl,
  termsUrl,
  screenshots,
  testFlightUploaded,
  secretsRotated,
}

enum ReleaseEvidencePackStatus {
  notReady,
  readyForTestFlight,
  readyForSubmission,
}

class ReleaseEvidencePackInput {
  const ReleaseEvidencePackInput({
    required this.cleanGitStatus,
    required this.versionBuildCaptured,
    required this.physicalIphoneSmokeTest,
    required this.physicalIpadSmokeTest,
    required this.productionApiSmokeTest,
    required this.voiceSavePath,
    required this.typedSavePath,
    required this.firstProofPath,
    required this.proPaywallRoute,
    required this.revenueCatProductLoad,
    required this.sandboxPurchase,
    required this.restorePurchases,
    required this.entitlementPersistence,
    required this.supportUrl,
    required this.privacyUrl,
    required this.termsUrl,
    required this.screenshots,
    required this.testFlightUploaded,
    required this.secretsRotated,
  });

  final bool cleanGitStatus;
  final bool versionBuildCaptured;
  final bool physicalIphoneSmokeTest;
  final bool physicalIpadSmokeTest;
  final bool productionApiSmokeTest;
  final bool voiceSavePath;
  final bool typedSavePath;
  final bool firstProofPath;
  final bool proPaywallRoute;
  final bool revenueCatProductLoad;
  final bool sandboxPurchase;
  final bool restorePurchases;
  final bool entitlementPersistence;
  final bool supportUrl;
  final bool privacyUrl;
  final bool termsUrl;
  final bool screenshots;
  final bool testFlightUploaded;
  final bool secretsRotated;
}

class ReleaseEvidencePackResult {
  const ReleaseEvidencePackResult({
    required this.status,
    required this.message,
    required this.missingItems,
  });

  final ReleaseEvidencePackStatus status;
  final String message;
  final List<ReleaseEvidenceItem> missingItems;
}

class ReleaseEvidencePackReport {
  const ReleaseEvidencePackReport({
    required this.headline,
    required this.body,
    required this.notReadyLine,
    required this.testFlightLine,
    required this.submissionLine,
    required this.guardrail,
    required this.result,
  });

  final String headline;
  final String body;
  final String notReadyLine;
  final String testFlightLine;
  final String submissionLine;
  final String guardrail;
  final ReleaseEvidencePackResult result;
}
