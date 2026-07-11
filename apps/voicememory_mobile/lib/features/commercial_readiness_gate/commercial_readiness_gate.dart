import '../paid_intent_beta_proof/paid_intent_beta_proof.dart';
import '../store_readiness_single_source/store_readiness_single_source.dart';
import 'commercial_readiness_gate_copy.dart';

/// Commercial readiness gate — product-ready vs commercially ready.
abstract final class CommercialReadinessGate {
  CommercialReadinessGate._();

  static const checkCount = 12;

  static CommercialReadinessGateResult build(
    CommercialReadinessGateInput input,
  ) {
    final checks = _buildChecks(input);
    final status = _resolveStatus(input, checks);
    return CommercialReadinessGateResult(
      status: status,
      message: CommercialReadinessGateCopy.messageFor(status),
      recommendation: CommercialReadinessGateCopy.recommendationFor(status),
      checks: checks,
      earliestBlocker: _earliestBlocker(checks),
      commerciallyReady: status == CommercialReadinessGateStatus.commerciallyReady,
      productReadyOnly: status == CommercialReadinessGateStatus.productReadyOnly,
    );
  }

  static CommercialReadinessGateReport report(CommercialReadinessGateResult result) =>
      CommercialReadinessGateReport(
        headline: CommercialReadinessGateCopy.headline,
        body: CommercialReadinessGateCopy.body,
        orderLine: CommercialReadinessGateCopy.orderLine,
        guardrail: CommercialReadinessGateCopy.guardrail,
        result: result,
      );

  static bool detectProductPromiseCopyPresent(String proEvidenceValueCopySource) =>
      proEvidenceValueCopySource.contains('productPromise') &&
      proEvidenceValueCopySource.contains('not a chat');

  static bool detectFirstJourneyCopyPresent(String featureNoiseReductionCopySource) =>
      featureNoiseReductionCopySource.contains('Keep the first journey clear');

  static bool detectFirstProofThresholdGuarded(String archiveEvidenceGateSource) =>
      archiveEvidenceGateSource.contains('static const minProofEntryCount = 3;');

  static bool detectProPromiseCopyPresent(String proSinglePromiseCopySource) =>
      proSinglePromiseCopySource.contains('Keep the longer proof trail');

  static bool detectPaywallPriceKeyPresent(String paywallScreenSource) =>
      paywallScreenSource.contains("Key('paywall_price_confidence')");

  static CommercialReadinessGateInput fromStoreReadinessInput(
    StoreReadinessSingleSourceInput input, {
    bool productPromiseClear = true,
    bool firstJourneyStable = true,
    bool firstProofUsefulEnough = true,
    bool proPromiseClear = true,
    bool paywallPriceVisible = false,
    bool sandboxPurchaseWorks = false,
  }) =>
      CommercialReadinessGateInput(
        productPromiseClear: productPromiseClear,
        firstJourneyStable: firstJourneyStable,
        firstProofUsefulEnough: firstProofUsefulEnough,
        proPromiseClear: proPromiseClear,
        revenueCatProductLoads: input.revenueCatApiKeyProvided &&
            input.revenueCatConfigured &&
            input.productsLoaded,
        paywallPriceVisible: paywallPriceVisible,
        sandboxPurchaseWorks: sandboxPurchaseWorks && input.purchaseFlowReachable,
        restoreWorks: input.restorePurchasesReachable &&
            input.restoreNoCrashVerified,
        entitlementPersists: input.proEntitlementConfigured &&
            input.proStateCanBeRead &&
            input.entitlementPersistsAfterRestart,
        testFlightBuildUploaded: input.testFlightUploadReady,
        paidIntentBetaComplete: input.paidIntentBetaReady,
        secretsRotationDone: input.secretsRotated,
      );

