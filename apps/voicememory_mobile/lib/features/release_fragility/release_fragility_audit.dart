import '../../billing/archive_loop_entitlement_ids.dart';
import '../physical_device_smoke/physical_device_smoke_proof.dart';
import '../product_language_consistency/product_language_consistency_guard.dart';
import '../secrets_rotation_gate/secrets_rotation_launch_gate.dart';
import '../secrets_rotation_gate/secrets_rotation_launch_gate_copy.dart';
import '../widget_release_risk/widget_release_risk_gate.dart';
import 'release_fragility_copy.dart';

/// Release fragility audit — operational risks that survive green tests.
abstract final class ReleaseFragilityAudit {
  ReleaseFragilityAudit._();

  static const riskCount = 17;
  static const canonicalBundleId = 'com.voicememory.mobile';
  static const canonicalDisplayName = 'ArchiveMe';
  static const canonicalDeploymentTarget = '13.0';
  static const canonicalProductId = 'archive_loop_pro_monthly';

  static final RegExp _legacyBundleIdPattern = RegExp(r'com\.voicememory\.app');

  static const canonicalRiskOrder = [
    ReleaseFragilityRiskId.signing,
    ReleaseFragilityRiskId.bundleId,
    ReleaseFragilityRiskId.displayName,
    ReleaseFragilityRiskId.iosDeploymentTarget,
    ReleaseFragilityRiskId.revenueCatKey,
    ReleaseFragilityRiskId.appStoreProducts,
    ReleaseFragilityRiskId.entitlementId,
    ReleaseFragilityRiskId.restorePath,
    ReleaseFragilityRiskId.supportUrl,
    ReleaseFragilityRiskId.privacyUrl,
    ReleaseFragilityRiskId.termsUrl,
    ReleaseFragilityRiskId.widgetExtension,
    ReleaseFragilityRiskId.productionApi,
    ReleaseFragilityRiskId.secrets,
    ReleaseFragilityRiskId.screenshots,
    ReleaseFragilityRiskId.testFlightUpload,
    ReleaseFragilityRiskId.staleProductCopy,
  ];

  static ReleaseFragilityAuditResult build(ReleaseFragilityAuditInput input) {
    final risks = _buildRisks(input);
    final decision = _resolveDecision(risks);
    return ReleaseFragilityAuditResult(
      decision: decision,
      message: ReleaseFragilityCopy.messageFor(decision),
      recommendation: ReleaseFragilityCopy.recommendationFor(decision),
      risks: risks,
      riskOrder: canonicalRiskOrder,
      earliestBlocker: risks
          .where((risk) => risk.level == ReleaseFragilityRiskLevel.releaseBlocked)
          .map((risk) => risk.id)
          .firstOrNull,
      lowRiskCount:
          risks.where((risk) => risk.level == ReleaseFragilityRiskLevel.lowRisk).length,
      manualCheckCount: risks
          .where((risk) => risk.level == ReleaseFragilityRiskLevel.manualCheckNeeded)
          .length,
      blockedCount: risks
          .where((risk) => risk.level == ReleaseFragilityRiskLevel.releaseBlocked)
          .length,
    );
  }

  static ReleaseFragilityAuditReport report(ReleaseFragilityAuditResult result) =>
      ReleaseFragilityAuditReport(
        headline: ReleaseFragilityCopy.headline,
        body: ReleaseFragilityCopy.body,
        orderLine: ReleaseFragilityCopy.orderLine,
        guardrail: ReleaseFragilityCopy.guardrail,
        result: result,
      );

