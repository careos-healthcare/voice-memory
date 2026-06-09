import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/activation/activation_tracker.dart';
import '../features/activation/first_loop_activation_coordinator.dart';
import 'archive_entitlement_reader.dart';
import 'archive_pro_feature_map.dart';
import 'paywall_route_args.dart';
import 'paywall_trigger_engine.dart';
import 'paywall_trigger_model.dart';

/// Loads access state and opens the paywall when a Pro feature is gated.
abstract final class PaywallAccess {
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
    int checkInCount = 0,
    int weekCount = 0,
    String sourceRoute = '',
  }) async {
    final reader = entitlementReader ?? ArchiveEntitlementReader.forAccessCheck();
    final isPro = await reader.isPro;
    final loopClosed = firstLoopClosed ?? await isFirstLoopClosed();
    return buildPaywallTrigger(
      feature: feature,
      isPro: isPro,
      firstLoopClosed: loopClosed,
      momentCount: momentCount,
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
    int checkInCount = 0,
    int weekCount = 0,
    String sourceRoute = '',
  }) async {
    final trigger = await check(
      feature: feature,
      entitlementReader: entitlementReader,
      firstLoopClosed: firstLoopClosed,
      momentCount: momentCount,
      checkInCount: checkInCount,
      weekCount: weekCount,
      sourceRoute: sourceRoute,
    );
    if (trigger == null) return true;
    if (!context.mounted) return false;
    openPaywall(context, trigger);
    return false;
  }

  static void openPaywall(BuildContext context, PaywallTriggerContext trigger) {
    ActivationTracker.trackPaywallTriggerShown();
    context.push(
      '/subscription',
      extra: PaywallRouteArgs.fromContext(trigger),
    );
  }
}
