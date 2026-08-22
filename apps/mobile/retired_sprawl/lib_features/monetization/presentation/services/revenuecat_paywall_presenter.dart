import 'package:archiveme_mobile/billing/paywall_access.dart';
import 'package:archiveme_mobile/billing/paywall_route_args.dart';
import 'package:archiveme_mobile/billing/revenuecat_diagnostics_log.dart';
import 'package:archiveme_mobile/billing/revenuecat_service.dart';
import 'package:archiveme_mobile/features/activation/activation_tracker.dart';
import 'package:archiveme_mobile/features/monetization/presentation/models/paywall_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart' as purchases_ui;

/// Presents the remotely managed RevenueCat paywall sheet.
class RevenueCatPaywallPresenter {
  const RevenueCatPaywallPresenter({
    this._revenueCatService,
    this._canOpenPaywall,
    this.presentPaywallOverride,
    this.presentPaywallIfNeededOverride,
    this.getCustomerInfoOverride,
    this.openFallbackRouteOverride,
  });

  final RevenueCatService? _revenueCatService;
  final Future<bool> Function()? _canOpenPaywall;

  RevenueCatService get _revenueCat =>
      _revenueCatService ?? RevenueCatService.instance;

  Future<bool> Function() get _canOpen =>
      _canOpenPaywall ?? PaywallAccess.canOpenPaywall;

  @visibleForTesting
  final Future<purchases_ui.PaywallResult> Function({
    Offering? offering,
    bool displayCloseButton,
  })?
  presentPaywallOverride;

  @visibleForTesting
  final Future<purchases_ui.PaywallResult> Function(
    String requiredEntitlementIdentifier, {
    Offering? offering,
    bool displayCloseButton,
  })?
  presentPaywallIfNeededOverride;

  @visibleForTesting
  final Future<CustomerInfo?> Function()? getCustomerInfoOverride;

  @visibleForTesting
  final Future<void> Function(BuildContext? context, PaywallRouteArgs? args)?
  openFallbackRouteOverride;

  /// Triggers the native RevenueCat paywall footer or sheet.
  ///
  /// Returns a [PaywallResult] indicating the ultimate outcome after native
  /// presentation and entitlement verification.
  Future<PaywallResult> triggerNativePaywallSheet({
    String? requiredEntitlementId,
    String? specificOfferingId,
    BuildContext? fallbackContext,
    PaywallRouteArgs? fallbackArgs,
  }) async {
    if (!await _canOpen()) {
      _logFallbackStrategy(
        reason: 'paywall_gate_closed',
        error: 'DelayedPaywallProofStore blocked native sheet',
      );
      await _openFallbackRoute(fallbackContext, fallbackArgs);
      return PaywallResult.fallbackRoute;
    }

    try {
      final offering = await _resolveOffering(specificOfferingId);
      ActivationTracker.trackPaywallTriggerShown();

      final nativeResult = presentPaywallOverride != null
          ? await presentPaywallOverride!(
              offering: offering,
              displayCloseButton: true,
            )
          : await purchases_ui.RevenueCatUI.presentPaywall(
              offering: offering,
              displayCloseButton: true,
            );

      if (nativeResult == purchases_ui.PaywallResult.error) {
        _logCriticalFailure(
          'Native paywall bridge returned error',
          nativeResult,
        );
        _logFallbackStrategy(
          reason: 'native_paywall_error',
          error: nativeResult.name,
        );
        await _openFallbackRoute(fallbackContext, fallbackArgs);
        return PaywallResult.fallbackRoute;
      }

      final customerInfo = await _fetchCustomerInfo();
      if (customerInfo != null &&
          _verifyEntitlement(requiredEntitlementId, customerInfo)) {
        if (nativeResult == purchases_ui.PaywallResult.restored) {
          return PaywallResult.restored;
        }
        return PaywallResult.purchased;
      }

      return _resolveUnverifiedOutcome(nativeResult);
    } on PlatformException catch (platformError, stackTrace) {
      _logCriticalFailure(
        'Platform error during native paywall presentation',
        platformError,
      );
      _logFallbackStrategy(
        reason: 'platform_exception',
        error: '${platformError.code}: ${platformError.message}',
      );
      await _openFallbackRoute(fallbackContext, fallbackArgs);
      return PaywallResult.failed;
    } catch (generalError, stackTrace) {
      _logCriticalFailure(
        'Unexpected anomaly during paywall execution pipeline',
        generalError,
      );
      _logFallbackStrategy(
        reason: 'unexpected_error',
        error: generalError.toString(),
      );
      await _openFallbackRoute(fallbackContext, fallbackArgs);
      return PaywallResult.failed;
    }
  }

