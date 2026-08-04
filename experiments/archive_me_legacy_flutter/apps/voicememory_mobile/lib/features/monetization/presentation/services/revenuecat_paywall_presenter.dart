import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart' as purchases_ui;

import '../../../../billing/paywall_access.dart';
import '../../../../billing/paywall_route_args.dart';
import '../../../../billing/revenuecat_diagnostics_log.dart';
import '../../../../features/activation/activation_tracker.dart';
import '../../../../services/app_services.dart';
import '../../../../subscriptions/domain/subscription_repository.dart';
import '../models/paywall_result.dart';

/// Presents the remotely managed RevenueCat paywall sheet.
class RevenueCatPaywallPresenter {
  const RevenueCatPaywallPresenter({
    this.subscriptionRepository,
    this.canOpenPaywall,
    this.presentPaywallOverride,
    this.presentPaywallIfNeededOverride,
    this.openFallbackRouteOverride,
  });

  final SubscriptionRepository? subscriptionRepository;
  final Future<bool> Function()? canOpenPaywall;

  SubscriptionRepository get _repository =>
      subscriptionRepository ?? AppServices.instance.subscriptionRepository;

  Future<bool> Function() get _canOpen =>
      canOpenPaywall ?? PaywallAccess.canOpenPaywall;

  @visibleForTesting
  final Future<purchases_ui.PaywallResult> Function({bool displayCloseButton})?
  presentPaywallOverride;

  final Future<purchases_ui.PaywallResult> Function({bool displayCloseButton})?
  presentPaywallIfNeededOverride;

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
    final openFallbackRoute = _fallbackRouteOpener(
      fallbackContext,
      fallbackArgs,
    );
    if (!await _canOpen()) {
      _logFallbackStrategy(
        reason: 'paywall_gate_closed',
        error: 'DelayedPaywallProofStore blocked native sheet',
      );
      await openFallbackRoute();
      return PaywallResult.fallbackRoute;
    }

    try {
      ActivationTracker.trackPaywallTriggerShown();

      final nativeResult = presentPaywallOverride != null
          ? await presentPaywallOverride!(displayCloseButton: true)
          : await purchases_ui.RevenueCatUI.presentPaywall(
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
        await openFallbackRoute();
        return PaywallResult.fallbackRoute;
      }

      if (nativeResult == purchases_ui.PaywallResult.purchased ||
          nativeResult == purchases_ui.PaywallResult.restored) {
        final state = await _repository.refresh(force: true);
        if (!state.isPro) return PaywallResult.failed;
        return nativeResult == purchases_ui.PaywallResult.restored
            ? PaywallResult.restored
            : PaywallResult.purchased;
      }

      return _resolveUnverifiedOutcome(nativeResult);
    } on PlatformException catch (platformError) {
      _logCriticalFailure(
        'Platform error during native paywall presentation',
        platformError,
      );
      _logFallbackStrategy(
        reason: 'platform_exception',
        error: '${platformError.code}: ${platformError.message}',
      );
      await openFallbackRoute();
      return PaywallResult.failed;
    } catch (generalError) {
      _logCriticalFailure(
        'Unexpected anomaly during paywall execution pipeline',
        generalError,
      );
      _logFallbackStrategy(
        reason: 'unexpected_error',
        error: generalError.toString(),
      );
      await openFallbackRoute();
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
    final openFallbackRoute = _fallbackRouteOpener(
      fallbackContext,
      fallbackArgs,
    );
    if (!await _canOpen()) {
      _logFallbackStrategy(
        reason: 'paywall_gate_closed',
        error: 'presentIfNeeded blocked before native sheet',
      );
      return PaywallResult.notPresented;
    }

    try {
      final before = await _repository.refresh();
      if (before.isPro) return PaywallResult.notPresented;
      ActivationTracker.trackPaywallTriggerShown();

      final nativeResult = presentPaywallIfNeededOverride != null
          ? await presentPaywallIfNeededOverride!(displayCloseButton: true)
          : await purchases_ui.RevenueCatUI.presentPaywall(
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
        await openFallbackRoute();
        return PaywallResult.fallbackRoute;
      }

      if (nativeResult == purchases_ui.PaywallResult.purchased ||
          nativeResult == purchases_ui.PaywallResult.restored) {
        final state = await _repository.refresh(force: true);
        if (!state.isPro) return PaywallResult.failed;
        return nativeResult == purchases_ui.PaywallResult.restored
            ? PaywallResult.restored
            : PaywallResult.purchased;
      }

      return _resolveUnverifiedOutcome(nativeResult);
    } on PlatformException catch (platformError) {
      _logCriticalFailure(
        'Platform error during presentIfNeeded pipeline',
        platformError,
      );
      _logFallbackStrategy(
        reason: 'present_if_needed_platform_exception',
        error: '${platformError.code}: ${platformError.message}',
      );
      return PaywallResult.failed;
    } catch (generalError) {
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
        // The store completed an action, but entitlement verification did not.
        // Treating this as cancellation hides a receipt/propagation problem.
        return PaywallResult.failed;
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
    context.push('/subscription', extra: args);
  }

  Future<void> Function() _fallbackRouteOpener(
    BuildContext? context,
    PaywallRouteArgs? args,
  ) {
    return () {
      if (context != null && !context.mounted) return Future<void>.value();
      return _openFallbackRoute(context, args);
    };
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
