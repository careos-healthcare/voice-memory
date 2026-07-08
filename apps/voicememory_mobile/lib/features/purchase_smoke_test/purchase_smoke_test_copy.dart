/// Copy for the purchase smoke test card — debug/testing only.
abstract final class PurchaseSmokeTestCopy {
  PurchaseSmokeTestCopy._();

  static const title = 'Purchase smoke test';
  static const body =
      'Use this before TestFlight to confirm Pro can be seen, bought, restored, and unlocked.';

  static const statusReady = 'Ready';
  static const statusWarning = 'Warning';
  static const statusBlocked = 'Blocked';
  static const statusUnknown = 'Unknown';

  static const refreshCta = 'Refresh checks';
  static const openPaywallCta = 'Open paywall smoke check';
  static const localNote =
      'Manual verification only. Does not purchase automatically.';

  static const checkBillingConfigured = 'Billing configured';
  static const checkRevenueCatInitialized = 'RevenueCat initialized';
  static const checkOfferingsLoaded = 'Offerings loaded';
  static const checkCurrentOfferingExists = 'Current offering exists';
  static const checkMonthlyPackageFound = 'Monthly package found';
  static const checkAnnualPackageFound = 'Annual package found if configured';
  static const checkPaywallOpens = 'Paywall opens';
  static const checkPurchaseCtaVisible = 'Purchase CTA visible';
  static const checkRestoreVisible = 'Restore purchases visible';
  static const checkEntitlementReadable = 'Current entitlement status readable';
  static const checkProUnlockReadable = 'Pro unlock state readable';
  static const checkLastPurchaseError = 'Last purchase error visible as safe debug text';

  static const detailNotCheckedYet = 'Not checked yet';
  static const detailConfigured = 'Configured';
  static const detailNotConfigured = 'Not configured';
  static const detailLoaded = 'Loaded';
  static const detailMissing = 'Missing';
  static const detailFound = 'Found';
  static const detailNotFound = 'Not found';
  static const detailAvailable = 'Available';
  static const detailUnavailable = 'Unavailable';
  static const detailReadable = 'Readable';
  static const detailNone = 'None';
  static const detailRouteReady = 'Route ready';
  static const detailAnnualOptionalMissing = 'Annual not in current offering';

  static const entitlementFree = 'Free';
  static const entitlementPro = 'Pro active';

  static Iterable<String> allVisibleStrings() sync* {
    yield title;
    yield body;
    yield statusReady;
    yield statusWarning;
    yield statusBlocked;
    yield statusUnknown;
    yield refreshCta;
    yield openPaywallCta;
    yield localNote;
    yield checkBillingConfigured;
    yield checkRevenueCatInitialized;
    yield checkOfferingsLoaded;
    yield checkCurrentOfferingExists;
    yield checkMonthlyPackageFound;
    yield checkAnnualPackageFound;
    yield checkPaywallOpens;
    yield checkPurchaseCtaVisible;
    yield checkRestoreVisible;
    yield checkEntitlementReadable;
    yield checkProUnlockReadable;
    yield checkLastPurchaseError;
    yield detailNotCheckedYet;
    yield detailConfigured;
    yield detailNotConfigured;
    yield detailLoaded;
    yield detailMissing;
    yield detailFound;
    yield detailNotFound;
    yield detailAvailable;
    yield detailUnavailable;
    yield detailReadable;
    yield detailNone;
    yield detailRouteReady;
    yield detailAnnualOptionalMissing;
    yield entitlementFree;
    yield entitlementPro;
  }
}
