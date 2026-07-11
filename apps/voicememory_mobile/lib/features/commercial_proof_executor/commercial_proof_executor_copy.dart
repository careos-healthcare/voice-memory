/// Commercial proof executor copy — one executable release checklist.
abstract final class CommercialProofExecutorCopy {
  CommercialProofExecutorCopy._();

  static const headline = 'Commercial proof executor';

  static const body =
      'ArchiveMe is commercially ready only when the product promise, store path, '
      'purchase, restore, entitlement, TestFlight, paid-intent beta, and production '
      'secrets are proven.';

  static const orderLine =
      'Order: product promise, first journey, first proof, Pro promise, RevenueCat '
      'products, paywall price, sandbox purchase, restore, entitlement, TestFlight, '
      'paid-intent beta, secrets rotation.';

  static const guardrail =
      'Do not call the app commercially ready until real purchase, restore, '
      'entitlement, and beta evidence exist.';

  static const checkProductPromiseClear = 'Product promise clear';
  static const checkFirstJourneyStable = 'First journey stable';
  static const checkFirstProofUseful = 'First proof useful';
  static const checkProPromiseClear = 'Pro promise clear';
  static const checkRevenueCatProductsLoad = 'RevenueCat products load';
  static const checkPaywallPriceVisible = 'Paywall price visible';
  static const checkSandboxPurchaseWorks = 'Sandbox purchase works';
  static const checkRestoreWorks = 'Restore works';
  static const checkEntitlementPersists = 'Entitlement persists';
  static const checkTestFlightUploaded = 'TestFlight uploaded';
  static const checkPaidIntentBetaComplete = 'Paid-intent beta complete';
  static const checkSecretsRotationComplete = 'Secrets rotation complete';

  static const detailPass = 'Proven';
  static const detailFail = 'Blocked';
  static const detailBlocked = 'Blocked by earlier step';

  static const productReadyOnlyLine =
      'Product-ready only. Fix product promise, first journey, first proof, or Pro '
      'promise before store proof.';

  static const storeBlockedLine =
      'Store blocked. Prove RevenueCat products load before purchase proof.';

  static const purchaseBlockedLine =
      'Purchase blocked. Prove paywall price visibility and sandbox purchase.';

  static const restoreBlockedLine =
      'Restore blocked. Prove restore purchases before entitlement persistence.';

  static const entitlementBlockedLine =
      'Entitlement blocked. Prove entitlement persists after purchase and restore.';

  static const testFlightBlockedLine =
      'TestFlight blocked. Upload a TestFlight build before paid-intent beta.';

  static const betaBlockedLine =
      'Beta blocked. Complete paid-intent beta before commercial readiness.';

  static const productionBlockedBySecretsLine =
      'Production blocked by secrets. Rotate production secrets before submission.';

  static const commerciallyReadyLine =
      'Commercially ready. Product, store, purchase, beta, and secrets proof pass.';

  static const internalTestFlightReadyLine =
      'Internal TestFlight may proceed. Production submission stays blocked until '
      'secrets rotation is confirmed.';

  static String labelFor(CommercialProofExecutorCheckId id) => switch (id) {
        CommercialProofExecutorCheckId.productPromiseClear =>
          checkProductPromiseClear,
        CommercialProofExecutorCheckId.firstJourneyStable =>
          checkFirstJourneyStable,
        CommercialProofExecutorCheckId.firstProofUseful => checkFirstProofUseful,
        CommercialProofExecutorCheckId.proPromiseClear => checkProPromiseClear,
        CommercialProofExecutorCheckId.revenueCatProductsLoad =>
          checkRevenueCatProductsLoad,
        CommercialProofExecutorCheckId.paywallPriceVisible =>
          checkPaywallPriceVisible,
        CommercialProofExecutorCheckId.sandboxPurchaseWorks =>
          checkSandboxPurchaseWorks,
        CommercialProofExecutorCheckId.restoreWorks => checkRestoreWorks,
        CommercialProofExecutorCheckId.entitlementPersists =>
          checkEntitlementPersists,
        CommercialProofExecutorCheckId.testFlightUploaded =>
          checkTestFlightUploaded,
        CommercialProofExecutorCheckId.paidIntentBetaComplete =>
          checkPaidIntentBetaComplete,
        CommercialProofExecutorCheckId.secretsRotationComplete =>
          checkSecretsRotationComplete,
      };

