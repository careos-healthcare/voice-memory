/// Commercial readiness gate copy — product vs commercial readiness only.
abstract final class CommercialReadinessGateCopy {
  CommercialReadinessGateCopy._();

  static const headline = 'Commercial readiness gate';

  static const body =
      'State clearly whether the product is commercially ready, not just product-ready. '
      'Classification and repair routing only — no product features.';

  static const orderLine =
      'Checks: product promise, first journey, first proof, Pro promise, RevenueCat '
      'products, paywall price, sandbox purchase, restore, entitlement persistence, '
      'TestFlight upload, paid-intent beta, secrets rotation.';

  static const checkProductPromiseClear = 'Product promise clear';
  static const checkFirstJourneyStable = 'First journey stable';
  static const checkFirstProofUsefulEnough = 'First proof useful enough';
  static const checkProPromiseClear = 'Pro promise clear';
  static const checkRevenueCatProductLoads = 'RevenueCat product loads';
  static const checkPaywallPriceVisible = 'Paywall price visible';
  static const checkSandboxPurchaseWorks = 'Sandbox purchase works';
  static const checkRestoreWorks = 'Restore works';
  static const checkEntitlementPersists = 'Entitlement persists';
  static const checkTestFlightBuildUploaded = 'TestFlight build uploaded';
  static const checkPaidIntentBetaComplete = 'Paid-intent beta complete';
  static const checkSecretsRotationDone =
      'Secrets rotation done before production';

  static const detailPass = 'Verified';
  static const detailFail = 'Blocked';
  static const detailBlocked = 'Blocked by earlier step';
  static const detailPending = 'Not verified yet';

  static const productReadyOnlyLine =
      'Product-ready only. Fix product promise, first journey, first proof, or Pro '
      'promise before commercial work.';

  static const storeBlockedLine =
      'Store blocked. Prove RevenueCat products load and TestFlight upload before '
      'purchase validation.';

  static const purchaseBlockedLine =
      'Purchase blocked. Fix paywall price visibility or sandbox purchase mechanics '
      'only — no paywall redesign.';

  static const restoreBlockedLine =
      'Restore blocked. Prove restore purchases works without changing product '
      'surfaces.';

  static const entitlementBlockedLine =
      'Entitlement blocked. Prove Pro entitlement persists after purchase and restore.';

  static const betaBlockedLine =
      'Beta blocked. Finish paid-intent beta validation before calling commercial '
      'readiness.';

  static const productionBlockedBySecretsLine =
      'Production blocked by secrets. Rotate production secrets before submission.';

  static const commerciallyReadyLine =
      'Commercially ready. Product promise, purchase path, beta proof, and production '
      'secrets all pass.';

  static const guardrail =
      'Commercial readiness gate classifies readiness only. No product features and '
      'no paywall mechanics changes unless purchase, restore, or entitlement is the '
      'blocker.';

  static String labelFor(CommercialReadinessGateCheckId id) => switch (id) {
    CommercialReadinessGateCheckId.productPromiseClear =>
      checkProductPromiseClear,
    CommercialReadinessGateCheckId.firstJourneyStable =>
      checkFirstJourneyStable,
    CommercialReadinessGateCheckId.firstProofUsefulEnough =>
      checkFirstProofUsefulEnough,
    CommercialReadinessGateCheckId.proPromiseClear => checkProPromiseClear,
    CommercialReadinessGateCheckId.revenueCatProductLoads =>
      checkRevenueCatProductLoads,
    CommercialReadinessGateCheckId.paywallPriceVisible =>
      checkPaywallPriceVisible,
    CommercialReadinessGateCheckId.sandboxPurchaseWorks =>
      checkSandboxPurchaseWorks,
    CommercialReadinessGateCheckId.restoreWorks => checkRestoreWorks,
    CommercialReadinessGateCheckId.entitlementPersists =>
      checkEntitlementPersists,
    CommercialReadinessGateCheckId.testFlightBuildUploaded =>
      checkTestFlightBuildUploaded,
    CommercialReadinessGateCheckId.paidIntentBetaComplete =>
      checkPaidIntentBetaComplete,
    CommercialReadinessGateCheckId.secretsRotationDone =>
      checkSecretsRotationDone,
  };

