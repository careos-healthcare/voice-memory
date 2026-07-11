import '../commercial_readiness_gate/commercial_readiness_gate.dart';
import 'commercial_proof_executor_copy.dart';

/// Commercial proof executor — one executable release checklist.
abstract final class CommercialProofExecutor {
  CommercialProofExecutor._();

  static const checkCount = 12;

  static const canonicalChecklistOrder = [
    CommercialProofExecutorCheckId.productPromiseClear,
    CommercialProofExecutorCheckId.firstJourneyStable,
    CommercialProofExecutorCheckId.firstProofUseful,
    CommercialProofExecutorCheckId.proPromiseClear,
    CommercialProofExecutorCheckId.revenueCatProductsLoad,
    CommercialProofExecutorCheckId.paywallPriceVisible,
    CommercialProofExecutorCheckId.sandboxPurchaseWorks,
    CommercialProofExecutorCheckId.restoreWorks,
    CommercialProofExecutorCheckId.entitlementPersists,
    CommercialProofExecutorCheckId.testFlightUploaded,
    CommercialProofExecutorCheckId.paidIntentBetaComplete,
    CommercialProofExecutorCheckId.secretsRotationComplete,
  ];

  static CommercialProofExecutorResult build(
    CommercialProofExecutorInput input,
  ) {
    final checks = _buildChecks(input);
    final status = _resolveStatus(input);
    final commerciallyReady =
        status == CommercialProofExecutorStatus.commerciallyReady;
    final internalTestFlightReady = _internalTestFlightReady(input, status);
    return CommercialProofExecutorResult(
      status: status,
      message: CommercialProofExecutorCopy.messageFor(status),
      recommendation: CommercialProofExecutorCopy.recommendationFor(status),
      checks: checks,
      checklistOrder: canonicalChecklistOrder,
      earliestBlocker: checks
          .where((check) => check.status == CommercialProofExecutorCheckStatus.fail)
          .map((check) => check.id)
          .firstOrNull,
      commerciallyReady: commerciallyReady,
      internalTestFlightReady: internalTestFlightReady,
      productionSubmissionReady: commerciallyReady,
    );
  }

  static CommercialProofExecutorResult fromCommercialReadinessGateInput(
    CommercialReadinessGateInput input, {
    bool secretsRotationRepoSafe = true,
  }) =>
      build(
        CommercialProofExecutorInput(
          productPromiseClear: input.productPromiseClear,
          firstJourneyStable: input.firstJourneyStable,
          firstProofUseful: input.firstProofUsefulEnough,
          proPromiseClear: input.proPromiseClear,
          revenueCatProductsLoad: input.revenueCatProductLoads,
          paywallPriceVisible: input.paywallPriceVisible,
          sandboxPurchaseWorks: input.sandboxPurchaseWorks,
          restoreWorks: input.restoreWorks,
          entitlementPersists: input.entitlementPersists,
          testFlightUploaded: input.testFlightBuildUploaded,
          paidIntentBetaComplete: input.paidIntentBetaComplete,
          secretsRotationComplete: input.secretsRotationDone,
          secretsRotationRepoSafe: secretsRotationRepoSafe,
        ),
      );

  static CommercialProofExecutorReport report(
    CommercialProofExecutorResult result,
  ) =>
      CommercialProofExecutorReport(
        headline: CommercialProofExecutorCopy.headline,
        body: CommercialProofExecutorCopy.body,
        orderLine: CommercialProofExecutorCopy.orderLine,
        guardrail: CommercialProofExecutorCopy.guardrail,
        result: result,
      );

  static bool _internalTestFlightReady(
    CommercialProofExecutorInput input,
    CommercialProofExecutorStatus status,
  ) {
    if (status == CommercialProofExecutorStatus.commerciallyReady) {
      return true;
    }
    if (status != CommercialProofExecutorStatus.productionBlockedBySecrets) {
      return false;
    }
    return input.secretsRotationRepoSafe && _allExceptSecretsPass(input);
  }

