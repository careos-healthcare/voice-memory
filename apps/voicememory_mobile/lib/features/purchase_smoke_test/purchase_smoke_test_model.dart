import 'purchase_smoke_test_copy.dart';

enum PurchaseSmokeTestStatus {
  ready,
  warning,
  blocked,
  unknown;

  String get label => switch (this) {
        PurchaseSmokeTestStatus.ready => PurchaseSmokeTestCopy.statusReady,
        PurchaseSmokeTestStatus.warning => PurchaseSmokeTestCopy.statusWarning,
        PurchaseSmokeTestStatus.blocked => PurchaseSmokeTestCopy.statusBlocked,
        PurchaseSmokeTestStatus.unknown => PurchaseSmokeTestCopy.statusUnknown,
      };
}

enum PurchaseSmokeTestCheckId {
  billingConfigured,
  revenueCatInitialized,
  offeringsLoaded,
  currentOfferingExists,
  monthlyPackageFound,
  annualPackageFoundIfConfigured,
  paywallOpens,
  purchaseCtaVisible,
  restoreVisible,
  entitlementReadable,
  proUnlockReadable,
  lastPurchaseError,
}

class PurchaseSmokeTestCheck {
  const PurchaseSmokeTestCheck({
    required this.id,
    required this.label,
    required this.status,
    required this.detailLabel,
  });

  final PurchaseSmokeTestCheckId id;
  final String label;
  final PurchaseSmokeTestStatus status;
  final String detailLabel;
}

class PurchaseSmokeTestInput {
  const PurchaseSmokeTestInput({
    this.billingConfigured = false,
    this.revenueCatInitialized = false,
    this.offeringsLoaded = false,
    this.currentOfferingExists = false,
    this.hasMonthlyPackage = false,
    this.hasAnnualPackage = false,
    this.entitlementReadable = false,
    this.isPro = false,
    this.lastErrorSafe,
  });

  final bool billingConfigured;
  final bool revenueCatInitialized;
  final bool offeringsLoaded;
  final bool currentOfferingExists;
  final bool hasMonthlyPackage;
  final bool hasAnnualPackage;
  final bool entitlementReadable;
  final bool isPro;
  final String? lastErrorSafe;
}

class PurchaseSmokeTestSnapshot {
  const PurchaseSmokeTestSnapshot({
    required this.title,
    required this.body,
    required this.checks,
    required this.billingConfigured,
    required this.offeringsLoaded,
    required this.entitlementKnown,
    this.lastErrorSafe,
  });

  final String title;
  final String body;
  final List<PurchaseSmokeTestCheck> checks;
  final bool billingConfigured;
  final bool offeringsLoaded;
  final bool entitlementKnown;
  final String? lastErrorSafe;

  List<String> get allDisplayedText => [
        title,
        body,
        for (final check in checks) ...[
          check.label,
          check.detailLabel,
          check.status.label,
        ],
        if (lastErrorSafe != null) lastErrorSafe!,
        PurchaseSmokeTestCopy.localNote,
      ];
}
