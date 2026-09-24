/// Single launch checklist copy — one source of truth for launch readiness.
abstract final class SingleLaunchChecklistCopy {
  SingleLaunchChecklistCopy._();

  static const headline = 'Single launch checklist';

  static const body =
      'One ordered checklist for TestFlight and App Store submission readiness. '
      'Aggregates existing proof modules without changing product UI or purchase logic.';

  static const orderLine =
      'Order: clean git, version/build, iPhone smoke, iPad smoke, production API, '
      'voice save, typed save, first proof, Pro promise, RevenueCat products, paywall '
      'price, sandbox purchase, entitlement unlock, restore, entitlement persist, '
      'support/privacy/terms, screenshots, TestFlight, paid-intent beta, secrets rotation.';

  static const guardrail =
      'Single launch checklist aggregates readiness only. Do not change product UI, '
      'purchase logic, or analytics emission.';

  static const checkCleanGit = 'Clean git';
  static const checkVersionBuildSet = 'Version/build set';
  static const checkPhysicalIphoneSmoke = 'Physical iPhone smoke';
  static const checkPhysicalIpadSmoke = 'Physical iPad smoke';
  static const checkProductionApiWorks = 'Production API works';
  static const checkVoiceSaveWorks = 'Voice save works';
  static const checkTypedSaveWorks = 'Typed save works';
  static const checkFirstProofWorks = 'First proof works';
  static const checkProPromiseVisible = 'Pro promise visible';
  static const checkRevenueCatProductsLoad = 'RevenueCat products load';
  static const checkPaywallPriceVisible = 'Paywall price visible';
  static const checkSandboxPurchaseWorks = 'Sandbox purchase works';
  static const checkEntitlementUnlocks = 'Entitlement unlocks';
  static const checkRestoreWorks = 'Restore works';
  static const checkEntitlementPersists = 'Entitlement persists';
  static const checkSupportPrivacyTermsWork = 'Support/privacy/terms work';
  static const checkScreenshotsReady = 'Screenshots ready';
  static const checkTestFlightUploaded = 'TestFlight uploaded';
  static const checkPaidIntentBetaComplete = 'Paid-intent beta complete';
  static const checkSecretsRotatedBeforeProduction =
      'Secrets rotated before production';

  static const detailPass = 'Proven';
  static const detailFail = 'Blocked';
  static const detailPending = 'Pending manual proof';

  static const notReadyLine =
      'Launch checklist incomplete. Fix the earliest blocker before TestFlight or '
      'submission.';

  static const testFlightLine =
      'Ready for TestFlight. Production submission stays blocked until secrets '
      'rotation is confirmed.';

  static const submissionLine =
      'Ready for App Store submission. All launch checklist items are proven.';

  static String labelFor(SingleLaunchChecklistItemId id) => switch (id) {
    SingleLaunchChecklistItemId.cleanGit => checkCleanGit,
    SingleLaunchChecklistItemId.versionBuildSet => checkVersionBuildSet,
    SingleLaunchChecklistItemId.physicalIphoneSmoke => checkPhysicalIphoneSmoke,
    SingleLaunchChecklistItemId.physicalIpadSmoke => checkPhysicalIpadSmoke,
    SingleLaunchChecklistItemId.productionApiWorks => checkProductionApiWorks,
    SingleLaunchChecklistItemId.voiceSaveWorks => checkVoiceSaveWorks,
    SingleLaunchChecklistItemId.typedSaveWorks => checkTypedSaveWorks,
    SingleLaunchChecklistItemId.firstProofWorks => checkFirstProofWorks,
    SingleLaunchChecklistItemId.proPromiseVisible => checkProPromiseVisible,
    SingleLaunchChecklistItemId.revenueCatProductsLoad =>
      checkRevenueCatProductsLoad,
    SingleLaunchChecklistItemId.paywallPriceVisible => checkPaywallPriceVisible,
    SingleLaunchChecklistItemId.sandboxPurchaseWorks =>
      checkSandboxPurchaseWorks,
    SingleLaunchChecklistItemId.entitlementUnlocks => checkEntitlementUnlocks,
    SingleLaunchChecklistItemId.restoreWorks => checkRestoreWorks,
    SingleLaunchChecklistItemId.entitlementPersists => checkEntitlementPersists,
    SingleLaunchChecklistItemId.supportPrivacyTermsWork =>
      checkSupportPrivacyTermsWork,
    SingleLaunchChecklistItemId.screenshotsReady => checkScreenshotsReady,
    SingleLaunchChecklistItemId.testFlightUploaded => checkTestFlightUploaded,
    SingleLaunchChecklistItemId.paidIntentBetaComplete =>
      checkPaidIntentBetaComplete,
    SingleLaunchChecklistItemId.secretsRotatedBeforeProduction =>
      checkSecretsRotatedBeforeProduction,
  };

  static String messageFor(SingleLaunchChecklistStatus status) =>
      switch (status) {
        SingleLaunchChecklistStatus.notReady => notReadyLine,
        SingleLaunchChecklistStatus.readyForTestFlight => testFlightLine,
        SingleLaunchChecklistStatus.readyForSubmission => submissionLine,
      };

  static String recommendationFor(
    SingleLaunchChecklistStatus status,
  ) => switch (status) {
    SingleLaunchChecklistStatus.notReady =>
      'Work the checklist in order. Bridge manual proof from existing readiness modules.',
    SingleLaunchChecklistStatus.readyForTestFlight =>
      'Upload to TestFlight and finish paid-intent beta before production submission.',
    SingleLaunchChecklistStatus.readyForSubmission =>
      'Proceed with App Store submission using the release evidence pack.',
  };

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield body;
    yield orderLine;
    yield guardrail;
    yield checkCleanGit;
    yield checkVersionBuildSet;
    yield checkPhysicalIphoneSmoke;
    yield checkPhysicalIpadSmoke;
    yield checkProductionApiWorks;
    yield checkVoiceSaveWorks;
    yield checkTypedSaveWorks;
    yield checkFirstProofWorks;
    yield checkProPromiseVisible;
    yield checkRevenueCatProductsLoad;
    yield checkPaywallPriceVisible;
    yield checkSandboxPurchaseWorks;
    yield checkEntitlementUnlocks;
    yield checkRestoreWorks;
    yield checkEntitlementPersists;
    yield checkSupportPrivacyTermsWork;
    yield checkScreenshotsReady;
    yield checkTestFlightUploaded;
    yield checkPaidIntentBetaComplete;
    yield checkSecretsRotatedBeforeProduction;
    yield detailPass;
    yield detailFail;
    yield detailPending;
    yield notReadyLine;
    yield testFlightLine;
    yield submissionLine;
    for (final status in SingleLaunchChecklistStatus.values) {
      yield messageFor(status);
      yield recommendationFor(status);
    }
  }
}

enum SingleLaunchChecklistItemId {
  cleanGit,
  versionBuildSet,
  physicalIphoneSmoke,
  physicalIpadSmoke,
  productionApiWorks,
  voiceSaveWorks,
  typedSaveWorks,
  firstProofWorks,
  proPromiseVisible,
  revenueCatProductsLoad,
  paywallPriceVisible,
  sandboxPurchaseWorks,
  entitlementUnlocks,
  restoreWorks,
  entitlementPersists,
  supportPrivacyTermsWork,
  screenshotsReady,
  testFlightUploaded,
  paidIntentBetaComplete,
  secretsRotatedBeforeProduction,
}

enum SingleLaunchChecklistStatus {
  notReady,
  readyForTestFlight,
  readyForSubmission,
}

enum SingleLaunchChecklistCheckStatus { pass, fail, pending }
