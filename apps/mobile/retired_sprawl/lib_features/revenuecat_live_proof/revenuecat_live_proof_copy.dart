/// RevenueCat live proof copy — manual iOS sandbox purchase/restore evidence.
abstract final class RevenueCatLiveProofCopy {
  RevenueCatLiveProofCopy._();

  static const headline = 'RevenueCat live proof';

  static const body =
      'Purchase and restore are proven only after a real sandbox purchase, '
      'entitlement unlock, restart persistence, and restore check on device.';

  static const manualNote =
      'Steps 3–13 require a sandbox Apple ID on a physical iPhone or iPad.';

  static const guardrail = 'Do not treat automated tests as purchase proof.';

  static const statusPass = 'Pass';
  static const statusFail = 'Fail';
  static const statusPending = 'Pending';
  static const statusBlocked = 'Blocked';
  static const statusSkipped = 'Skipped';

  static const checkIosApiKeyPresent = 'REVENUECAT_IOS_API_KEY present';
  static const checkOfferingLoads = 'Offering loads';
  static const checkProductIdentifierMatches =
      'Product identifier matches App Store Connect';
  static const checkPriceVisible = 'Price visible';
  static const checkPaywallRouteOpens = 'Paywall route opens';
  static const checkPurchaseButtonEnabled = 'Purchase button enabled';
  static const checkStoreKitSheetAppears = 'StoreKit sheet appears';
  static const checkSandboxPurchaseSucceeds = 'Sandbox purchase succeeds';
  static const checkEntitlementActiveAfterPurchase =
      'Entitlement active after purchase';
  static const checkProGateUnlocks = 'Pro gate unlocks';
  static const checkAppRestartKeepsEntitlement =
      'App restart keeps entitlement';
  static const checkRestorePurchasesSucceeds = 'Restore purchases succeeds';
  static const checkRestoreAfterReinstallSucceeds =
      'Restore after reinstall succeeds';
  static const checkCalmFallbackOnFailure =
      'Missing product/failure shows calm fallback';
  static const checkNoCrash = 'No crash';

  static const detailPass = 'Verified';
  static const detailFail = 'Failed';
  static const detailPending = 'Run on physical device';
  static const detailBlocked = 'Blocked by earlier step';
  static const detailSkipped = 'Not required for this build';
  static const detailKeyMissing = 'Key not set at build time';
  static const detailKeyPresent = 'Key provided at build time';
  static const detailOfferingLoaded = 'Offering loaded';
  static const detailOfferingMissing = 'Offering not loaded';
  static const detailProductMatch = 'Product identifier matches store config';
  static const detailProductMismatch = 'Product identifier mismatch';
  static const detailPriceVisible = 'Price shown on paywall';
  static const detailPriceMissing = 'Price not visible';
  static const detailPaywallOpens = 'Paywall route reachable';
  static const detailPaywallBlocked = 'Paywall route not reachable';
  static const detailButtonEnabled = 'Purchase button enabled';
  static const detailButtonDisabled = 'Purchase button disabled';
  static const detailSheetSeen = 'StoreKit sheet appeared';
  static const detailSheetNotSeen = 'StoreKit sheet did not appear';
  static const detailPurchaseOk = 'Sandbox purchase completed';
  static const detailPurchaseFailed = 'Sandbox purchase failed';
  static const detailEntitlementOk = 'Pro entitlement active';
  static const detailEntitlementMissing = 'Pro entitlement not active';
  static const detailGateUnlocked = 'Gated Pro feature unlocked';
  static const detailGateLocked = 'Pro gate still locked';
  static const detailRestartOk = 'Pro still active after relaunch';
  static const detailRestartFailed = 'Pro lost after relaunch';
  static const detailRestoreOk = 'Restore purchases succeeded';
  static const detailRestoreFailed = 'Restore purchases failed';
  static const detailReinstallRestoreOk = 'Restore after reinstall succeeded';
  static const detailReinstallRestoreFailed = 'Restore after reinstall failed';
  static const detailFallbackOk = 'Calm fallback shown without crash';
  static const detailFallbackFailed = 'Missing product caused hard failure';
  static const detailNoCrashOk = 'App stayed usable';
  static const detailNoCrashFailed = 'Crash or hard failure observed';