  static CommercialReadinessGateInput fromRepoSignals({
    required String proEvidenceValueCopySource,
    required String featureNoiseReductionCopySource,
    required String archiveEvidenceGateSource,
    required String proSinglePromiseCopySource,
    required String paywallScreenSource,
    bool revenueCatProductLoads = false,
    bool paywallPriceVisible = false,
    bool sandboxPurchaseWorks = false,
    bool restoreWorks = false,
    bool entitlementPersists = false,
    bool testFlightBuildUploaded = false,
    bool paidIntentBetaComplete = false,
    bool secretsRotationDone = false,
  }) =>
      CommercialReadinessGateInput(
        productPromiseClear:
            detectProductPromiseCopyPresent(proEvidenceValueCopySource),
        firstJourneyStable:
            detectFirstJourneyCopyPresent(featureNoiseReductionCopySource),
        firstProofUsefulEnough:
            detectFirstProofThresholdGuarded(archiveEvidenceGateSource),
        proPromiseClear: detectProPromiseCopyPresent(proSinglePromiseCopySource),
        revenueCatProductLoads: revenueCatProductLoads,
        paywallPriceVisible:
            paywallPriceVisible ||
                detectPaywallPriceKeyPresent(paywallScreenSource),
        sandboxPurchaseWorks: sandboxPurchaseWorks,
        restoreWorks: restoreWorks,
        entitlementPersists: entitlementPersists,
        testFlightBuildUploaded: testFlightBuildUploaded,
        paidIntentBetaComplete: paidIntentBetaComplete,
        secretsRotationDone: secretsRotationDone,
      );

  static bool paidIntentBetaCompleteFromDecision(
    PaidIntentBetaProofDecision decision,
  ) =>
      decision == PaidIntentBetaProofDecision.paidIntentPromising;