  static bool _allExceptSecretsPass(CommercialProofExecutorInput input) =>
      input.productPromiseClear &&
      input.firstJourneyStable &&
      input.firstProofUseful &&
      input.proPromiseClear &&
      input.revenueCatProductsLoad &&
      input.paywallPriceVisible &&
      input.sandboxPurchaseWorks &&
      input.restoreWorks &&
      input.entitlementPersists &&
      input.testFlightUploaded &&
      input.paidIntentBetaComplete;

  static CommercialProofExecutorStatus _resolveStatus(
    CommercialProofExecutorInput input,
  ) {
    if (!input.productPromiseClear ||
        !input.firstJourneyStable ||
        !input.firstProofUseful ||
        !input.proPromiseClear) {
      return CommercialProofExecutorStatus.productReadyOnly;
    }

    if (!input.revenueCatProductsLoad) {
      return CommercialProofExecutorStatus.storeBlocked;
    }

    if (!input.paywallPriceVisible || !input.sandboxPurchaseWorks) {
      return CommercialProofExecutorStatus.purchaseBlocked;
    }

    if (!input.restoreWorks) {
      return CommercialProofExecutorStatus.restoreBlocked;
    }

    if (!input.entitlementPersists) {
      return CommercialProofExecutorStatus.entitlementBlocked;
    }

    if (!input.testFlightUploaded) {
      return CommercialProofExecutorStatus.testFlightBlocked;
    }

    if (!input.paidIntentBetaComplete) {
      return CommercialProofExecutorStatus.betaBlocked;
    }

    if (!input.secretsRotationComplete) {
      return CommercialProofExecutorStatus.productionBlockedBySecrets;
    }

    return CommercialProofExecutorStatus.commerciallyReady;
  }

  static List<CommercialProofExecutorCheck> _buildChecks(
    CommercialProofExecutorInput input,
  ) {
    CommercialProofExecutorCheckStatus statusFor({
      required bool prerequisite,
      required bool value,
    }) {
      if (!prerequisite) return CommercialProofExecutorCheckStatus.blocked;
      return value
          ? CommercialProofExecutorCheckStatus.pass
          : CommercialProofExecutorCheckStatus.fail;
    }

    final productOk = input.productPromiseClear &&
        input.firstJourneyStable &&
        input.firstProofUseful &&
        input.proPromiseClear;
    final storeOk = productOk && input.revenueCatProductsLoad;
    final purchaseOk = storeOk &&
        input.paywallPriceVisible &&
        input.sandboxPurchaseWorks;
    final restoreOk = purchaseOk && input.restoreWorks;
    final entitlementOk = restoreOk && input.entitlementPersists;
    final testFlightOk = entitlementOk && input.testFlightUploaded;
    final betaOk = testFlightOk && input.paidIntentBetaComplete;

    return [
      _check(
        id: CommercialProofExecutorCheckId.productPromiseClear,
        status: statusFor(prerequisite: true, value: input.productPromiseClear),
      ),
      _check(
        id: CommercialProofExecutorCheckId.firstJourneyStable,
        status: statusFor(prerequisite: true, value: input.firstJourneyStable),
      ),
      _check(
        id: CommercialProofExecutorCheckId.firstProofUseful,
        status: statusFor(prerequisite: true, value: input.firstProofUseful),
      ),
      _check(
        id: CommercialProofExecutorCheckId.proPromiseClear,
        status: statusFor(prerequisite: true, value: input.proPromiseClear),
      ),
      _check(
        id: CommercialProofExecutorCheckId.revenueCatProductsLoad,
        status: statusFor(
          prerequisite: productOk,
          value: input.revenueCatProductsLoad,
        ),
      ),
      _check(
        id: CommercialProofExecutorCheckId.paywallPriceVisible,
        status: statusFor(
          prerequisite: storeOk,
          value: input.paywallPriceVisible,
        ),
      ),
      _check(
        id: CommercialProofExecutorCheckId.sandboxPurchaseWorks,
        status: statusFor(
          prerequisite: storeOk,
          value: input.sandboxPurchaseWorks,
        ),
      ),
      _check(
        id: CommercialProofExecutorCheckId.restoreWorks,
        status: statusFor(prerequisite: purchaseOk, value: input.restoreWorks),
      ),
      _check(
        id: CommercialProofExecutorCheckId.entitlementPersists,
        status: statusFor(
          prerequisite: restoreOk,
          value: input.entitlementPersists,
        ),
      ),
      _check(
        id: CommercialProofExecutorCheckId.testFlightUploaded,
        status: statusFor(
          prerequisite: entitlementOk,
          value: input.testFlightUploaded,
        ),
      ),
      _check(
        id: CommercialProofExecutorCheckId.paidIntentBetaComplete,
        status: statusFor(
          prerequisite: testFlightOk,
          value: input.paidIntentBetaComplete,
        ),
      ),
      _check(
        id: CommercialProofExecutorCheckId.secretsRotationComplete,
        status: statusFor(
          prerequisite: betaOk,
          value: input.secretsRotationComplete,
        ),
      ),
    ];
  }

