/// Android after iOS proof copy — block Android expansion until iOS proof lands.
abstract final class AndroidAfterIosProofCopy {
  AndroidAfterIosProofCopy._();

  static const headline = 'Android after iOS proof gate';

  static const body =
      'Block Android expansion until iOS purchase, restore, and paid intent are proven. '
      'Classification and gating documentation only.';

  static const positioning =
      'Android expansion stays frozen until iOS TestFlight, RevenueCat, purchase, restore, '
      'entitlement, paid intent, and secrets safety are proven.';

  static const orderLine =
      'Rules: Android work blocked until prerequisites pass; Android setup documented but not prioritised.';

  static const prereqOrderLine =
      'Prerequisites: iOS TestFlight uploaded, RevenueCat products load, sandbox purchase works, '
      'restore works, entitlement persists, paid-intent beta promising, no production secrets blocker.';

  static const guardrail =
      'Android after iOS proof gate blocks Android expansion until iOS purchase, restore, and paid intent '
      'are proven. Android work blocked until prerequisites pass. Android setup may be documented but not '
      'prioritised before iOS proof.';

  static const androidFrozenLine =
      'Keep Android expansion frozen until iOS purchase, restore, entitlement, paid intent, and secrets safety pass.';

  static const androidExpansionUnblockedLine =
      'iOS proof complete. Android expansion may proceed — setup stays documented until prioritisation is intentional.';

  static const detailPass = 'Pass';
  static const detailPending = 'Pending';
  static const detailFail = 'Fail';

  static const detailBlockedBeforeIosProof = 'Blocked before iOS proof';
  static const detailAndroidExpansionUnblocked = 'Android expansion unblocked';

  static String prereqLabelFor(AndroidAfterIosProofPrereqId id) => switch (id) {
        AndroidAfterIosProofPrereqId.iosTestFlightUploaded =>
          'iOS TestFlight uploaded',
        AndroidAfterIosProofPrereqId.iosRevenueCatProductsLoad =>
          'iOS RevenueCat products load',
        AndroidAfterIosProofPrereqId.iosSandboxPurchaseWorks =>
          'iOS sandbox purchase works',
        AndroidAfterIosProofPrereqId.iosRestoreWorks => 'iOS restore works',
        AndroidAfterIosProofPrereqId.iosEntitlementPersists =>
          'iOS entitlement persists',
        AndroidAfterIosProofPrereqId.paidIntentBetaPromising =>
          'Paid-intent beta promising',
        AndroidAfterIosProofPrereqId.noProductionSecretsBlocker =>
          'No production secrets blocker',
      };

  static String ruleLabelFor(AndroidAfterIosProofRuleId id) => switch (id) {
        AndroidAfterIosProofRuleId.androidWorkBlockedUntilPrereqsPass =>
          'Android work blocked until prerequisites pass',
        AndroidAfterIosProofRuleId.androidSetupDocumentedNotPrioritised =>
          'Android setup documented but not prioritised',
      };

  static String messageFor(AndroidAfterIosProofGateDecision decision) =>
      switch (decision) {
        AndroidAfterIosProofGateDecision.androidFrozen => androidFrozenLine,
        AndroidAfterIosProofGateDecision.androidExpansionUnblocked =>
          androidExpansionUnblockedLine,
      };

  static String recommendationFor(AndroidAfterIosProofGateDecision decision) =>
      switch (decision) {
        AndroidAfterIosProofGateDecision.androidFrozen =>
          'Finish iOS TestFlight, RevenueCat, purchase, restore, entitlement, paid intent, and secrets safety before Android work.',
        AndroidAfterIosProofGateDecision.androidExpansionUnblocked =>
          'Android expansion may proceed. Keep setup documentation separate from launch prioritisation until ready.',
      };

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield body;
    yield positioning;
    yield orderLine;
    yield prereqOrderLine;
    yield guardrail;
    yield androidFrozenLine;
    yield androidExpansionUnblockedLine;
    yield detailPass;
    yield detailPending;
    yield detailFail;
    yield detailBlockedBeforeIosProof;
    yield detailAndroidExpansionUnblocked;
    for (final id in AndroidAfterIosProofPrereqId.values) {
      yield prereqLabelFor(id);
    }
    for (final id in AndroidAfterIosProofRuleId.values) {
      yield ruleLabelFor(id);
    }
    for (final decision in AndroidAfterIosProofGateDecision.values) {
      yield messageFor(decision);
      yield recommendationFor(decision);
    }
  }
}

enum AndroidAfterIosProofPrereqId {
  iosTestFlightUploaded,
  iosRevenueCatProductsLoad,
  iosSandboxPurchaseWorks,
  iosRestoreWorks,
  iosEntitlementPersists,
  paidIntentBetaPromising,
  noProductionSecretsBlocker,
}

enum AndroidAfterIosProofPrereqStatus {
  pass,
  pending,
  fail,
}

enum AndroidAfterIosProofRuleId {
  androidWorkBlockedUntilPrereqsPass,
  androidSetupDocumentedNotPrioritised,
}

enum AndroidAfterIosProofRuleStatus {
  pass,
  fail,
}

enum AndroidAfterIosProofGateDecision {
  androidFrozen,
  androidExpansionUnblocked,
}