  static List<CommercialReadinessGateCheck> _buildChecks(
    CommercialReadinessGateInput input,
  ) {
    CommercialReadinessGateCheckStatus statusFor({
      required bool prerequisite,
      required bool value,
    }) {
      if (!prerequisite) return CommercialReadinessGateCheckStatus.blocked;
      return value
          ? CommercialReadinessGateCheckStatus.pass
          : CommercialReadinessGateCheckStatus.fail;
    }

    final productOk = input.productPromiseClear &&
        input.firstJourneyStable &&
        input.firstProofUsefulEnough &&
        input.proPromiseClear;
    final storeOk = productOk &&
        input.revenueCatProductLoads &&
        input.testFlightBuildUploaded;
    final purchaseOk = storeOk &&
        input.paywallPriceVisible &&
        input.sandboxPurchaseWorks;
    final restoreOk = purchaseOk && input.restoreWorks;
    final entitlementOk = restoreOk && input.entitlementPersists;
    final betaOk = entitlementOk && input.paidIntentBetaComplete;

    return [
      _check(
        id: CommercialReadinessGateCheckId.productPromiseClear,
        status: statusFor(prerequisite: true, value: input.productPromiseClear),
        detailLabel: input.productPromiseClear
            ? CommercialReadinessGateCopy.detailPass
            : CommercialReadinessGateCopy.detailFail,
      ),
      _check(
        id: CommercialReadinessGateCheckId.firstJourneyStable,
        status: statusFor(prerequisite: true, value: input.firstJourneyStable),
        detailLabel: input.firstJourneyStable
            ? CommercialReadinessGateCopy.detailPass
            : CommercialReadinessGateCopy.detailFail,
      ),
      _check(
        id: CommercialReadinessGateCheckId.firstProofUsefulEnough,
        status: statusFor(
          prerequisite: true,
          value: input.firstProofUsefulEnough,
        ),
        detailLabel: input.firstProofUsefulEnough
            ? CommercialReadinessGateCopy.detailPass
            : CommercialReadinessGateCopy.detailFail,
      ),
      _check(
        id: CommercialReadinessGateCheckId.proPromiseClear,
        status: statusFor(prerequisite: true, value: input.proPromiseClear),
        detailLabel: input.proPromiseClear
            ? CommercialReadinessGateCopy.detailPass
            : CommercialReadinessGateCopy.detailFail,
      ),
      _check(
        id: CommercialReadinessGateCheckId.revenueCatProductLoads,
        status: statusFor(
          prerequisite: productOk,
          value: input.revenueCatProductLoads,
        ),
        detailLabel: !productOk
            ? CommercialReadinessGateCopy.detailBlocked
            : input.revenueCatProductLoads
                ? CommercialReadinessGateCopy.detailPass
                : CommercialReadinessGateCopy.detailFail,
      ),
      _check(
        id: CommercialReadinessGateCheckId.paywallPriceVisible,
        status: statusFor(
          prerequisite: storeOk,
          value: input.paywallPriceVisible,
        ),
        detailLabel: !storeOk
            ? CommercialReadinessGateCopy.detailBlocked
            : input.paywallPriceVisible
                ? CommercialReadinessGateCopy.detailPass
                : CommercialReadinessGateCopy.detailFail,
      ),
      _check(
        id: CommercialReadinessGateCheckId.sandboxPurchaseWorks,
        status: statusFor(
          prerequisite: storeOk,
          value: input.sandboxPurchaseWorks,
        ),
        detailLabel: !storeOk
            ? CommercialReadinessGateCopy.detailBlocked
            : input.sandboxPurchaseWorks
                ? CommercialReadinessGateCopy.detailPass
                : CommercialReadinessGateCopy.detailFail,
      ),
      _check(
        id: CommercialReadinessGateCheckId.restoreWorks,
        status: statusFor(prerequisite: purchaseOk, value: input.restoreWorks),
        detailLabel: !purchaseOk
            ? CommercialReadinessGateCopy.detailBlocked
            : input.restoreWorks
                ? CommercialReadinessGateCopy.detailPass
                : CommercialReadinessGateCopy.detailFail,
      ),
      _check(
        id: CommercialReadinessGateCheckId.entitlementPersists,
        status: statusFor(
          prerequisite: restoreOk,
          value: input.entitlementPersists,
        ),
        detailLabel: !restoreOk
            ? CommercialReadinessGateCopy.detailBlocked
            : input.entitlementPersists
                ? CommercialReadinessGateCopy.detailPass
                : CommercialReadinessGateCopy.detailFail,
      ),
      _check(
        id: CommercialReadinessGateCheckId.testFlightBuildUploaded,
        status: statusFor(
          prerequisite: productOk,
          value: input.testFlightBuildUploaded,
        ),
        detailLabel: !productOk
            ? CommercialReadinessGateCopy.detailBlocked
            : input.testFlightBuildUploaded
                ? CommercialReadinessGateCopy.detailPass
                : CommercialReadinessGateCopy.detailFail,
      ),
      _check(
        id: CommercialReadinessGateCheckId.paidIntentBetaComplete,
        status: statusFor(
          prerequisite: entitlementOk,
          value: input.paidIntentBetaComplete,
        ),
        detailLabel: !entitlementOk
            ? CommercialReadinessGateCopy.detailBlocked
            : input.paidIntentBetaComplete
                ? CommercialReadinessGateCopy.detailPass
                : CommercialReadinessGateCopy.detailPending,
      ),
      _check(
        id: CommercialReadinessGateCheckId.secretsRotationDone,
        status: statusFor(
          prerequisite: betaOk,
          value: input.secretsRotationDone,
        ),
        detailLabel: !betaOk
            ? CommercialReadinessGateCopy.detailBlocked
            : input.secretsRotationDone
                ? CommercialReadinessGateCopy.detailPass
                : CommercialReadinessGateCopy.detailFail,
      ),
    ];
  }

