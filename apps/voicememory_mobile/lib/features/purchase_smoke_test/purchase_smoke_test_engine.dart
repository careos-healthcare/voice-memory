import 'package:flutter/foundation.dart';

import '../../billing/archive_paywall_plans.dart';
import '../../billing/revenuecat_service.dart';
import '../../product/consumer_ui_copy.dart';
import '../../services/activation_funnel_analytics.dart';
import '../../services/app_services.dart';
import 'purchase_smoke_test_copy.dart';
import 'purchase_smoke_test_model.dart';

/// Metadata-only analytics for purchase smoke test.
abstract final class PurchaseSmokeTestAnalytics {
  PurchaseSmokeTestAnalytics._();

  static const openedEvent = 'purchase_smoke_test_opened';
  static const paywallOpenedEvent = 'purchase_smoke_test_paywall_opened';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
      captureForTest;

  static void opened({
    required String source,
    required bool billingConfigured,
    required bool offeringsLoaded,
    required bool entitlementKnown,
  }) {
    _emit(
      openedEvent,
      source: source,
      billingConfigured: billingConfigured,
      offeringsLoaded: offeringsLoaded,
      entitlementKnown: entitlementKnown,
    );
  }

  static void paywallOpened({
    required String source,
    required bool billingConfigured,
    required bool offeringsLoaded,
    required bool entitlementKnown,
  }) {
    _emit(
      paywallOpenedEvent,
      source: source,
      billingConfigured: billingConfigured,
      offeringsLoaded: offeringsLoaded,
      entitlementKnown: entitlementKnown,
    );
  }

