import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/screenshot_mode.dart';
import '../features/app_review/archive_app_review_session.dart';
import '../features/activation/activation_tracker.dart';
import '../features/activation/first_loop_activation_coordinator.dart';
import '../features/pro_bridge_visibility/delayed_paywall_proof_store.dart';
import '../features/monetization/data/monetization_local_migration.dart';
import '../features/monetization/domain/access_policy_engine.dart';
import '../services/app_services.dart';
import '../subscriptions/domain/subscription_models.dart';
import 'archive_entitlement_reader.dart';
import 'paywall_route_args.dart';
import 'paywall_trigger_engine.dart';
import 'paywall_trigger_model.dart';

/// Loads access state and opens the paywall when a Pro feature is gated.
abstract class PaywallAccess {
  PaywallAccess._();

  static Future<bool> isFirstLoopClosed() async {
    final state = await FirstLoopActivationCoordinator.load();
    return state.isComplete;
  }

  static Future<PaywallTriggerContext?> check({
    required CapabilityId capability,
    ArchiveEntitlementReader? entitlementReader,
    ProductValueState? valueState,
    UsageSnapshot usage = const UsageSnapshot.serverAuthoritative(),
    bool explicitlyRequestedPro = false,
    int momentCount = 0,
    int checkInCount = 0,
    int weekCount = 0,
    String sourceRoute = '',
  }) async {
    final reader =
        entitlementReader ?? ArchiveEntitlementReader.forAccessCheck();
    final entitlement = await reader.entitlement;
    final value = valueState ?? await _loadProductValue();
    return buildPaywallTrigger(
      capability: capability,
      entitlement: entitlement,
      valueState: value,
      usage: usage,
      explicitlyRequestedPro: explicitlyRequestedPro,
      momentCount: momentCount,
      checkInCount: checkInCount,
      weekCount: weekCount,
      sourceRoute: sourceRoute,
    );
  }

  /// Returns true when access is allowed; otherwise opens paywall and returns false.
  static Future<bool> ensureAccess(
    BuildContext context, {
    required CapabilityId capability,
    ArchiveEntitlementReader? entitlementReader,
    ProductValueState? valueState,
    UsageSnapshot usage = const UsageSnapshot.serverAuthoritative(),
    bool explicitlyRequestedPro = false,
    int momentCount = 0,
    int checkInCount = 0,
    int weekCount = 0,
    String sourceRoute = '',
  }) async {
    final trigger = await check(
      capability: capability,
      entitlementReader: entitlementReader,
      valueState: valueState,
      usage: usage,
      explicitlyRequestedPro: explicitlyRequestedPro,
      momentCount: momentCount,
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

  /// Requires an active Pro entitlement even before the paywall timing gate.
  ///
  /// Free users are always denied the Pro action. The subscription screen is
  /// only opened once the proof-first paywall gate allows it.
  static Future<bool> ensureProAccess(
    BuildContext context, {
    required CapabilityId capability,
    ArchiveEntitlementReader? entitlementReader,
    int momentCount = 0,
    int checkInCount = 0,
    int weekCount = 0,
    String sourceRoute = '',
  }) async {
    final reader =
        entitlementReader ?? ArchiveEntitlementReader.forAccessCheck();
    final entitlement = await reader.entitlement;
    final decision = AccessPolicyEngine.decide(
      capability: capability,
      entitlement: entitlement,
      usage: const UsageSnapshot.serverAuthoritative(),
    );
    if (decision.allowed) return true;
    if (!context.mounted || !await canOpenPaywall()) return false;

    final trigger = buildPaywallTrigger(
      capability: capability,
      entitlement: entitlement,
      valueState: await _loadProductValue(),
      usage: const UsageSnapshot.serverAuthoritative(),
      explicitlyRequestedPro: true,
      momentCount: momentCount,
      checkInCount: checkInCount,
      weekCount: weekCount,
      sourceRoute: sourceRoute,
    );
    if (trigger == null || !context.mounted) return false;
    await openPaywall(context, trigger);
    return false;
  }

  /// Paywall only after first repeat and evidence trail — same gate as Pro bridge.
  static Future<bool> canOpenPaywall() async {
    if (ScreenshotMode.enabled) return true;
    if (ArchiveAppReviewSession.isActive) return true;
    await DelayedPaywallProofStore.ensureLoaded();
    return DelayedPaywallProofStore.passesGate;
  }

  static Future<ProductValueState> _loadProductValue() async {
    if (!AppServices.isInitialized) return const ProductValueState();
    final services = AppServices.instance;
    final subscription =
        services.subscriptionRepository.currentState ??
        await services.subscriptionRepository.loadCachedState() ??
        SubscriptionState.free();
    return (await MonetizationLocalMigration(
      services.prefs,
    ).run(subscription: subscription)).productValue;
  }

  static Future<void> openPaywall(
    BuildContext context,
    PaywallTriggerContext trigger,
  ) async {
    if (!await canOpenPaywall()) return;
    if (!context.mounted) return;
    ActivationTracker.trackPaywallTriggerShown();
    context.push('/subscription', extra: PaywallRouteArgs.fromContext(trigger));
  }
}
