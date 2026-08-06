import 'dart:async';

import 'package:purchases_flutter/purchases_flutter.dart';

import '../../billing/revenuecat_diagnostics_log.dart';
import '../../billing/revenuecat_offerings_debug_log.dart';
import '../../billing/subscription_copy.dart';
import '../../config/screenshot_mode.dart';
import '../../models/entitlement.dart';
import '../../product/consumer_ui_copy.dart';
import 'paywall_dependencies.dart';
import 'paywall_plan.dart';

/// Result of a paywall offerings + entitlement load pass.
class PaywallLoadResult {
  const PaywallLoadResult({
    required this.offerings,
    required this.entitlements,
    required this.selectedPlan,
    required this.billingConfigured,
    this.errorMessage,
    required this.unavailable,
    required this.loadReason,
  });

  final Offerings? offerings;
  final PremiumEntitlements entitlements;
  final PaywallPlan selectedPlan;
  final bool billingConfigured;
  final String? errorMessage;
  final bool unavailable;
  final String loadReason;

  bool get hasPackages {
    final packages = offerings?.current?.availablePackages;
    return packages != null && packages.isNotEmpty;
  }

  bool get purchasePlansAvailable => billingConfigured && hasPackages;
}

/// Loads RevenueCat offerings and refreshes entitlements — no widget code.
class PaywallOfferingsLoader {
  PaywallOfferingsLoader({required PaywallDependencies dependencies})
    : _deps = dependencies;

  final PaywallDependencies _deps;

  Package? packageFor(PaywallPlan plan, Offerings? offerings) {
    final current = offerings?.current;
    if (current == null) return null;
    for (final package in current.availablePackages) {
      if (plan == PaywallPlan.monthly &&
          package.packageType == PackageType.monthly) {
        return package;
      }
      if (plan == PaywallPlan.yearly &&
          package.packageType == PackageType.annual) {
        return package;
      }
    }
    return null;
  }

  bool hasPackagesIn(Offerings? offerings) {
    final packages = offerings?.current?.availablePackages;
    return packages != null && packages.isNotEmpty;
  }

