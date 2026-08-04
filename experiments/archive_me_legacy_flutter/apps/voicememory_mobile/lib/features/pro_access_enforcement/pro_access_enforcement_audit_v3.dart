import '../store_readiness_single_source/store_readiness_single_source.dart';
import '../store_readiness_single_source/store_readiness_single_source_copy.dart';
import 'pro_access_enforcement_audit.dart';
import 'pro_access_enforcement_audit_copy.dart';
import 'pro_access_enforcement_audit_v2.dart';
import 'pro_access_enforcement_audit_v3_copy.dart';

/// Pro access enforcement audit v3 — store readiness bridge + CI enforcement.
abstract final class ProAccessEnforcementAuditV3 {
  ProAccessEnforcementAuditV3._();

  static const ciTestBundle = ProAccessEnforcementAuditV2.ciTestBundle;

  static const billingStoreStepIds = {
    StoreReadinessSingleSourceStepId.revenueCatProducts,
    StoreReadinessSingleSourceStepId.purchasePath,
    StoreReadinessSingleSourceStepId.restorePath,
    StoreReadinessSingleSourceStepId.entitlementPersistence,
  };

  static const storeStepToEnforcementItem = {
    StoreReadinessSingleSourceStepId.revenueCatProducts:
        ProAccessEnforcementAuditItemId.revenueCatEntitlement,
    StoreReadinessSingleSourceStepId.purchasePath:
        ProAccessEnforcementAuditItemId.revenueCatEntitlement,
    StoreReadinessSingleSourceStepId.restorePath:
        ProAccessEnforcementAuditItemId.restoreEntitlement,
    StoreReadinessSingleSourceStepId.entitlementPersistence:
        ProAccessEnforcementAuditItemId.reinstallBehavior,
  };

  static ProAccessEnforcementStoreReadinessBridge fromStoreReadiness(
    StoreReadinessSingleSourceInput input, {
    bool revenueCatLinkedToAccount = false,
    bool backendConfigured = true,
    bool privacyLockIndependentOfPro = true,
    bool localCachePreventsStalePro = true,
    StoreReadinessSingleSourceResult? storeResult,
  }) {
    final store = storeResult ?? StoreReadinessSingleSource.build(input);
    final enforcement = ProAccessEnforcementAudit.build(
      ProAccessEnforcementAudit.fromStoreReadinessInput(
        input,
        revenueCatLinkedToAccount: revenueCatLinkedToAccount,
        localCachePreventsStalePro: localCachePreventsStalePro,
        serverSideEntitlementCheckPresent: backendConfigured,
        privacyLockIndependentOfPro: privacyLockIndependentOfPro,
      ),
    );
    final tags = _buildTags(store, enforcement);
    final aligned = _aligned(store, enforcement);

    return ProAccessEnforcementStoreReadinessBridge(
      headline: ProAccessEnforcementAuditV3Copy.headline,
      body: ProAccessEnforcementAuditV3Copy.body,
      guardrail: ProAccessEnforcementAuditV3Copy.guardrail,
      storeDecision: store.decision,
      enforcementDecision: enforcement.decision,
      aligned: aligned,
      alignmentLabel: aligned
          ? ProAccessEnforcementAuditV3Copy.alignedLabel
          : ProAccessEnforcementAuditV3Copy.misalignedLabel,
      tags: tags,
      storeResult: store,
      enforcementResult: enforcement,
    );
  }

  static ProAccessEnforcementStoreReadinessBridge fromLocalSignals(
    ProAccessEnforcementLocalSignals signals,
  ) => fromStoreReadiness(
    storeInputFromLocalSignals(signals),
    revenueCatLinkedToAccount: signals.revenueCatLinkedToAccount,
    backendConfigured: signals.backendConfigured,
    privacyLockIndependentOfPro: signals.privacyLockIndependentOfPro,
  );

  static StoreReadinessSingleSourceInput storeInputFromLocalSignals(
    ProAccessEnforcementLocalSignals signals,
  ) => StoreReadinessSingleSourceInput(
    signingConfigured: true,
    appStoreMetadataReady: true,
    supportUrlSet: true,
    privacyUrlSet: true,
    termsUrlSet: true,
    screenshotsReady: true,
    revenueCatApiKeyProvided: !signals.revenueCatApiKeyMissing,
    revenueCatConfigured: signals.revenueCatConfigured,
    productsLoaded: signals.productsLoaded,
    proEntitlementConfigured: signals.proStateReadable,
    purchaseFlowReachable: signals.revenueCatConfigured,
    restorePurchasesReachable: signals.restorePurchasesReachable,
    restoreNoCrashVerified: signals.restoreNoCrashVerified,
    purchasesUnavailableFallbackVerified: true,
    proStateCanBeRead: signals.proStateReadable,
    entitlementPersistsAfterRestart:
        signals.entitlementPersistsAfterRestart ||
        (signals.cachedProOnDisk && signals.proEntitlementActive),
    physicalDeviceSmokePassed: true,
    testFlightUploadReady: true,
    paidIntentBetaReady: true,
    secretsRotated: true,
  );

