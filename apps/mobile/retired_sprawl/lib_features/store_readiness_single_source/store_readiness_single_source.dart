import 'package:archiveme_mobile/features/production_candidate/production_candidate_checklist.dart';
import 'package:archiveme_mobile/features/store_readiness/store_readiness_audit.dart';
import 'package:archiveme_mobile/features/store_readiness_proof/store_readiness_proof.dart';
import 'package:archiveme_mobile/features/store_readiness_single_source/store_readiness_single_source_copy.dart';

/// Single store readiness source — unify scattered release checklists.
abstract final class StoreReadinessSingleSource {
  StoreReadinessSingleSource._();

  static const canonicalStepCount = 12;
  static const testFlightStepCount = 10;

  static StoreReadinessSingleSourceResult build(
    StoreReadinessSingleSourceInput input,
  ) {
    final steps = _buildSteps(input);
    final decision = _resolveDecision(steps);
    final proofInput = toProofInput(input);
    final proofResult = StoreReadinessProof.resolve(proofInput);
    final audit = toAudit(input);

    return StoreReadinessSingleSourceResult(
      decision: decision,
      message: _messageFor(decision),
      steps: steps,
      earliestGap: _earliestGap(steps),
      proofResult: proofResult,
      auditStatus: audit.resolveStatus(),
      productionStatus: input.productionChecklist?.resolveStatus(),
      testFlightReady: _testFlightReady(steps),
      submissionReady:
          decision == StoreReadinessSingleSourceDecision.submissionReady,
    );
  }

  static StoreReadinessSingleSourceReport report(
    StoreReadinessSingleSourceResult result,
  ) => StoreReadinessSingleSourceReport(
    headline: StoreReadinessSingleSourceCopy.headline,
    body: StoreReadinessSingleSourceCopy.body,
    orderLine: StoreReadinessSingleSourceCopy.orderLine,
    guardrail: StoreReadinessSingleSourceCopy.guardrail,
    result: result,
  );

  static StoreReadinessSingleSourceInput fromProofInput(
    StoreReadinessProofInput proofInput, {
    bool signingConfigured = false,
    bool termsUrlSet = true,
    bool entitlementPersistsAfterRestart = false,
    bool paidIntentBetaReady = false,
    ProductionCandidateChecklist? productionChecklist,
  }) => StoreReadinessSingleSourceInput(
    signingConfigured: signingConfigured,
    appStoreMetadataReady: proofInput.appStoreMetadataReady,
    supportUrlSet: proofInput.supportUrlSet,
    privacyUrlSet: proofInput.privacyUrlSet,
    termsUrlSet: termsUrlSet,
    screenshotsReady: proofInput.screenshotsReady,
    revenueCatApiKeyProvided: proofInput.revenueCatApiKeyProvided,
    revenueCatConfigured: proofInput.revenueCatConfigured,
    productsLoaded: proofInput.productsLoaded,
    proEntitlementConfigured: proofInput.proEntitlementConfigured,
    purchaseFlowReachable: proofInput.purchaseFlowReachable,
    restorePurchasesReachable: proofInput.restorePurchasesReachable,
    restoreNoCrashVerified: proofInput.restoreNoCrashVerified,
    purchasesUnavailableFallbackVerified:
        proofInput.purchasesUnavailableFallbackVerified,
    proStateCanBeRead: proofInput.proStateCanBeRead,
    entitlementPersistsAfterRestart: entitlementPersistsAfterRestart,
    physicalDeviceSmokePassed: proofInput.physicalDeviceSmokePassed,
    testFlightUploadReady: proofInput.testFlightUploadReady,
    paidIntentBetaReady: paidIntentBetaReady,
    secretsRotated: proofInput.secretsRotated,
    productionChecklist: productionChecklist,
  );

