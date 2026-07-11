/// Pro access enforcement audit copy — clarify what Pro access actually enforces.
abstract final class ProAccessEnforcementAuditCopy {
  ProAccessEnforcementAuditCopy._();

  static const headline = 'Pro access enforcement audit';

  static const body =
      'Clarify what Pro access is enforced locally, via RevenueCat, not enforced '
      'yet, acceptable for TestFlight, or a production blocker. Audit only — no '
      'account system, backend sync, or purchase behavior changes.';

  static const orderLine =
      'Audit: RevenueCat entitlement → restore → local cache → reinstall → account '
      'identity → device sharing → server-side entitlement → privacy lock vs Pro.';

  static const itemRevenueCatEntitlement = 'RevenueCat entitlement active';
  static const itemRestoreEntitlement = 'Restore entitlement';
  static const itemLocalCache = 'Local entitlement cache';
  static const itemReinstallBehavior = 'Reinstall behavior';
  static const itemAccountIdentity = 'Account identity linked to billing';
  static const itemDeviceSharing = 'Device and Family Sharing prevention';
  static const itemServerSideEntitlement = 'Server-side entitlement check';
  static const itemPrivacyLockSeparate = 'Privacy lock separate from Pro';

  static const classificationEnforcedLocally = 'Enforced locally';
  static const classificationEnforcedByRevenueCat = 'Enforced by RevenueCat';
  static const classificationNotEnforcedYet = 'Not enforced yet';
  static const classificationAcceptableForTestFlight =
      'Acceptable for TestFlight';
  static const classificationProductionBlocker = 'Production blocker';

  static const detailVerified = 'Verified';
  static const detailBroken = 'Broken — fix before production';
  static const detailDocumentedGap = 'Documented gap';
  static const detailNotApplicableYet = 'Not applicable until RevenueCat is live';
  static const detailRestoreRequired = 'Restore path required after reinstall';

  static const testFlightAcceptableLine =
      'Purchase, restore, and entitlement mechanics are acceptable for TestFlight. '
      'Documented gaps remain before full production anti-sharing.';

  static const productionBlockedLine =
      'Pro access enforcement has a production blocker. Fix purchase, restore, '
      'or entitlement mechanics before submission.';

  static const enforcementDocumentedLine =
      'Pro access enforcement is documented. No production blockers in the audit.';

  static const guardrail =
      'Pro access enforcement audit classifies enforcement only. Do not build account '
      'system, add backend sync, or block TestFlight unless purchase, restore, or '
      'entitlement is broken.';

  static String labelFor(ProAccessEnforcementAuditItemId id) => switch (id) {
        ProAccessEnforcementAuditItemId.revenueCatEntitlement =>
          itemRevenueCatEntitlement,
        ProAccessEnforcementAuditItemId.restoreEntitlement =>
          itemRestoreEntitlement,
        ProAccessEnforcementAuditItemId.localCache => itemLocalCache,
        ProAccessEnforcementAuditItemId.reinstallBehavior => itemReinstallBehavior,
        ProAccessEnforcementAuditItemId.accountIdentity => itemAccountIdentity,
        ProAccessEnforcementAuditItemId.deviceSharing => itemDeviceSharing,
        ProAccessEnforcementAuditItemId.serverSideEntitlement =>
          itemServerSideEntitlement,
        ProAccessEnforcementAuditItemId.privacyLockSeparate =>
          itemPrivacyLockSeparate,
      };

  static String classificationLabel(
    ProAccessEnforcementClassification classification,
  ) =>
      switch (classification) {
        ProAccessEnforcementClassification.enforcedLocally =>
          classificationEnforcedLocally,
        ProAccessEnforcementClassification.enforcedByRevenueCat =>
          classificationEnforcedByRevenueCat,
        ProAccessEnforcementClassification.notEnforcedYet =>
          classificationNotEnforcedYet,
        ProAccessEnforcementClassification.acceptableForTestFlight =>
          classificationAcceptableForTestFlight,
        ProAccessEnforcementClassification.productionBlocker =>
          classificationProductionBlocker,
      };

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield body;
    yield orderLine;
    yield itemRevenueCatEntitlement;
    yield itemRestoreEntitlement;
    yield itemLocalCache;
    yield itemReinstallBehavior;
    yield itemAccountIdentity;
    yield itemDeviceSharing;
    yield itemServerSideEntitlement;
    yield itemPrivacyLockSeparate;
    yield classificationEnforcedLocally;
    yield classificationEnforcedByRevenueCat;
    yield classificationNotEnforcedYet;
    yield classificationAcceptableForTestFlight;
    yield classificationProductionBlocker;
    yield detailVerified;
    yield detailBroken;
    yield detailDocumentedGap;
    yield detailNotApplicableYet;
    yield detailRestoreRequired;
    yield testFlightAcceptableLine;
    yield productionBlockedLine;
    yield enforcementDocumentedLine;
    yield guardrail;
  }
}

enum ProAccessEnforcementAuditItemId {
  revenueCatEntitlement,
  restoreEntitlement,
  localCache,
  reinstallBehavior,
  accountIdentity,
  deviceSharing,
  serverSideEntitlement,
  privacyLockSeparate,
}

enum ProAccessEnforcementClassification {
  enforcedLocally,
  enforcedByRevenueCat,
  notEnforcedYet,
  acceptableForTestFlight,
  productionBlocker,
}