  static String messageFor(
    CommercialReadinessGateStatus status,
  ) => switch (status) {
    CommercialReadinessGateStatus.productReadyOnly => productReadyOnlyLine,
    CommercialReadinessGateStatus.storeBlocked => storeBlockedLine,
    CommercialReadinessGateStatus.purchaseBlocked => purchaseBlockedLine,
    CommercialReadinessGateStatus.restoreBlocked => restoreBlockedLine,
    CommercialReadinessGateStatus.entitlementBlocked => entitlementBlockedLine,
    CommercialReadinessGateStatus.betaBlocked => betaBlockedLine,
    CommercialReadinessGateStatus.productionBlockedBySecrets =>
      productionBlockedBySecretsLine,
    CommercialReadinessGateStatus.commerciallyReady => commerciallyReadyLine,
  };

  static String recommendationFor(
    CommercialReadinessGateStatus status,
  ) => switch (status) {
    CommercialReadinessGateStatus.productReadyOnly =>
      'Repair product promise, first journey, first proof, or Pro promise copy only.',
    CommercialReadinessGateStatus.storeBlocked =>
      'Finish store readiness: RevenueCat products and TestFlight upload.',
    CommercialReadinessGateStatus.purchaseBlocked =>
      'Fix purchase mechanics: paywall price visibility and sandbox purchase path.',
    CommercialReadinessGateStatus.restoreBlocked =>
      'Fix restore purchases path without changing paywall positioning.',
    CommercialReadinessGateStatus.entitlementBlocked =>
      'Fix entitlement persistence after purchase and restore.',
    CommercialReadinessGateStatus.betaBlocked =>
      'Complete paid-intent beta validation on TestFlight.',
    CommercialReadinessGateStatus.productionBlockedBySecrets =>
      'Rotate production secrets before App Store submission.',
    CommercialReadinessGateStatus.commerciallyReady =>
      'Commercial readiness passes. Proceed to production submission.',
  };

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield body;
    yield orderLine;
    yield checkProductPromiseClear;
    yield checkFirstJourneyStable;
    yield checkFirstProofUsefulEnough;
    yield checkProPromiseClear;
    yield checkRevenueCatProductLoads;
    yield checkPaywallPriceVisible;
    yield checkSandboxPurchaseWorks;
    yield checkRestoreWorks;
    yield checkEntitlementPersists;
    yield checkTestFlightBuildUploaded;
    yield checkPaidIntentBetaComplete;
    yield checkSecretsRotationDone;
    yield detailPass;
    yield detailFail;
    yield detailBlocked;
    yield detailPending;
    yield productReadyOnlyLine;
    yield storeBlockedLine;
    yield purchaseBlockedLine;
    yield restoreBlockedLine;
    yield entitlementBlockedLine;
    yield betaBlockedLine;
    yield productionBlockedBySecretsLine;
    yield commerciallyReadyLine;
    yield guardrail;
    for (final status in CommercialReadinessGateStatus.values) {
      yield messageFor(status);
      yield recommendationFor(status);
    }
  }
}

enum CommercialReadinessGateCheckId {
  productPromiseClear,
  firstJourneyStable,
  firstProofUsefulEnough,
  proPromiseClear,
  revenueCatProductLoads,
  paywallPriceVisible,
  sandboxPurchaseWorks,
  restoreWorks,
  entitlementPersists,
  testFlightBuildUploaded,
  paidIntentBetaComplete,
  secretsRotationDone,
}

enum CommercialReadinessGateCheckStatus { pass, fail, blocked }

enum CommercialReadinessGateStatus {
  productReadyOnly,
  storeBlocked,
  purchaseBlocked,
  restoreBlocked,
  entitlementBlocked,
  betaBlocked,
  productionBlockedBySecrets,
  commerciallyReady,
}