  static const provedLine =
      'Live proof complete. Purchase, restore, entitlement, and restart verified.';

  static const manualRequiredLine =
      'Automated checks passed. Complete live sandbox steps on a physical device.';

  static const safeInternalStateLine =
      'Missing-key fallback verified. Add REVENUECAT_IOS_API_KEY for live proof.';

  static const blockedLine =
      'Live proof blocked. Fix the earliest failing check first.';

  static const scopeLine =
      'Live proof only. Do not change pricing, Pro promise, or Pro benefits.';

  static const List<String> canonicalChecklistOrder = [
    checkIosApiKeyPresent,
    checkOfferingLoads,
    checkProductIdentifierMatches,
    checkPriceVisible,
    checkPaywallRouteOpens,
    checkPurchaseButtonEnabled,
    checkStoreKitSheetAppears,
    checkSandboxPurchaseSucceeds,
    checkEntitlementActiveAfterPurchase,
    checkProGateUnlocks,
    checkAppRestartKeepsEntitlement,
    checkRestorePurchasesSucceeds,
    checkRestoreAfterReinstallSucceeds,
    checkCalmFallbackOnFailure,
    checkNoCrash,
  ];

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield body;
    yield manualNote;
    yield guardrail;
    yield scopeLine;
    yield statusPass;
    yield statusFail;
    yield statusPending;
    yield statusBlocked;
    yield statusSkipped;
    for (final label in canonicalChecklistOrder) {
      yield label;
    }
    yield detailPass;
    yield detailFail;
    yield detailPending;
    yield detailBlocked;
    yield detailSkipped;
    yield detailKeyMissing;
    yield detailKeyPresent;
    yield detailOfferingLoaded;
    yield detailOfferingMissing;
    yield detailProductMatch;
    yield detailProductMismatch;
    yield detailPriceVisible;
    yield detailPriceMissing;
    yield detailPaywallOpens;
    yield detailPaywallBlocked;
    yield detailButtonEnabled;
    yield detailButtonDisabled;
    yield detailSheetSeen;
    yield detailSheetNotSeen;
    yield detailPurchaseOk;
    yield detailPurchaseFailed;
    yield detailEntitlementOk;
    yield detailEntitlementMissing;
    yield detailGateUnlocked;
    yield detailGateLocked;
    yield detailRestartOk;
    yield detailRestartFailed;
    yield detailRestoreOk;
    yield detailRestoreFailed;
    yield detailReinstallRestoreOk;
    yield detailReinstallRestoreFailed;
    yield detailFallbackOk;
    yield detailFallbackFailed;
    yield detailNoCrashOk;
    yield detailNoCrashFailed;
    yield provedLine;
    yield manualRequiredLine;
    yield safeInternalStateLine;
    yield blockedLine;
  }
}

enum RevenueCatLiveProofCheckId {
  iosApiKeyPresent,
  offeringLoads,
  productIdentifierMatches,
  priceVisible,
  paywallRouteOpens,
  purchaseButtonEnabled,
  storeKitSheetAppears,
  sandboxPurchaseSucceeds,
  entitlementActiveAfterPurchase,
  proGateUnlocks,
  appRestartKeepsEntitlement,
  restorePurchasesSucceeds,
  restoreAfterReinstallSucceeds,
  calmFallbackOnFailure,
  noCrash,
}

enum RevenueCatLiveProofStatus {
  pass,
  fail,
  pending,
  blocked,
  skipped;

  String get label => switch (this) {
    RevenueCatLiveProofStatus.pass => RevenueCatLiveProofCopy.statusPass,
    RevenueCatLiveProofStatus.fail => RevenueCatLiveProofCopy.statusFail,
    RevenueCatLiveProofStatus.pending => RevenueCatLiveProofCopy.statusPending,
    RevenueCatLiveProofStatus.blocked => RevenueCatLiveProofCopy.statusBlocked,
    RevenueCatLiveProofStatus.skipped => RevenueCatLiveProofCopy.statusSkipped,
  };
}

enum RevenueCatLiveProofDecision {
  proved,
  manualRequired,
  safeInternalState,
  blocked,
}