  static StoreReadinessSingleSourceInput fromProductionCandidateChecklist(
    ProductionCandidateChecklist checklist, {
    bool signingConfigured = false,
    bool termsUrlSet = true,
    bool revenueCatApiKeyProvided = true,
    bool revenueCatConfigured = true,
    bool productsLoaded = true,
    bool proEntitlementConfigured = true,
    bool purchaseFlowReachable = true,
    bool restorePurchasesReachable = true,
    bool restoreNoCrashVerified = true,
    bool purchasesUnavailableFallbackVerified = true,
    bool proStateCanBeRead = true,
    bool entitlementPersistsAfterRestart = false,
    bool paidIntentBetaReady = false,
  }) => fromProofInput(
    StoreReadinessProof.fromProductionCandidateChecklist(
      checklist,
      revenueCatApiKeyProvided: revenueCatApiKeyProvided,
      revenueCatConfigured: revenueCatConfigured,
      productsLoaded: productsLoaded,
      proEntitlementConfigured: proEntitlementConfigured,
      purchaseFlowReachable: purchaseFlowReachable,
      restorePurchasesReachable: restorePurchasesReachable,
      restoreNoCrashVerified: restoreNoCrashVerified,
      purchasesUnavailableFallbackVerified:
          purchasesUnavailableFallbackVerified,
      proStateCanBeRead: proStateCanBeRead,
    ),
    signingConfigured: signingConfigured,
    termsUrlSet: termsUrlSet,
    entitlementPersistsAfterRestart: entitlementPersistsAfterRestart,
    paidIntentBetaReady: paidIntentBetaReady,
    productionChecklist: checklist,
  );

  static StoreReadinessSingleSourceInput fromStoreReadinessAudit(
    StoreReadinessAudit audit, {
    bool signingConfigured = false,
    bool termsUrlSet = true,
    bool revenueCatApiKeyProvided = true,
    bool revenueCatConfigured = true,
    bool productsLoaded = true,
    bool proEntitlementConfigured = true,
    bool purchaseFlowReachable = true,
    bool restorePurchasesReachable = true,
    bool restoreNoCrashVerified = true,
    bool purchasesUnavailableFallbackVerified = true,
    bool proStateCanBeRead = true,
    bool entitlementPersistsAfterRestart = false,
    bool paidIntentBetaReady = false,
    ProductionCandidateChecklist? productionChecklist,
  }) => fromProofInput(
    StoreReadinessProof.fromStoreReadinessAudit(
      audit,
      revenueCatApiKeyProvided: revenueCatApiKeyProvided,
      revenueCatConfigured: revenueCatConfigured,
      productsLoaded: productsLoaded,
      proEntitlementConfigured: proEntitlementConfigured,
      purchaseFlowReachable: purchaseFlowReachable,
      restorePurchasesReachable: restorePurchasesReachable,
      restoreNoCrashVerified: restoreNoCrashVerified,
      purchasesUnavailableFallbackVerified:
          purchasesUnavailableFallbackVerified,
      proStateCanBeRead: proStateCanBeRead,
    ),
    signingConfigured: signingConfigured,
    termsUrlSet: termsUrlSet,
    entitlementPersistsAfterRestart: entitlementPersistsAfterRestart,
    paidIntentBetaReady: paidIntentBetaReady,
    productionChecklist: productionChecklist,
  );

  static StoreReadinessProofInput toProofInput(
    StoreReadinessSingleSourceInput input,
  ) => StoreReadinessProofInput(
    revenueCatApiKeyProvided: input.revenueCatApiKeyProvided,
    revenueCatConfigured: input.revenueCatConfigured,
    productsLoaded: input.productsLoaded,
    proEntitlementConfigured: input.proEntitlementConfigured,
    purchaseFlowReachable: input.purchaseFlowReachable,
    restorePurchasesReachable: input.restorePurchasesReachable,
    restoreNoCrashVerified: input.restoreNoCrashVerified,
    purchasesUnavailableFallbackVerified:
        input.purchasesUnavailableFallbackVerified,
    proStateCanBeRead: input.proStateCanBeRead,
    supportUrlSet: input.supportUrlSet,
    privacyUrlSet: input.privacyUrlSet,
    appStoreMetadataReady: input.appStoreMetadataReady,
    screenshotsReady: input.screenshotsReady,
    physicalDeviceSmokePassed: input.physicalDeviceSmokePassed,
    testFlightUploadReady: input.testFlightUploadReady,
    secretsRotated: input.secretsRotated,
  );

  static StoreReadinessAudit toAudit(StoreReadinessSingleSourceInput input) =>
      StoreReadinessAudit(
        testFlightBuildUploaded: input.testFlightUploadReady,
        appStoreSupportUrlReady: input.supportUrlSet,
        privacyPolicyReady: input.privacyUrlSet,
        appStoreScreenshotsReady: input.screenshotsReady,
        appStoreMetadataReady: input.appStoreMetadataReady,
        revenueCatProductsVerified:
            input.revenueCatConfigured && input.productsLoaded,
        restorePurchasesVerified:
            input.restorePurchasesReachable && input.restoreNoCrashVerified,
        physicalDeviceSmokeTestPassed: input.physicalDeviceSmokePassed,
        productionSecretsRotated: input.secretsRotated,
      );