  static String messageFor(CommercialProofExecutorStatus status) =>
      switch (status) {
        CommercialProofExecutorStatus.productReadyOnly => productReadyOnlyLine,
        CommercialProofExecutorStatus.storeBlocked => storeBlockedLine,
        CommercialProofExecutorStatus.purchaseBlocked => purchaseBlockedLine,
        CommercialProofExecutorStatus.restoreBlocked => restoreBlockedLine,
        CommercialProofExecutorStatus.entitlementBlocked =>
          entitlementBlockedLine,
        CommercialProofExecutorStatus.testFlightBlocked => testFlightBlockedLine,
        CommercialProofExecutorStatus.betaBlocked => betaBlockedLine,
        CommercialProofExecutorStatus.productionBlockedBySecrets =>
          productionBlockedBySecretsLine,
        CommercialProofExecutorStatus.commerciallyReady => commerciallyReadyLine,
      };

  static String recommendationFor(CommercialProofExecutorStatus status) =>
      switch (status) {
        CommercialProofExecutorStatus.productReadyOnly =>
          'Repair product promise, first journey, first proof, or Pro promise only.',
        CommercialProofExecutorStatus.storeBlocked =>
          'Finish RevenueCat product load before purchase validation.',
        CommercialProofExecutorStatus.purchaseBlocked =>
          'Fix paywall price visibility and sandbox purchase mechanics only.',
        CommercialProofExecutorStatus.restoreBlocked =>
          'Fix restore purchases before entitlement persistence proof.',
        CommercialProofExecutorStatus.entitlementBlocked =>
          'Fix entitlement persistence after purchase and restore.',
        CommercialProofExecutorStatus.testFlightBlocked =>
          'Upload TestFlight before paid-intent beta validation.',
        CommercialProofExecutorStatus.betaBlocked =>
          'Complete paid-intent beta validation on TestFlight.',
        CommercialProofExecutorStatus.productionBlockedBySecrets =>
          'Rotate production secrets before App Store submission.',
        CommercialProofExecutorStatus.commerciallyReady =>
          'Commercial proof passes. Proceed to production submission.',
      };

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield body;
    yield orderLine;
    yield guardrail;
    yield checkProductPromiseClear;
    yield checkFirstJourneyStable;
    yield checkFirstProofUseful;
    yield checkProPromiseClear;
    yield checkRevenueCatProductsLoad;
    yield checkPaywallPriceVisible;
    yield checkSandboxPurchaseWorks;
    yield checkRestoreWorks;
    yield checkEntitlementPersists;
    yield checkTestFlightUploaded;
    yield checkPaidIntentBetaComplete;
    yield checkSecretsRotationComplete;
    yield detailPass;
    yield detailFail;
    yield detailBlocked;
    yield productReadyOnlyLine;
    yield storeBlockedLine;
    yield purchaseBlockedLine;
    yield restoreBlockedLine;
    yield entitlementBlockedLine;
    yield testFlightBlockedLine;
    yield betaBlockedLine;
    yield productionBlockedBySecretsLine;
    yield commerciallyReadyLine;
    yield internalTestFlightReadyLine;
    for (final status in CommercialProofExecutorStatus.values) {
      yield messageFor(status);
      yield recommendationFor(status);
    }
  }
}

enum CommercialProofExecutorCheckId {
  productPromiseClear,
  firstJourneyStable,
  firstProofUseful,
  proPromiseClear,
  revenueCatProductsLoad,
  paywallPriceVisible,
  sandboxPurchaseWorks,
  restoreWorks,
  entitlementPersists,
  testFlightUploaded,
  paidIntentBetaComplete,
  secretsRotationComplete,
}

enum CommercialProofExecutorCheckStatus {
  pass,
  fail,
  blocked,
}

enum CommercialProofExecutorStatus {
  productReadyOnly,
  storeBlocked,
  purchaseBlocked,
  restoreBlocked,
  entitlementBlocked,
  testFlightBlocked,
  betaBlocked,
  productionBlockedBySecrets,
  commerciallyReady,
}
