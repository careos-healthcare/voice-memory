/// Single store readiness source copy — one canonical release checklist.
abstract final class StoreReadinessSingleSourceCopy {
  StoreReadinessSingleSourceCopy._();

  static const headline = 'Store readiness single source';

  static const body =
      'One canonical store and release checklist. Bridge existing audits without '
      'duplicating purchase, paywall, or RevenueCat behavior.';

  static const orderLine =
      'Order: signing → metadata → support/privacy/terms → screenshots → '
      'RevenueCat products → purchase path → restore path → entitlement '
      'persistence → physical device smoke → TestFlight upload → paid intent '
      'beta → secrets rotation before production submission.';

  static const stepSigning = 'Signing configured';
  static const stepMetadata = 'App Store metadata ready';
  static const stepSupportPrivacyTerms = 'Support, privacy, and terms ready';
  static const stepScreenshots = 'Screenshots ready';
  static const stepRevenueCatProducts = 'RevenueCat products verified';
  static const stepPurchasePath = 'Purchase path reachable';
  static const stepRestorePath = 'Restore path verified';
  static const stepEntitlementPersistence =
      'Entitlement persists after restart';
  static const stepPhysicalDeviceSmoke = 'Physical device smoke passed';
  static const stepTestFlightUpload = 'TestFlight upload ready';
  static const stepPaidIntentBeta = 'Paid intent beta ready';
  static const stepSecretsRotation =
      'Secrets rotated before production submission';

  static const detailPass = 'Verified';
  static const detailFail = 'Missing';
  static const detailPending = 'Not yet verified';
  static const detailBlocked = 'Blocked by earlier step';

  static const notReadyLine =
      'Store readiness not ready. Fix the earliest failing canonical step first.';

  static const testFlightReadyLine =
      'TestFlight-ready blockers cleared. Finish paid intent beta and secrets '
      'rotation before production submission.';

  static const paidIntentPendingLine =
      'Store path is TestFlight-ready. Run paid intent beta before submission.';

  static const secretsPendingLine =
      'Paid intent beta is ready. Rotate secrets before production submission.';

  static const submissionReadyLine =
      'All canonical store readiness steps verified for production submission.';

  static const guardrail =
      'Single store readiness source classifies release steps only. Do not change '
      'purchase, paywall, or RevenueCat behavior.';

  static String labelFor(StoreReadinessSingleSourceStepId id) => switch (id) {
    StoreReadinessSingleSourceStepId.signing => stepSigning,
    StoreReadinessSingleSourceStepId.metadata => stepMetadata,
    StoreReadinessSingleSourceStepId.supportPrivacyTerms =>
      stepSupportPrivacyTerms,
    StoreReadinessSingleSourceStepId.screenshots => stepScreenshots,
    StoreReadinessSingleSourceStepId.revenueCatProducts =>
      stepRevenueCatProducts,
    StoreReadinessSingleSourceStepId.purchasePath => stepPurchasePath,
    StoreReadinessSingleSourceStepId.restorePath => stepRestorePath,
    StoreReadinessSingleSourceStepId.entitlementPersistence =>
      stepEntitlementPersistence,
    StoreReadinessSingleSourceStepId.physicalDeviceSmoke =>
      stepPhysicalDeviceSmoke,
    StoreReadinessSingleSourceStepId.testFlightUpload => stepTestFlightUpload,
    StoreReadinessSingleSourceStepId.paidIntentBeta => stepPaidIntentBeta,
    StoreReadinessSingleSourceStepId.secretsRotation => stepSecretsRotation,
  };

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield body;
    yield orderLine;
    yield stepSigning;
    yield stepMetadata;
    yield stepSupportPrivacyTerms;
    yield stepScreenshots;
    yield stepRevenueCatProducts;
    yield stepPurchasePath;
    yield stepRestorePath;
    yield stepEntitlementPersistence;
    yield stepPhysicalDeviceSmoke;
    yield stepTestFlightUpload;
    yield stepPaidIntentBeta;
    yield stepSecretsRotation;
    yield detailPass;
    yield detailFail;
    yield detailPending;
    yield detailBlocked;
    yield notReadyLine;
    yield testFlightReadyLine;
    yield paidIntentPendingLine;
    yield secretsPendingLine;
    yield submissionReadyLine;
  }
}

enum StoreReadinessSingleSourceStepId {
  signing,
  metadata,
  supportPrivacyTerms,
  screenshots,
  revenueCatProducts,
  purchasePath,
  restorePath,
  entitlementPersistence,
  physicalDeviceSmoke,
  testFlightUpload,
  paidIntentBeta,
  secretsRotation,
}