  static void _emit(
    String event, {
    required String source,
    required bool billingConfigured,
    required bool offeringsLoaded,
    required bool entitlementKnown,
  }) {
    final props = <String, Object>{
      'source': source,
      'billing_configured': billingConfigured ? 1 : 0,
      'offerings_loaded': offeringsLoaded ? 1 : 0,
      'entitlement_known': entitlementKnown ? 1 : 0,
    };
    captureForTest?.call(event, props);
    ActivationFunnelAnalytics.track(
      event,
      source: source,
    );
    if (kDebugMode) {
      debugPrint(
        'ARCHIVEME_PURCHASE_SMOKE_TEST event=$event source=$source '
        'billing_configured=${props['billing_configured']} '
        'offerings_loaded=${props['offerings_loaded']} '
        'entitlement_known=${props['entitlement_known']}',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}

/// Read-only purchase verification checks for beta/TestFlight readiness.
abstract final class PurchaseSmokeTestEngine {
  PurchaseSmokeTestEngine._();

  static final _secretPattern = RegExp(
    r'(sk_[a-z0-9]+|appl_[a-z0-9]+|goog_[a-z0-9]+|'
    r'revenuecat_[a-z0-9_]*api[a-z0-9_]*|api[_-]?key|secret)',
    caseSensitive: false,
  );

  static bool shouldShow({required bool betaMissionEnabled}) =>
      betaMissionEnabled;

  static Future<PurchaseSmokeTestSnapshot> build() async {
    if (!AppServices.isInitialized) {
      return buildFromInput(const PurchaseSmokeTestInput());
    }

    final rc = RevenueCatService.instance;
    await rc.initialize();
    final diagnostics = rc.diagnostics;
    final offerings = await rc.fetchOfferings();
    final packages = offerings?.current?.availablePackages ?? const [];
    final entitlements = await AppServices.instance.billing.loadEntitlements(
      forceRefresh: false,
    );

    return buildFromInput(
      PurchaseSmokeTestInput(
        billingConfigured:
            diagnostics.revenueCatConfigured && !diagnostics.apiKeyMissing,
        revenueCatInitialized: rc.isConfigured,
        offeringsLoaded: diagnostics.offeringsLoaded,
        currentOfferingExists: diagnostics.currentOfferingId != null,
        hasMonthlyPackage: packageListHasMonthly(packages),
        hasAnnualPackage: packageListHasAnnual(packages),
        entitlementReadable: true,
        isPro: entitlements.isPro,
        lastErrorSafe: sanitizeDebugText(diagnostics.lastRevenueCatError),
      ),
    );
  }

  static PurchaseSmokeTestSnapshot buildFromInput(PurchaseSmokeTestInput input) {
    final checks = _buildChecks(input);
    return PurchaseSmokeTestSnapshot(
      title: PurchaseSmokeTestCopy.title,
      body: PurchaseSmokeTestCopy.body,
      checks: checks,
      billingConfigured: input.billingConfigured,
      offeringsLoaded: input.offeringsLoaded,
      entitlementKnown: input.entitlementReadable,
      lastErrorSafe: input.lastErrorSafe,
    );
  }

  static List<PurchaseSmokeTestCheck> _buildChecks(PurchaseSmokeTestInput input) {
    final paywallReady = input.billingConfigured && input.revenueCatInitialized;
    final purchaseCtaReady =
        paywallReady && input.offeringsLoaded && input.hasMonthlyPackage;
    final restoreVisible = paywallReady &&
        ConsumerUiCopy.restorePurchases.trim().isNotEmpty;

    return [
      _check(
        id: PurchaseSmokeTestCheckId.billingConfigured,
        label: PurchaseSmokeTestCopy.checkBillingConfigured,
        status: input.billingConfigured
            ? PurchaseSmokeTestStatus.ready
            : PurchaseSmokeTestStatus.blocked,
        detailLabel: input.billingConfigured
            ? PurchaseSmokeTestCopy.detailConfigured
            : PurchaseSmokeTestCopy.detailNotConfigured,
      ),
      _check(
        id: PurchaseSmokeTestCheckId.revenueCatInitialized,
        label: PurchaseSmokeTestCopy.checkRevenueCatInitialized,
        status: input.revenueCatInitialized
            ? PurchaseSmokeTestStatus.ready
            : input.billingConfigured
                ? PurchaseSmokeTestStatus.blocked
                : PurchaseSmokeTestStatus.unknown,
        detailLabel: input.revenueCatInitialized
            ? PurchaseSmokeTestCopy.detailConfigured
            : PurchaseSmokeTestCopy.detailNotConfigured,
      ),
      _check(
        id: PurchaseSmokeTestCheckId.offeringsLoaded,
        label: PurchaseSmokeTestCopy.checkOfferingsLoaded,
        status: !input.revenueCatInitialized
            ? PurchaseSmokeTestStatus.unknown
            : input.offeringsLoaded
                ? PurchaseSmokeTestStatus.ready
                : PurchaseSmokeTestStatus.blocked,
        detailLabel: input.offeringsLoaded
            ? PurchaseSmokeTestCopy.detailLoaded
            : PurchaseSmokeTestCopy.detailMissing,
      ),
      _check(
        id: PurchaseSmokeTestCheckId.currentOfferingExists,
        label: PurchaseSmokeTestCopy.checkCurrentOfferingExists,
        status: !input.offeringsLoaded
            ? PurchaseSmokeTestStatus.unknown
            : input.currentOfferingExists
                ? PurchaseSmokeTestStatus.ready
                : PurchaseSmokeTestStatus.blocked,
        detailLabel: input.currentOfferingExists
            ? PurchaseSmokeTestCopy.detailFound
            : PurchaseSmokeTestCopy.detailNotFound,
      ),
      _check(
        id: PurchaseSmokeTestCheckId.monthlyPackageFound,
        label: PurchaseSmokeTestCopy.checkMonthlyPackageFound,
        status: !input.currentOfferingExists
            ? PurchaseSmokeTestStatus.unknown
            : input.hasMonthlyPackage
                ? PurchaseSmokeTestStatus.ready
                : PurchaseSmokeTestStatus.blocked,
        detailLabel: input.hasMonthlyPackage
            ? PurchaseSmokeTestCopy.detailFound
            : PurchaseSmokeTestCopy.detailNotFound,
      ),
      _check(
        id: PurchaseSmokeTestCheckId.annualPackageFoundIfConfigured,
        label: PurchaseSmokeTestCopy.checkAnnualPackageFound,
        status: !input.currentOfferingExists
            ? PurchaseSmokeTestStatus.unknown
            : input.hasAnnualPackage
                ? PurchaseSmokeTestStatus.ready
                : PurchaseSmokeTestStatus.warning,
        detailLabel: input.hasAnnualPackage
            ? PurchaseSmokeTestCopy.detailFound
            : PurchaseSmokeTestCopy.detailAnnualOptionalMissing,
      ),
      _check(
        id: PurchaseSmokeTestCheckId.paywallOpens,
        label: PurchaseSmokeTestCopy.checkPaywallOpens,
        status: paywallReady
            ? PurchaseSmokeTestStatus.ready
            : PurchaseSmokeTestStatus.blocked,
        detailLabel: paywallReady
            ? PurchaseSmokeTestCopy.detailRouteReady
            : PurchaseSmokeTestCopy.detailUnavailable,
      ),
      _check(
        id: PurchaseSmokeTestCheckId.purchaseCtaVisible,
        label: PurchaseSmokeTestCopy.checkPurchaseCtaVisible,
        status: purchaseCtaReady
            ? PurchaseSmokeTestStatus.ready
            : paywallReady
                ? PurchaseSmokeTestStatus.warning
                : PurchaseSmokeTestStatus.blocked,
        detailLabel: purchaseCtaReady
            ? PurchaseSmokeTestCopy.detailAvailable
            : PurchaseSmokeTestCopy.detailUnavailable,
      ),
      _check(
        id: PurchaseSmokeTestCheckId.restoreVisible,
        label: PurchaseSmokeTestCopy.checkRestoreVisible,
        status: restoreVisible
            ? PurchaseSmokeTestStatus.ready
            : PurchaseSmokeTestStatus.blocked,
        detailLabel: restoreVisible
            ? PurchaseSmokeTestCopy.detailAvailable
            : PurchaseSmokeTestCopy.detailUnavailable,
      ),
      _check(
        id: PurchaseSmokeTestCheckId.entitlementReadable,
        label: PurchaseSmokeTestCopy.checkEntitlementReadable,
        status: input.entitlementReadable
            ? PurchaseSmokeTestStatus.ready
            : PurchaseSmokeTestStatus.unknown,
        detailLabel: input.entitlementReadable
            ? PurchaseSmokeTestCopy.detailReadable
            : PurchaseSmokeTestCopy.detailNotCheckedYet,
      ),
      _check(
        id: PurchaseSmokeTestCheckId.proUnlockReadable,
        label: PurchaseSmokeTestCopy.checkProUnlockReadable,
        status: input.entitlementReadable
            ? PurchaseSmokeTestStatus.ready
            : PurchaseSmokeTestStatus.unknown,
        detailLabel: input.entitlementReadable
            ? (input.isPro
                ? PurchaseSmokeTestCopy.entitlementPro
                : PurchaseSmokeTestCopy.entitlementFree)
            : PurchaseSmokeTestCopy.detailNotCheckedYet,
      ),
      _check(
        id: PurchaseSmokeTestCheckId.lastPurchaseError,
        label: PurchaseSmokeTestCopy.checkLastPurchaseError,
        status: input.lastErrorSafe == null
            ? PurchaseSmokeTestStatus.ready
            : PurchaseSmokeTestStatus.warning,
        detailLabel: input.lastErrorSafe ?? PurchaseSmokeTestCopy.detailNone,
      ),
    ];
  }

  static PurchaseSmokeTestCheck _check({
    required PurchaseSmokeTestCheckId id,
    required String label,
    required PurchaseSmokeTestStatus status,
    required String detailLabel,
  }) {
    return PurchaseSmokeTestCheck(
      id: id,
      label: label,
      status: status,
      detailLabel: detailLabel,
    );
  }

  static String? sanitizeDebugText(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    var safe = trimmed.replaceAll(_secretPattern, '[redacted]');
    if (safe.length > 160) {
      safe = '${safe.substring(0, 159).trim()}…';
    }
    if (safe.toLowerCase().contains('[redacted]') &&
        safe.replaceAll('[redacted]', '').trim().isEmpty) {
      return 'Billing error recorded';
    }
    return safe;
  }
}