  static bool ciEnforcementPasses({required bool bundleTestsGreen}) =>
      bundleTestsGreen;

  static List<ProAccessEnforcementStoreReadinessTag> _buildTags(
    StoreReadinessSingleSourceResult store,
    ProAccessEnforcementAuditResult enforcement,
  ) {
    final enforcementById = {
      for (final item in enforcement.items) item.id: item,
    };

    return [
      for (final stepId in billingStoreStepIds)
        _tagForStep(
          store: store,
          enforcementById: enforcementById,
          stepId: stepId,
        ),
    ];
  }

  static ProAccessEnforcementStoreReadinessTag _tagForStep({
    required StoreReadinessSingleSourceResult store,
    required Map<ProAccessEnforcementAuditItemId, ProAccessEnforcementAuditItem>
    enforcementById,
    required StoreReadinessSingleSourceStepId stepId,
  }) {
    final storeStep = store.steps.firstWhere((step) => step.id == stepId);
    final enforcementItemId = storeStepToEnforcementItem[stepId]!;
    final enforcementItem = enforcementById[enforcementItemId]!;
    final storePass =
        storeStep.status == StoreReadinessSingleSourceStepStatus.pass;
    final enforcementBlocked =
        enforcementItem.classification ==
        ProAccessEnforcementClassification.productionBlocker;

    return ProAccessEnforcementStoreReadinessTag(
      storeStepId: stepId,
      storeStepLabel: storeStep.label,
      storeStepStatus: storeStep.status,
      enforcementItemId: enforcementItemId,
      enforcementItemLabel: enforcementItem.label,
      classification: enforcementItem.classification,
      classificationLabel: enforcementItem.classificationLabel,
      aligned: !(storePass && enforcementBlocked),
    );
  }

  static bool _aligned(
    StoreReadinessSingleSourceResult store,
    ProAccessEnforcementAuditResult enforcement,
  ) {
    if (store.submissionReady && enforcement.hasProductionBlocker) {
      return false;
    }
    if (enforcement.hasProductionBlocker && _billingStoreStepsAllPass(store)) {
      return false;
    }
    return true;
  }

  static bool _billingStoreStepsAllPass(
    StoreReadinessSingleSourceResult store,
  ) => store.steps
      .where((step) => billingStoreStepIds.contains(step.id))
      .every(
        (step) => step.status == StoreReadinessSingleSourceStepStatus.pass,
      );
}

class ProAccessEnforcementStoreReadinessTag {
  const ProAccessEnforcementStoreReadinessTag({
    required this.storeStepId,
    required this.storeStepLabel,
    required this.storeStepStatus,
    required this.enforcementItemId,
    required this.enforcementItemLabel,
    required this.classification,
    required this.classificationLabel,
    required this.aligned,
  });

  final StoreReadinessSingleSourceStepId storeStepId;
  final String storeStepLabel;
  final StoreReadinessSingleSourceStepStatus storeStepStatus;
  final ProAccessEnforcementAuditItemId enforcementItemId;
  final String enforcementItemLabel;
  final ProAccessEnforcementClassification classification;
  final String classificationLabel;
  final bool aligned;
}

class ProAccessEnforcementStoreReadinessBridge {
  const ProAccessEnforcementStoreReadinessBridge({
    required this.headline,
    required this.body,
    required this.guardrail,
    required this.storeDecision,
    required this.enforcementDecision,
    required this.aligned,
    required this.alignmentLabel,
    required this.tags,
    required this.storeResult,
    required this.enforcementResult,
  });

  final String headline;
  final String body;
  final String guardrail;
  final StoreReadinessSingleSourceDecision storeDecision;
  final ProAccessEnforcementAuditDecision enforcementDecision;
  final bool aligned;
  final String alignmentLabel;
  final List<ProAccessEnforcementStoreReadinessTag> tags;
  final StoreReadinessSingleSourceResult storeResult;
  final ProAccessEnforcementAuditResult enforcementResult;

  int get misalignedTagCount => tags.where((tag) => !tag.aligned).length;
}
