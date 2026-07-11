/// RevenueCat sandbox proof copy — iOS purchase/restore/entitlement evidence.
abstract final class RevenueCatSandboxProofCopy {
  RevenueCatSandboxProofCopy._();

  static const headline = 'RevenueCat sandbox proof';

  static const body =
      'Prove iOS purchase, restore, and Pro entitlement on a physical device '
      'before TestFlight or App Store submission.';

  static const manualNote =
      'Steps 4–9 require a sandbox Apple ID on a physical iPad or iPhone.';

  static const statusPass = 'Pass';
  static const statusFail = 'Fail';
  static const statusPending = 'Pending';
  static const statusBlocked = 'Blocked';
  static const statusSkipped = 'Skipped';

  static const checkIosApiKeyPresent = 'REVENUECAT_IOS_API_KEY present';
  static const checkOfferingLoads = 'Offering loads';
  static const checkProductTitlePriceVisible = 'Product title and price visible';
  static const checkStoreKitSheetAppears = 'StoreKit purchase sheet appears';
  static const checkSandboxPurchaseSucceeds = 'Sandbox purchase succeeds';
  static const checkProEntitlementActive =
      'archive_loop_pro or pro entitlement active';
  static const checkProGateUnlocks = 'Pro gate unlocks';
  static const checkRestorePurchasesSucceeds = 'Restore purchases succeeds';
  static const checkEntitlementPersistsAfterRestart =
      'Entitlement persists after app restart';
  static const checkMissingKeyNoCrash =
      'Missing key does not crash release smoke';

  static const detailPass = 'Verified';
  static const detailFail = 'Failed';
  static const detailPending = 'Run on physical device';
  static const detailBlocked = 'Blocked by earlier step';
  static const detailSkipped = 'Not required for this build';
  static const detailKeyMissing = 'Key not set at build time';
  static const detailKeyPresent = 'Key provided at build time';
  static const detailOfferingLoaded = 'Offering loaded';
  static const detailOfferingMissing = 'Offering not loaded';
  static const detailProductVisible = 'Title and price shown on paywall';
  static const detailProductMissing = 'Product title or price missing';
  static const detailSheetSeen = 'StoreKit sheet appeared';
  static const detailSheetNotSeen = 'StoreKit sheet did not appear';
  static const detailPurchaseOk = 'Sandbox purchase completed';
  static const detailPurchaseFailed = 'Sandbox purchase failed';
  static const detailEntitlementOk = 'Pro entitlement active';
  static const detailEntitlementMissing = 'Pro entitlement not active';
  static const detailGateUnlocked = 'Gated Pro feature unlocked';
  static const detailGateLocked = 'Pro gate still locked';
  static const detailRestoreOk = 'Restore purchases succeeded';
  static const detailRestoreFailed = 'Restore purchases failed';
  static const detailPersistOk = 'Pro still active after relaunch';
  static const detailPersistFailed = 'Pro lost after relaunch';
  static const detailNoCrashOk = 'App stayed usable without API key';
  static const detailNoCrashFailed = 'Missing key caused crash or hard failure';

  static const provedLine =
      'Sandbox proof complete. Purchase, restore, and entitlement verified.';

  static const manualRequiredLine =
      'Automated checks passed. Complete sandbox steps on a physical device.';

  static const fallbackVerifiedLine =
      'Missing-key fallback verified. Add REVENUECAT_IOS_API_KEY for full proof.';

  static const blockedLine =
      'Sandbox proof blocked. Fix the earliest failing check first.';

  static const guardrail =
      'Sandbox proof must verify purchase and restore only. Do not change product '
      'promise, pricing copy, or Pro benefits.';

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield body;
    yield manualNote;
    yield statusPass;
    yield statusFail;
    yield statusPending;
    yield statusBlocked;
    yield statusSkipped;
    yield checkIosApiKeyPresent;
    yield checkOfferingLoads;
    yield checkProductTitlePriceVisible;
    yield checkStoreKitSheetAppears;
    yield checkSandboxPurchaseSucceeds;
    yield checkProEntitlementActive;
    yield checkProGateUnlocks;
    yield checkRestorePurchasesSucceeds;
    yield checkEntitlementPersistsAfterRestart;
    yield checkMissingKeyNoCrash;
    yield detailPass;
    yield detailFail;
    yield detailPending;
    yield detailBlocked;
    yield detailSkipped;
    yield detailKeyMissing;
    yield detailKeyPresent;
    yield detailOfferingLoaded;
    yield detailOfferingMissing;
    yield detailProductVisible;
    yield detailProductMissing;
    yield detailSheetSeen;
    yield detailSheetNotSeen;
    yield detailPurchaseOk;
    yield detailPurchaseFailed;
    yield detailEntitlementOk;
    yield detailEntitlementMissing;
    yield detailGateUnlocked;
    yield detailGateLocked;
    yield detailRestoreOk;
    yield detailRestoreFailed;
    yield detailPersistOk;
    yield detailPersistFailed;
    yield detailNoCrashOk;
    yield detailNoCrashFailed;
    yield provedLine;
    yield manualRequiredLine;
    yield fallbackVerifiedLine;
    yield blockedLine;
  }
}