  static ReleaseFragilityAuditInput fromRepoSignals({
    required String appConfigSource,
    required String pbxprojSource,
    required String infoPlistSource,
    required String appRouterSource,
    required String securitySettingsSource,
    required String revenueCatServiceSource,
    required String revenueCatReleaseChecklistSource,
    required String revenueCatArchiveLoopLogsSource,
    required String revenueCatLiveProofRunnerSource,
    required String archiveLoopEntitlementIdsSource,
    required String proSinglePromiseCopySource,
    required String mobileLibAndDocsScanSource,
    required String revenueCatOfferingsDebugLogSource,
    required String deploySecretsCheckSource,
    required String envExampleSource,
    required String widgetPbxprojSource,
    required String runnerEntitlementsSource,
    required String extensionEntitlementsSource,
    required String objectiveWidgetStorageSwiftSource,
    required String todayCheckWidgetSwiftSource,
    required String widgetExporterDartSource,
    required String widgetPrepDocSource,
    bool? signingVerified,
    bool? screenshotsReady,
    bool? testFlightUploaded,
    bool? stripeSecretKeyRotated,
    bool? stripeWebhookSecretRotated,
    bool? productionEnvUpdated,
    bool? oldWebhookDisabled,
    bool? vercelEnvProductionVerified,
  }) {
    final secretsInput = SecretsRotationLaunchGate.fromRepoSignals(
      mobileLibAndDocsScanSource: mobileLibAndDocsScanSource,
      revenueCatServiceSource: revenueCatServiceSource,
      revenueCatArchiveLoopLogsSource: revenueCatArchiveLoopLogsSource,
      revenueCatOfferingsDebugLogSource: revenueCatOfferingsDebugLogSource,
      revenueCatReleaseChecklistSource: revenueCatReleaseChecklistSource,
      deploySecretsCheckSource: deploySecretsCheckSource,
      envExampleSource: envExampleSource,
      stripeSecretKeyRotated: stripeSecretKeyRotated,
      stripeWebhookSecretRotated: stripeWebhookSecretRotated,
      productionEnvUpdated: productionEnvUpdated,
      oldWebhookDisabled: oldWebhookDisabled,
      vercelEnvProductionVerified: vercelEnvProductionVerified,
    );
    final widgetInput = WidgetReleaseRiskGate.fromRepoSignals(
      pbxprojContents: widgetPbxprojSource,
      runnerEntitlements: runnerEntitlementsSource,
      extensionEntitlements: extensionEntitlementsSource,
      objectiveWidgetStorageSwift: objectiveWidgetStorageSwiftSource,
      todayCheckWidgetSwift: todayCheckWidgetSwiftSource,
      widgetExporterDart: widgetExporterDartSource,
      widgetPrepDoc: widgetPrepDocSource,
      signingPasses: signingVerified ?? true,
    );
    final widgetResult = WidgetReleaseRiskGate.build(widgetInput);

    return ReleaseFragilityAuditInput(
      signingConfigured: signingVerified,
      bundleIdCanonical: detectCanonicalBundleId(
        appConfigSource: appConfigSource,
        pbxprojSource: pbxprojSource,
      ),
      displayNameCanonical:
          PhysicalDeviceSmokeProof.detectAppNameArchiveMe(infoPlistSource),
      iosDeploymentTargetAligned: detectIosDeploymentTargetAligned(
        pbxprojSource: pbxprojSource,
      ),
      revenueCatKeySeparated: SecretsRotationLaunchGate
          .detectRevenueCatApiKeySeparatedFromDocsLogs(
        revenueCatServiceSource: revenueCatServiceSource,
        revenueCatReleaseChecklistSource: revenueCatReleaseChecklistSource,
        revenueCatArchiveLoopLogsSource: revenueCatArchiveLoopLogsSource,
      ),
      appStoreProductsConfigured: detectAppStoreProductsConfigured(
        revenueCatLiveProofRunnerSource,
      ),
      entitlementIdConfigured: detectEntitlementIdConfigured(
        archiveLoopEntitlementIdsSource,
      ),
      restorePathPresent:
          PhysicalDeviceSmokeProof.detectRestorePath(securitySettingsSource),
      supportUrlConfigured: detectSupportUrlConfigured(appConfigSource),
      privacyUrlConfigured: detectPrivacyUrlConfigured(appConfigSource),
      termsRouteConfigured: detectTermsRouteConfigured(
        appConfigSource: appConfigSource,
        appRouterSource: appRouterSource,
      ),
      widgetExtensionSafe: !widgetResult.testFlightBlockedByWidget,
      widgetExtensionNeedsReview: widgetResult.widgetShouldBeDisabled,
      productionApiConfigured: detectProductionApiConfigured(appConfigSource),
      secretsRotationInput: secretsInput,
      screenshotsReady: screenshotsReady,
      testFlightUploaded: testFlightUploaded,
      staleProductCopyRisk: detectStaleProductCopyRisk(proSinglePromiseCopySource),
      signingRepoSignal: detectSigningConfigured(pbxprojSource),
    );
  }