  static CommercialProofExecutorCheck _check({
    required CommercialProofExecutorCheckId id,
    required CommercialProofExecutorCheckStatus status,
  }) =>
      CommercialProofExecutorCheck(
        id: id,
        label: CommercialProofExecutorCopy.labelFor(id),
        status: status,
        detailLabel: switch (status) {
          CommercialProofExecutorCheckStatus.pass =>
            CommercialProofExecutorCopy.detailPass,
          CommercialProofExecutorCheckStatus.fail =>
            CommercialProofExecutorCopy.detailFail,
          CommercialProofExecutorCheckStatus.blocked =>
            CommercialProofExecutorCopy.detailBlocked,
        },
      );
}

class CommercialProofExecutorInput {
  const CommercialProofExecutorInput({
    this.productPromiseClear = false,
    this.firstJourneyStable = false,
    this.firstProofUseful = false,
    this.proPromiseClear = false,
    this.revenueCatProductsLoad = false,
    this.paywallPriceVisible = false,
    this.sandboxPurchaseWorks = false,
    this.restoreWorks = false,
    this.entitlementPersists = false,
    this.testFlightUploaded = false,
    this.paidIntentBetaComplete = false,
    this.secretsRotationComplete = false,
    this.secretsRotationRepoSafe = true,
  });

  final bool productPromiseClear;
  final bool firstJourneyStable;
  final bool firstProofUseful;
  final bool proPromiseClear;
  final bool revenueCatProductsLoad;
  final bool paywallPriceVisible;
  final bool sandboxPurchaseWorks;
  final bool restoreWorks;
  final bool entitlementPersists;
  final bool testFlightUploaded;
  final bool paidIntentBetaComplete;
  final bool secretsRotationComplete;
  final bool secretsRotationRepoSafe;
}

class CommercialProofExecutorCheck {
  const CommercialProofExecutorCheck({
    required this.id,
    required this.label,
    required this.status,
    required this.detailLabel,
  });

  final CommercialProofExecutorCheckId id;
  final String label;
  final CommercialProofExecutorCheckStatus status;
  final String detailLabel;
}

class CommercialProofExecutorResult {
  const CommercialProofExecutorResult({
    required this.status,
    required this.message,
    required this.recommendation,
    required this.checks,
    required this.checklistOrder,
    required this.earliestBlocker,
    required this.commerciallyReady,
    required this.internalTestFlightReady,
    required this.productionSubmissionReady,
  });

  final CommercialProofExecutorStatus status;
  final String message;
  final String recommendation;
  final List<CommercialProofExecutorCheck> checks;
  final List<CommercialProofExecutorCheckId> checklistOrder;
  final CommercialProofExecutorCheckId? earliestBlocker;
  final bool commerciallyReady;
  final bool internalTestFlightReady;
  final bool productionSubmissionReady;
}

class CommercialProofExecutorReport {
  const CommercialProofExecutorReport({
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
  final CommercialProofExecutorResult result;
}