  /// Conditionally displays the paywall sheet only if the active customer
  /// profile doesn't currently unlock the designated premium tier entitlement.
  Future<PaywallResult> presentIfNeeded(
    String requiredEntitlementId, {
    String? specificOfferingId,
    BuildContext? fallbackContext,
    PaywallRouteArgs? fallbackArgs,
  }) async {
    if (!await _canOpen()) {
      _logFallbackStrategy(
        reason: 'paywall_gate_closed',
        error: 'presentIfNeeded blocked before native sheet',
      );
      return PaywallResult.notPresented;
    }

    try {
      final offering = await _resolveOffering(specificOfferingId);
      ActivationTracker.trackPaywallTriggerShown();

      final nativeResult = presentPaywallIfNeededOverride != null
          ? await presentPaywallIfNeededOverride!(
              requiredEntitlementId,
              offering: offering,
              displayCloseButton: true,
            )
          : await purchases_ui.RevenueCatUI.presentPaywallIfNeeded(
              requiredEntitlementId,
              offering: offering,
              displayCloseButton: true,
            );

      if (nativeResult == purchases_ui.PaywallResult.notPresented) {
        return PaywallResult.notPresented;
      }

      if (nativeResult == purchases_ui.PaywallResult.error) {
        _logCriticalFailure(
          'Native presentIfNeeded bridge returned error',
          nativeResult,
        );
        _logFallbackStrategy(
          reason: 'native_paywall_if_needed_error',
          error: nativeResult.name,
        );
        await _openFallbackRoute(fallbackContext, fallbackArgs);
        return PaywallResult.fallbackRoute;
      }

      final customerInfo = await _fetchCustomerInfo();
      if (customerInfo != null &&
          _verifyEntitlement(requiredEntitlementId, customerInfo)) {
        if (nativeResult == purchases_ui.PaywallResult.restored) {
          return PaywallResult.restored;
        }
        return PaywallResult.purchased;
      }

      return _resolveUnverifiedOutcome(nativeResult);
    } on PlatformException catch (platformError, stackTrace) {
      _logCriticalFailure(
        'Platform error during presentIfNeeded pipeline',
        platformError,
      );
      _logFallbackStrategy(
        reason: 'present_if_needed_platform_exception',
        error: '${platformError.code}: ${platformError.message}',
      );
      return PaywallResult.failed;
    } catch (generalError, stackTrace) {
      _logCriticalFailure(
        'Unexpected anomaly during presentIfNeeded pipeline',
        generalError,
      );
      return PaywallResult.failed;
    }
  }

  /// Convenience wrapper for value-moment taps that need route fallback.
  Future<PaywallResult> present(
    BuildContext context, {
    required PaywallRouteArgs args,
    String? requiredEntitlementId,
    String? specificOfferingId,
  }) {
    return triggerNativePaywallSheet(
      requiredEntitlementId: requiredEntitlementId,
      specificOfferingId: specificOfferingId,
      fallbackContext: context,
      fallbackArgs: args,
    );
  }

  Future<Offering?> _resolveOffering(String? specificOfferingId) async {
    final offerings = await _revenueCat.fetchOfferings();
    if (offerings == null) return null;

    if (specificOfferingId == null || specificOfferingId.trim().isEmpty) {
      return offerings.current;
    }

    return offerings.getOffering(specificOfferingId) ?? offerings.current;
  }

  Future<CustomerInfo?> _fetchCustomerInfo() async {
    if (getCustomerInfoOverride != null) {
      return getCustomerInfoOverride!();
    }

    if (!_revenueCat.isConfigured) return null;

    try {
      return await Purchases.getCustomerInfo();
    } catch (error, stackTrace) {
      _logCriticalFailure('Customer info fetch failed after paywall', error);
      return null;
    }
  }

  bool _verifyEntitlement(String? requiredEntitlementId, CustomerInfo info) {
    RevenueCatDiagnosticsLog.entitlementsChecked(
      source: 'paywall_presenter',
      info: info,
    );

    if (requiredEntitlementId != null &&
        requiredEntitlementId.trim().isNotEmpty) {
      return info.entitlements.all[requiredEntitlementId]?.isActive ?? false;
    }

    return info.entitlements.active.isNotEmpty;
  }

  PaywallResult _resolveUnverifiedOutcome(
    purchases_ui.PaywallResult nativeResult,
  ) {
    switch (nativeResult) {
      case purchases_ui.PaywallResult.cancelled:
        return PaywallResult.cancelled;
      case purchases_ui.PaywallResult.notPresented:
        return PaywallResult.notPresented;
      case purchases_ui.PaywallResult.error:
        return PaywallResult.failed;
      case purchases_ui.PaywallResult.purchased:
      case purchases_ui.PaywallResult.restored:
        return PaywallResult.cancelled;
    }
  }

  Future<void> _openFallbackRoute(
    BuildContext? context,
    PaywallRouteArgs? args,
  ) async {
    if (openFallbackRouteOverride != null) {
      await openFallbackRouteOverride!(context, args);
      return;
    }

    if (context == null || !context.mounted || args == null) return;
    await context.push('/subscription', extra: args);
  }

  void _logCriticalFailure(String context, Object error) {
    RevenueCatDiagnosticsLog.paywallCriticalFailure(
      context: context,
      error: error,
    );
  }

  void _logFallbackStrategy({required String reason, String? error}) {
    RevenueCatDiagnosticsLog.paywallFallback(reason: reason, error: error);
  }
}