  static bool detectCanonicalBundleId({
    required String appConfigSource,
    required String pbxprojSource,
  }) =>
      appConfigSource.contains("bundleId = '$canonicalBundleId'") &&
      pbxprojSource.contains(
        'PRODUCT_BUNDLE_IDENTIFIER = $canonicalBundleId;',
      ) &&
      !_legacyBundleIdPattern.hasMatch(pbxprojSource);

  static bool detectIosDeploymentTargetAligned({
    required String pbxprojSource,
  }) =>
      pbxprojSource.contains(
        'IPHONEOS_DEPLOYMENT_TARGET = $canonicalDeploymentTarget;',
      );

  static bool detectAppStoreProductsConfigured(
    String revenueCatLiveProofRunnerSource,
  ) =>
      revenueCatLiveProofRunnerSource.contains(canonicalProductId) &&
      revenueCatLiveProofRunnerSource.contains('expectedStoreProductIds');

  static bool detectEntitlementIdConfigured(
    String archiveLoopEntitlementIdsSource,
  ) =>
      archiveLoopEntitlementIdsSource.contains(
        "archiveLoopPro = '${ArchiveLoopEntitlementIds.archiveLoopPro}'",
      ) &&
      archiveLoopEntitlementIdsSource.contains(
        "revenueCatLegacyPro = '${ArchiveLoopEntitlementIds.revenueCatLegacyPro}'",
      );

  static bool detectSupportUrlConfigured(String appConfigSource) =>
      appConfigSource.contains('https://careosapp.co.uk/archiveme-support');

  static bool detectPrivacyUrlConfigured(String appConfigSource) =>
      appConfigSource.contains('https://careosapp.co.uk/archiveme-privacy');

  static bool detectTermsRouteConfigured({
    required String appConfigSource,
    required String appRouterSource,
  }) =>
      appConfigSource.contains("termsRoute = '/terms'") &&
      PhysicalDeviceSmokeProof.detectPrivacyTermsSupportRoutes(appRouterSource);

  static bool detectProductionApiConfigured(String appConfigSource) =>
      appConfigSource.contains('voice-memory-iota.vercel.app') &&
      appConfigSource.contains('careosapp.co.uk') &&
      appConfigSource.contains('marketing-only');

  static bool detectSigningConfigured(String pbxprojSource) =>
      pbxprojSource.contains('CODE_SIGN_STYLE = Automatic') ||
      pbxprojSource.contains('CODE_SIGN_IDENTITY');

  static bool detectStaleProductCopyRisk(String proSinglePromiseCopySource) {
    if (!proSinglePromiseCopySource.contains('longer proof trail')) {
      return true;
    }
    final result = ProductLanguageConsistencyGuard.evaluate(
      proSinglePromiseCopySource,
    );
    return result.action == ProductLanguageConsistencyAction.highRiskBlocked;
  }