  static List<StoreReadinessSingleSourceStep> _buildSteps(
    StoreReadinessSingleSourceInput input,
  ) {
    StoreReadinessSingleSourceStepStatus statusFor({
      required bool prerequisite,
      required bool value,
    }) {
      if (!prerequisite) return StoreReadinessSingleSourceStepStatus.blocked;
      return value
          ? StoreReadinessSingleSourceStepStatus.pass
          : StoreReadinessSingleSourceStepStatus.fail;
    }

    final signingOk = input.signingConfigured;
    final metadataOk = signingOk && input.appStoreMetadataReady;
    final supportOk =
        metadataOk &&
        input.supportUrlSet &&
        input.privacyUrlSet &&
        input.termsUrlSet;
    final screenshotsOk = supportOk && input.screenshotsReady;
    final revenueCatOk =
        screenshotsOk &&
        input.revenueCatApiKeyProvided &&
        input.revenueCatConfigured &&
        input.productsLoaded;
    final purchaseOk = revenueCatOk && input.purchaseFlowReachable;
    final restoreOk =
        purchaseOk &&
        input.restorePurchasesReachable &&
        input.restoreNoCrashVerified;
    final entitlementOk =
        restoreOk &&
        input.proEntitlementConfigured &&
        input.proStateCanBeRead &&
        input.entitlementPersistsAfterRestart;
    final smokeOk = entitlementOk && input.physicalDeviceSmokePassed;
    final testFlightOk = smokeOk && input.testFlightUploadReady;

    return [
      _step(
        id: StoreReadinessSingleSourceStepId.signing,
        status: statusFor(prerequisite: true, value: input.signingConfigured),
        detailLabel: input.signingConfigured
            ? StoreReadinessSingleSourceCopy.detailPass
            : StoreReadinessSingleSourceCopy.detailFail,
      ),
      _step(
        id: StoreReadinessSingleSourceStepId.metadata,
        status: statusFor(
          prerequisite: signingOk,
          value: input.appStoreMetadataReady,
        ),
        detailLabel: !signingOk
            ? StoreReadinessSingleSourceCopy.detailBlocked
            : input.appStoreMetadataReady
            ? StoreReadinessSingleSourceCopy.detailPass
            : StoreReadinessSingleSourceCopy.detailFail,
      ),
      _step(
        id: StoreReadinessSingleSourceStepId.supportPrivacyTerms,
        status: statusFor(
          prerequisite: metadataOk,
          value:
              input.supportUrlSet && input.privacyUrlSet && input.termsUrlSet,
        ),
        detailLabel: !metadataOk
            ? StoreReadinessSingleSourceCopy.detailBlocked
            : input.supportUrlSet && input.privacyUrlSet && input.termsUrlSet
            ? StoreReadinessSingleSourceCopy.detailPass
            : StoreReadinessSingleSourceCopy.detailFail,
      ),
      _step(
        id: StoreReadinessSingleSourceStepId.screenshots,
        status: statusFor(
          prerequisite: supportOk,
          value: input.screenshotsReady,
        ),
        detailLabel: !supportOk
            ? StoreReadinessSingleSourceCopy.detailBlocked
            : input.screenshotsReady
            ? StoreReadinessSingleSourceCopy.detailPass
            : StoreReadinessSingleSourceCopy.detailFail,
      ),
      _step(
        id: StoreReadinessSingleSourceStepId.revenueCatProducts,
        status: statusFor(
          prerequisite: screenshotsOk,
          value:
              input.revenueCatApiKeyProvided &&
              input.revenueCatConfigured &&
              input.productsLoaded,
        ),
        detailLabel: !screenshotsOk
            ? StoreReadinessSingleSourceCopy.detailBlocked
            : input.revenueCatApiKeyProvided &&
                  input.revenueCatConfigured &&
                  input.productsLoaded
            ? StoreReadinessSingleSourceCopy.detailPass
            : StoreReadinessSingleSourceCopy.detailFail,
      ),
      _step(
        id: StoreReadinessSingleSourceStepId.purchasePath,
        status: statusFor(
          prerequisite: revenueCatOk,
          value: input.purchaseFlowReachable,
        ),
        detailLabel: !revenueCatOk
            ? StoreReadinessSingleSourceCopy.detailBlocked
            : input.purchaseFlowReachable
            ? StoreReadinessSingleSourceCopy.detailPass
            : StoreReadinessSingleSourceCopy.detailFail,
      ),
      _step(
        id: StoreReadinessSingleSourceStepId.restorePath,
        status: statusFor(
          prerequisite: purchaseOk,
          value:
              input.restorePurchasesReachable && input.restoreNoCrashVerified,
        ),
        detailLabel: !purchaseOk
            ? StoreReadinessSingleSourceCopy.detailBlocked
            : input.restorePurchasesReachable && input.restoreNoCrashVerified
            ? StoreReadinessSingleSourceCopy.detailPass
            : StoreReadinessSingleSourceCopy.detailFail,
      ),
      _step(
        id: StoreReadinessSingleSourceStepId.entitlementPersistence,
        status: statusFor(
          prerequisite: restoreOk,
          value:
              input.proEntitlementConfigured &&
              input.proStateCanBeRead &&
              input.entitlementPersistsAfterRestart,
        ),
        detailLabel: !restoreOk
            ? StoreReadinessSingleSourceCopy.detailBlocked
            : input.proEntitlementConfigured &&
                  input.proStateCanBeRead &&
                  input.entitlementPersistsAfterRestart
            ? StoreReadinessSingleSourceCopy.detailPass
            : StoreReadinessSingleSourceCopy.detailFail,
      ),
      _step(
        id: StoreReadinessSingleSourceStepId.physicalDeviceSmoke,
        status: statusFor(
          prerequisite: entitlementOk,
          value: input.physicalDeviceSmokePassed,
        ),
        detailLabel: !entitlementOk
            ? StoreReadinessSingleSourceCopy.detailBlocked
            : input.physicalDeviceSmokePassed
            ? StoreReadinessSingleSourceCopy.detailPass
            : StoreReadinessSingleSourceCopy.detailFail,
      ),
      _step(
        id: StoreReadinessSingleSourceStepId.testFlightUpload,
        status: statusFor(
          prerequisite: smokeOk,
          value: input.testFlightUploadReady,
        ),
        detailLabel: !smokeOk
            ? StoreReadinessSingleSourceCopy.detailBlocked
            : input.testFlightUploadReady
            ? StoreReadinessSingleSourceCopy.detailPass
            : StoreReadinessSingleSourceCopy.detailFail,
      ),
      _step(
        id: StoreReadinessSingleSourceStepId.paidIntentBeta,
        status: statusFor(
          prerequisite: testFlightOk,
          value: input.paidIntentBetaReady,
        ),
        detailLabel: !testFlightOk
            ? StoreReadinessSingleSourceCopy.detailBlocked
            : input.paidIntentBetaReady
            ? StoreReadinessSingleSourceCopy.detailPass
            : StoreReadinessSingleSourceCopy.detailPending,
      ),
      _step(
        id: StoreReadinessSingleSourceStepId.secretsRotation,
        status: statusFor(
          prerequisite: testFlightOk && input.paidIntentBetaReady,
          value: input.secretsRotated,
        ),
        detailLabel: !(testFlightOk && input.paidIntentBetaReady)
            ? StoreReadinessSingleSourceCopy.detailBlocked
            : input.secretsRotated
            ? StoreReadinessSingleSourceCopy.detailPass
            : StoreReadinessSingleSourceCopy.detailFail,
      ),
    ];
  }