  static CommercialReadinessGateStatus _resolveStatus(
    CommercialReadinessGateInput input,
    List<CommercialReadinessGateCheck> checks,
  ) {
    if (!input.productPromiseClear ||
        !input.firstJourneyStable ||
        !input.firstProofUsefulEnough ||
        !input.proPromiseClear) {
      return CommercialReadinessGateStatus.productReadyOnly;
    }

    if (!input.revenueCatProductLoads || !input.testFlightBuildUploaded) {
      return CommercialReadinessGateStatus.storeBlocked;
    }

    if (!input.paywallPriceVisible || !input.sandboxPurchaseWorks) {
      return CommercialReadinessGateStatus.purchaseBlocked;
    }

    if (!input.restoreWorks) {
      return CommercialReadinessGateStatus.restoreBlocked;
    }

    if (!input.entitlementPersists) {
      return CommercialReadinessGateStatus.entitlementBlocked;
    }

    if (!input.paidIntentBetaComplete) {
      return CommercialReadinessGateStatus.betaBlocked;
    }

    if (!input.secretsRotationDone) {
      return CommercialReadinessGateStatus.productionBlockedBySecrets;
    }

    final allPass = checks.every(
      (check) => check.status == CommercialReadinessGateCheckStatus.pass,
    );
    if (allPass) {
      return CommercialReadinessGateStatus.commerciallyReady;
    }

    return CommercialReadinessGateStatus.betaBlocked;
  }

  static CommercialReadinessGateCheck? _earliestBlocker(
    List<CommercialReadinessGateCheck> checks,
  ) {
    for (final check in checks) {
      if (check.status == CommercialReadinessGateCheckStatus.fail) {
        return check;
      }
    }
    return null;
  }

  static CommercialReadinessGateCheck _check({
    required CommercialReadinessGateCheckId id,
    required CommercialReadinessGateCheckStatus status,
    required String detailLabel,
  }) =>
      CommercialReadinessGateCheck(
        id: id,
        label: CommercialReadinessGateCopy.labelFor(id),
        status: status,
        detailLabel: detailLabel,
      );
}

class CommercialReadinessGateInput {
  const CommercialReadinessGateInput({
    this.productPromiseClear = false,
    this.firstJourneyStable = false,
    this.firstProofUsefulEnough = false,
    this.proPromiseClear = false,
    this.revenueCatProductLoads = false,
    this.paywallPriceVisible = false,
    this.sandboxPurchaseWorks = false,
    this.restoreWorks = false,
    this.entitlementPersists = false,
    this.testFlightBuildUploaded = false,
    this.paidIntentBetaComplete = false,
    this.secretsRotationDone = false,
  });

  final bool productPromiseClear;
  final bool firstJourneyStable;
  final bool firstProofUsefulEnough;
  final bool proPromiseClear;
  final bool revenueCatProductLoads;
  final bool paywallPriceVisible;
  final bool sandboxPurchaseWorks;
  final bool restoreWorks;
  final bool entitlementPersists;
  final bool testFlightBuildUploaded;
  final bool paidIntentBetaComplete;
  final bool secretsRotationDone;
}

class CommercialReadinessGateCheck {
  const CommercialReadinessGateCheck({
    required this.id,
    required this.label,
    required this.status,
    required this.detailLabel,
  });

  final CommercialReadinessGateCheckId id;
  final String label;
  final CommercialReadinessGateCheckStatus status;
  final String detailLabel;
}

class CommercialReadinessGateResult {
  const CommercialReadinessGateResult({
    required this.status,
    required this.message,
    required this.recommendation,
    required this.checks,
    required this.earliestBlocker,
    required this.commerciallyReady,
    required this.productReadyOnly,
  });

  final CommercialReadinessGateStatus status;
  final String message;
  final String recommendation;
  final List<CommercialReadinessGateCheck> checks;
  final CommercialReadinessGateCheck? earliestBlocker;
  final bool commerciallyReady;
  final bool productReadyOnly;
}

class CommercialReadinessGateReport {
  const CommercialReadinessGateReport({
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
  final CommercialReadinessGateResult result;
}