  static List<ReleaseFragilityRisk> _buildRisks(ReleaseFragilityAuditInput input) {
    final secretsResult =
        SecretsRotationLaunchGate.build(input.secretsRotationInput);

    return [
      _risk(
        id: ReleaseFragilityRiskId.signing,
        level: _manualWithRepo(
          repoOk: input.signingRepoSignal,
          manual: input.signingConfigured,
        ),
      ),
      _risk(
        id: ReleaseFragilityRiskId.bundleId,
        level: _repoOnly(input.bundleIdCanonical),
      ),
      _risk(
        id: ReleaseFragilityRiskId.displayName,
        level: _repoOnly(input.displayNameCanonical),
      ),
      _risk(
        id: ReleaseFragilityRiskId.iosDeploymentTarget,
        level: _repoOnly(input.iosDeploymentTargetAligned),
      ),
      _risk(
        id: ReleaseFragilityRiskId.revenueCatKey,
        level: _repoOnly(input.revenueCatKeySeparated),
      ),
      _risk(
        id: ReleaseFragilityRiskId.appStoreProducts,
        level: _repoOnly(input.appStoreProductsConfigured),
      ),
      _risk(
        id: ReleaseFragilityRiskId.entitlementId,
        level: _repoOnly(input.entitlementIdConfigured),
      ),
      _risk(
        id: ReleaseFragilityRiskId.restorePath,
        level: _repoOnly(input.restorePathPresent),
      ),
      _risk(
        id: ReleaseFragilityRiskId.supportUrl,
        level: _repoOnly(input.supportUrlConfigured),
      ),
      _risk(
        id: ReleaseFragilityRiskId.privacyUrl,
        level: _repoOnly(input.privacyUrlConfigured),
      ),
      _risk(
        id: ReleaseFragilityRiskId.termsUrl,
        level: _repoOnly(input.termsRouteConfigured),
      ),
      _risk(
        id: ReleaseFragilityRiskId.widgetExtension,
        level: input.widgetExtensionSafe
            ? (input.widgetExtensionNeedsReview
                ? ReleaseFragilityRiskLevel.manualCheckNeeded
                : ReleaseFragilityRiskLevel.lowRisk)
            : ReleaseFragilityRiskLevel.releaseBlocked,
      ),
      _risk(
        id: ReleaseFragilityRiskId.productionApi,
        level: _repoOnly(input.productionApiConfigured),
      ),
      _risk(
        id: ReleaseFragilityRiskId.secrets,
        level: switch (secretsResult.status) {
          SecretsRotationLaunchGateStatus.readyForProductionSubmission =>
            ReleaseFragilityRiskLevel.lowRisk,
          SecretsRotationLaunchGateStatus.safeForInternalTestFlight =>
            ReleaseFragilityRiskLevel.manualCheckNeeded,
          SecretsRotationLaunchGateStatus.blockedForProductionSubmission =>
            ReleaseFragilityRiskLevel.releaseBlocked,
        },
      ),
      _risk(
        id: ReleaseFragilityRiskId.screenshots,
        level: _manualOnly(input.screenshotsReady),
      ),
      _risk(
        id: ReleaseFragilityRiskId.testFlightUpload,
        level: _manualOnly(input.testFlightUploaded),
      ),
      _risk(
        id: ReleaseFragilityRiskId.staleProductCopy,
        level: input.staleProductCopyRisk
            ? ReleaseFragilityRiskLevel.releaseBlocked
            : ReleaseFragilityRiskLevel.lowRisk,
      ),
    ];
  }

  static ReleaseFragilityDecision _resolveDecision(
    List<ReleaseFragilityRisk> risks,
  ) {
    if (risks.any((risk) => risk.level == ReleaseFragilityRiskLevel.releaseBlocked)) {
      return ReleaseFragilityDecision.releaseBlocked;
    }
    if (risks.any(
      (risk) => risk.level == ReleaseFragilityRiskLevel.manualCheckNeeded,
    )) {
      return ReleaseFragilityDecision.manualCheckNeeded;
    }
    return ReleaseFragilityDecision.lowRisk;
  }

  static ReleaseFragilityRiskLevel _repoOnly(bool repoOk) =>
      repoOk
          ? ReleaseFragilityRiskLevel.lowRisk
          : ReleaseFragilityRiskLevel.releaseBlocked;

  static ReleaseFragilityRiskLevel _manualOnly(bool? manual) => switch (manual) {
        true => ReleaseFragilityRiskLevel.lowRisk,
        false => ReleaseFragilityRiskLevel.releaseBlocked,
        null => ReleaseFragilityRiskLevel.manualCheckNeeded,
      };

