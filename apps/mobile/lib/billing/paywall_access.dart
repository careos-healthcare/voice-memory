import 'package:archiveme_mobile/billing/archive_entitlement_reader.dart';
import 'package:archiveme_mobile/billing/archive_pro_feature_map.dart';
import 'package:archiveme_mobile/billing/magic_moments_counter.dart';
import 'package:archiveme_mobile/billing/paywall_route_args.dart';
import 'package:archiveme_mobile/billing/paywall_trigger_engine.dart';
import 'package:archiveme_mobile/billing/paywall_trigger_model.dart';
import 'package:archiveme_mobile/config/screenshot_mode.dart';
import 'package:archiveme_mobile/core/config/v1_billing_capability.dart';
import 'package:archiveme_mobile/features/activation/activation_tracker.dart';
import 'package:archiveme_mobile/features/activation/first_loop_activation_coordinator.dart';
import 'package:archiveme_mobile/features/app_review/archive_app_review_session.dart';
import 'package:archiveme_mobile/features/pro_bridge_visibility/delayed_paywall_proof_store.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Loads access state and opens the paywall when a Pro feature is gated.
abstract class PaywallAccess {
  PaywallAccess._();

  static Future<bool> isFirstLoopClosed() async {
    final state = await FirstLoopActivationCoordinator.load();
    return state.isComplete;
  }

  static Future<PaywallTriggerContext?> check({
    required ArchiveFeature feature,
    ArchiveEntitlementReader? entitlementReader,
    bool? firstLoopClosed,
    int momentCount = 0,
    int magicMomentsCount = 0,
    int checkInCount = 0,
    int weekCount = 0,
    String sourceRoute = '',
  }) async {
    if (!V1BillingCapability.isProductionReachable) return null;
    final reader =
        entitlementReader ?? ArchiveEntitlementReader.forAccessCheck();
    final isPro = await reader.isPro;
    final loopClosed = firstLoopClosed ?? await isFirstLoopClosed();
    final resolvedMagicMoments = magicMomentsCount > 0
        ? magicMomentsCount
        : momentCount;
    return buildPaywallTrigger(
      feature: feature,
      isPro: isPro,
      firstLoopClosed: loopClosed,
      momentCount: momentCount,
      magicMomentsCount: resolvedMagicMoments,
      checkInCount: checkInCount,
      weekCount: weekCount,
      sourceRoute: sourceRoute,
    );
  }

  /// Returns true when access is allowed; otherwise opens paywall and returns false.
  static Future<bool> ensureAccess(
    BuildContext context, {
    required ArchiveFeature feature,
    ArchiveEntitlementReader? entitlementReader,
    bool? firstLoopClosed,
    int momentCount = 0,
    int magicMomentsCount = 0,
    int checkInCount = 0,
    int weekCount = 0,
    String sourceRoute = '',
  }) async {
    final trigger = await check(
      feature: feature,
      entitlementReader: entitlementReader,
      firstLoopClosed: firstLoopClosed,
      momentCount: momentCount,
      magicMomentsCount: magicMomentsCount,
      checkInCount: checkInCount,
      weekCount: weekCount,
      sourceRoute: sourceRoute,
    );
    if (trigger == null) return true;
    if (!context.mounted) return false;
    if (!await canOpenPaywall()) return false;
    if (!context.mounted) return false;
    await openPaywall(context, trigger);
    return false;
  }

  /// Paywall only after first repeat and evidence trail — same gate as Pro bridge.
  static Future<bool> canOpenPaywall() async {
    if (!V1BillingCapability.isProductionReachable) return false;
    if (ScreenshotMode.enabled) return true;
    if (ArchiveAppReviewSession.isActive) return true;
    await DelayedPaywallProofStore.ensureLoaded();
    return DelayedPaywallProofStore.passesGate;
  }

  static Future<void> openPaywall(
    BuildContext context,
    PaywallTriggerContext trigger,
  ) async {
    if (!await canOpenPaywall()) return;
    if (!context.mounted) return;
    ActivationTracker.trackPaywallTriggerShown();
    await context.push('/subscription', extra: PaywallRouteArgs.fromContext(trigger));
  }
}