  static StoreReadinessSingleSourceStep _step({
    required StoreReadinessSingleSourceStepId id,
    required StoreReadinessSingleSourceStepStatus status,
    required String detailLabel,
  }) => StoreReadinessSingleSourceStep(
    id: id,
    label: StoreReadinessSingleSourceCopy.labelFor(id),
    status: status,
    detailLabel: detailLabel,
  );

  static StoreReadinessSingleSourceDecision _resolveDecision(
    List<StoreReadinessSingleSourceStep> steps,
  ) {
    final testFlightSteps = steps.take(testFlightStepCount);
    if (testFlightSteps.any(
      (step) => step.status == StoreReadinessSingleSourceStepStatus.fail,
    )) {
      return StoreReadinessSingleSourceDecision.notReady;
    }

    final paidIntentStep = steps.firstWhere(
      (step) => step.id == StoreReadinessSingleSourceStepId.paidIntentBeta,
    );
    if (paidIntentStep.status != StoreReadinessSingleSourceStepStatus.pass) {
      return StoreReadinessSingleSourceDecision.paidIntentPending;
    }

    final secretsStep = steps.firstWhere(
      (step) => step.id == StoreReadinessSingleSourceStepId.secretsRotation,
    );
    if (secretsStep.status != StoreReadinessSingleSourceStepStatus.pass) {
      return StoreReadinessSingleSourceDecision.secretsPending;
    }

    return StoreReadinessSingleSourceDecision.submissionReady;
  }