  static ReleaseFragilityRiskLevel _manualWithRepo({
    required bool repoOk,
    required bool? manual,
  }) {
    if (!repoOk || manual == false) {
      return ReleaseFragilityRiskLevel.releaseBlocked;
    }
    if (manual == null) {
      return ReleaseFragilityRiskLevel.manualCheckNeeded;
    }
    return ReleaseFragilityRiskLevel.lowRisk;
  }

  static ReleaseFragilityRisk _risk({
    required ReleaseFragilityRiskId id,
    required ReleaseFragilityRiskLevel level,
  }) =>
      ReleaseFragilityRisk(
        id: id,
        label: ReleaseFragilityCopy.labelFor(id),
        level: level,
        detailLabel: switch (level) {
          ReleaseFragilityRiskLevel.lowRisk => ReleaseFragilityCopy.detailLowRisk,
          ReleaseFragilityRiskLevel.manualCheckNeeded =>
            ReleaseFragilityCopy.detailManualCheck,
          ReleaseFragilityRiskLevel.releaseBlocked =>
            ReleaseFragilityCopy.detailReleaseBlocked,
        },
      );
}

class ReleaseFragilityAuditInput {
  const ReleaseFragilityAuditInput({
    this.signingConfigured,
    this.bundleIdCanonical = false,
    this.displayNameCanonical = false,
    this.iosDeploymentTargetAligned = false,
    this.revenueCatKeySeparated = false,
    this.appStoreProductsConfigured = false,
    this.entitlementIdConfigured = false,
    this.restorePathPresent = false,
    this.supportUrlConfigured = false,
    this.privacyUrlConfigured = false,
    this.termsRouteConfigured = false,
    this.widgetExtensionSafe = true,
    this.widgetExtensionNeedsReview = false,
    this.productionApiConfigured = false,
    required this.secretsRotationInput,
    this.screenshotsReady,
    this.testFlightUploaded,
    this.staleProductCopyRisk = false,
    this.signingRepoSignal = false,
  });

  final bool? signingConfigured;
  final bool bundleIdCanonical;
  final bool displayNameCanonical;
  final bool iosDeploymentTargetAligned;
  final bool revenueCatKeySeparated;
  final bool appStoreProductsConfigured;
  final bool entitlementIdConfigured;
  final bool restorePathPresent;
  final bool supportUrlConfigured;
  final bool privacyUrlConfigured;
  final bool termsRouteConfigured;
  final bool widgetExtensionSafe;
  final bool widgetExtensionNeedsReview;
  final bool productionApiConfigured;
  final SecretsRotationLaunchGateInput secretsRotationInput;
  final bool? screenshotsReady;
  final bool? testFlightUploaded;
  final bool staleProductCopyRisk;
  final bool signingRepoSignal;
}

class ReleaseFragilityRisk {
  const ReleaseFragilityRisk({
    required this.id,
    required this.label,
    required this.level,
    required this.detailLabel,
  });

  final ReleaseFragilityRiskId id;
  final String label;
  final ReleaseFragilityRiskLevel level;
  final String detailLabel;
}

class ReleaseFragilityAuditResult {
  const ReleaseFragilityAuditResult({
    required this.decision,
    required this.message,
    required this.recommendation,
    required this.risks,
    required this.riskOrder,
    required this.earliestBlocker,
    required this.lowRiskCount,
    required this.manualCheckCount,
    required this.blockedCount,
  });

  final ReleaseFragilityDecision decision;
  final String message;
  final String recommendation;
  final List<ReleaseFragilityRisk> risks;
  final List<ReleaseFragilityRiskId> riskOrder;
  final ReleaseFragilityRiskId? earliestBlocker;
  final int lowRiskCount;
  final int manualCheckCount;
  final int blockedCount;
}

class ReleaseFragilityAuditReport {
  const ReleaseFragilityAuditReport({
    required this.headline,
    required this.body,
    required this.orderLine,
    required this.guardrail,
    required this.result,
  });

  final String headline;
  final String body;
  final String orderLine;
  final String guardrail;
  final ReleaseFragilityAuditResult result;
}