  Future<PaywallLoadResult> load({
    required PaywallPlan currentPlan,
    bool isRetry = false,
  }) async {
    final timeout = _deps.loadTimeout;
    Offerings? offerings;
    var entitlements = PremiumEntitlements.free();
    String? error;
    var loadReason = 'completed';
    var billingConfigured = _deps.isBillingReady();
    var selected = currentPlan;
    var unavailable = false;

    RevenueCatOfferingsDebugLog.paywallLoadStarted(
      billingConfigured: billingConfigured,
      appServicesInitialized: _deps.appServicesInitialized,
      screenshotMode: ScreenshotMode.enabled,
    );

    try {
      if (!billingConfigured && !ScreenshotMode.enabled) {
        if (_deps.appServicesInitialized) {
          try {
            await _deps.initializeBilling().timeout(timeout);
          } on TimeoutException {
            loadReason = 'configure_timeout';
            RevenueCatDiagnosticsLog.paywallFallback(
              reason: loadReason,
              isRetry: isRetry,
            );
          }
          billingConfigured = _deps.isBillingReady();
        }
        if (!billingConfigured) {
          loadReason = 'billing_not_configured';
          RevenueCatOfferingsDebugLog.paywallLoadEarlyExit(reason: loadReason);
          entitlements = PremiumEntitlements.free();
          error = ConsumerUiCopy.paywallBillingNotConfigured;
          unavailable = true;
          return PaywallLoadResult(
            offerings: offerings,
            entitlements: entitlements,
            selectedPlan: selected,
            billingConfigured: billingConfigured,
            errorMessage: error,
            unavailable: unavailable,
            loadReason: loadReason,
          );
        }
      }

      if (ScreenshotMode.enabled) {
        loadReason = 'screenshot_mode';
        RevenueCatOfferingsDebugLog.paywallLoadEarlyExit(reason: loadReason);
        return PaywallLoadResult(
          offerings: null,
          entitlements: PremiumEntitlements.free(),
          selectedPlan: selected,
          billingConfigured: billingConfigured,
          unavailable: false,
          loadReason: loadReason,
        );
      }

      try {
        offerings = await _deps.fetchOfferings().timeout(
          timeout,
          onTimeout: () {
            RevenueCatOfferingsDebugLog.fetchOfferingsFinished(
              offerings: null,
              error: 'paywall_fetchOfferings_timeout_${timeout.inSeconds}s',
            );
            RevenueCatDiagnosticsLog.fetchOfferingsFinished(
              success: false,
              offerings: null,
              error: 'paywall_fetchOfferings_timeout_${timeout.inSeconds}s',
            );
            return null;
          },
        );
        entitlements = await _deps
            .loadEntitlements(forceRefresh: true)
            .timeout(timeout, onTimeout: () => PremiumEntitlements.free());
        entitlements = await _deps.mergeReviewProEntitlements(entitlements);
      } on TimeoutException {
        loadReason = 'load_timeout';
        error = SubscriptionCopy.paywallNoOfferings;
        entitlements = _deps.latestEntitlements;
        RevenueCatOfferingsDebugLog.paywallLoadEarlyExit(reason: loadReason);
        RevenueCatDiagnosticsLog.paywallFallback(
          reason: loadReason,
          error: error,
          isRetry: isRetry,
        );
      } catch (e) {
        loadReason = 'load_error';
        error = SubscriptionCopy.paywallNoOfferings;
        entitlements = _deps.latestEntitlements;
        RevenueCatOfferingsDebugLog.paywallLoadEarlyExit(reason: loadReason);
        RevenueCatDiagnosticsLog.paywallFallback(
          reason: loadReason,
          error: error,
          isRetry: isRetry,
        );
      }

      final monthly = packageFor(PaywallPlan.monthly, offerings);
      final yearly = packageFor(PaywallPlan.yearly, offerings);
      if (yearly == null && monthly != null) {
        selected = PaywallPlan.monthly;
      } else if (yearly != null) {
        selected = PaywallPlan.yearly;
      }

      if (!hasPackagesIn(offerings) && error == null) {
        loadReason = 'no_packages_in_current_offering';
        error = SubscriptionCopy.paywallNoOfferings;
        unavailable = true;
        RevenueCatDiagnosticsLog.paywallFallback(
          reason: loadReason,
          error: error,
          isRetry: isRetry,
        );
      } else if (hasPackagesIn(offerings)) {
        loadReason = 'plans_available';
        unavailable = false;
      } else {
        unavailable = !entitlements.isPro;
      }

      final purchasePlansAvailable =
          billingConfigured && hasPackagesIn(offerings);
      RevenueCatOfferingsDebugLog.paywallLoadResult(
        billingConfigured: billingConfigured,
        offeringsLoaded: offerings != null,
        offeringCount: offerings?.all.length ?? 0,
        currentOfferingId: offerings?.current?.identifier,
        packageCount: offerings?.current?.availablePackages.length ?? 0,
        monthlyPackageFound: monthly != null,
        annualPackageFound: yearly != null,
        purchasePlansAvailable: purchasePlansAvailable,
        showingUnavailable:
            !purchasePlansAvailable && entitlements.isPro != true,
        reason: loadReason,
        error: error,
      );
      if (!purchasePlansAvailable && entitlements.isPro != true) {
        RevenueCatDiagnosticsLog.paywallFallback(
          reason: loadReason,
          error: error,
          isRetry: isRetry,
        );
      }

      return PaywallLoadResult(
        offerings: offerings,
        entitlements: entitlements,
        selectedPlan: selected,
        billingConfigured: billingConfigured,
        errorMessage: error,
        unavailable: unavailable || !purchasePlansAvailable,
        loadReason: loadReason,
      );
    } catch (e) {
      loadReason = 'load_unhandled_error';
      error = SubscriptionCopy.paywallNoOfferings;
      RevenueCatDiagnosticsLog.paywallFallback(
        reason: loadReason,
        error: error,
        isRetry: isRetry,
      );
      return PaywallLoadResult(
        offerings: offerings,
        entitlements: entitlements,
        selectedPlan: selected,
        billingConfigured: billingConfigured,
        errorMessage: error,
        unavailable: true,
        loadReason: loadReason,
      );
    }
  }
}