  static bool _testFlightReady(List<StoreReadinessSingleSourceStep> steps) =>
      steps
          .take(testFlightStepCount)
          .every(
            (step) => step.status == StoreReadinessSingleSourceStepStatus.pass,
          );

  static StoreReadinessSingleSourceStepId? _earliestGap(
    List<StoreReadinessSingleSourceStep> steps,
  ) {
    for (final step in steps) {
      if (step.status == StoreReadinessSingleSourceStepStatus.fail ||
          step.status == StoreReadinessSingleSourceStepStatus.pending) {
        return step.id;
      }
    }
    return null;
  }

  static String _messageFor(StoreReadinessSingleSourceDecision decision) =>
      switch (decision) {
        StoreReadinessSingleSourceDecision.notReady =>
          StoreReadinessSingleSourceCopy.notReadyLine,
        StoreReadinessSingleSourceDecision.paidIntentPending =>
          StoreReadinessSingleSourceCopy.paidIntentPendingLine,
        StoreReadinessSingleSourceDecision.secretsPending =>
          StoreReadinessSingleSourceCopy.secretsPendingLine,
        StoreReadinessSingleSourceDecision.submissionReady =>
          StoreReadinessSingleSourceCopy.submissionReadyLine,
      };
}

enum StoreReadinessSingleSourceStepStatus { pass, fail, pending, blocked }

enum StoreReadinessSingleSourceDecision {
  notReady,
  paidIntentPending,
  secretsPending,
  submissionReady,
}

class StoreReadinessSingleSourceInput {
  const StoreReadinessSingleSourceInput({
    required this.signingConfigured,
    required this.appStoreMetadataReady,
    required this.supportUrlSet,
    required this.privacyUrlSet,
    required this.termsUrlSet,
    required this.screenshotsReady,
    required this.revenueCatApiKeyProvided,
    required this.revenueCatConfigured,
    required this.productsLoaded,
    required this.proEntitlementConfigured,
    required this.purchaseFlowReachable,
    required this.restorePurchasesReachable,
    required this.restoreNoCrashVerified,
    required this.purchasesUnavailableFallbackVerified,
    required this.proStateCanBeRead,
    required this.entitlementPersistsAfterRestart,
    required this.physicalDeviceSmokePassed,
    required this.testFlightUploadReady,
    required this.paidIntentBetaReady,
    required this.secretsRotated,
    this.productionChecklist,
  });

  final bool signingConfigured;
  final bool appStoreMetadataReady;
  final bool supportUrlSet;
  final bool privacyUrlSet;
  final bool termsUrlSet;
  final bool screenshotsReady;
  final bool revenueCatApiKeyProvided;
  final bool revenueCatConfigured;
  final bool productsLoaded;
  final bool proEntitlementConfigured;
  final bool purchaseFlowReachable;
  final bool restorePurchasesReachable;
  final bool restoreNoCrashVerified;
  final bool purchasesUnavailableFallbackVerified;
  final bool proStateCanBeRead;
  final bool entitlementPersistsAfterRestart;
  final bool physicalDeviceSmokePassed;
  final bool testFlightUploadReady;
  final bool paidIntentBetaReady;
  final bool secretsRotated;
  final ProductionCandidateChecklist? productionChecklist;
}

class StoreReadinessSingleSourceStep {
  const StoreReadinessSingleSourceStep({
    required this.id,
    required this.label,
    required this.status,
    required this.detailLabel,
  });

  final StoreReadinessSingleSourceStepId id;
  final String label;
  final StoreReadinessSingleSourceStepStatus status;
  final String detailLabel;
}

class StoreReadinessSingleSourceResult {
  const StoreReadinessSingleSourceResult({
    required this.decision,
    required this.message,
    required this.steps,
    required this.earliestGap,
    required this.proofResult,
    required this.auditStatus,
    required this.productionStatus,
    required this.testFlightReady,
    required this.submissionReady,
  });

  final StoreReadinessSingleSourceDecision decision;
  final String message;
  final List<StoreReadinessSingleSourceStep> steps;
  final StoreReadinessSingleSourceStepId? earliestGap;
  final StoreReadinessProofResult proofResult;
  final StoreReadinessStatus auditStatus;
  final ProductionCandidateStatus? productionStatus;
  final bool testFlightReady;
  final bool submissionReady;
}

class StoreReadinessSingleSourceReport {
  const StoreReadinessSingleSourceReport({
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
  final StoreReadinessSingleSourceResult result;
}