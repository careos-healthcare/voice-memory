import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';

/// Canonical focused-beta billing gate — registry capability plus build flag.
///
/// When [isEnabled] is false (focused beta default):
/// - No billing routes, CTAs, paywall gates, or paid-limit enforcement in production.
/// - RevenueCat SDK must not initialize or make network calls.
/// - Billing code remains in the repo for later commercial re-entry.
abstract final class V1BillingCapability {
  V1BillingCapability._();

  /// Compile-time capability from [V1CapabilityRegistry.storeBilling].
  static const bool registryEnabled = V1CapabilityRegistry.storeBilling;

  /// Optional build-time override (`REVENUECAT_PURCHASES_ENABLED`).
  ///
  /// Defaults to `false` so billing fails closed: enabling it requires an
  /// explicit `--dart-define`, even after [registryEnabled] flips true for
  /// commercial re-entry. On its own it can only narrow, never widen, billing.
  static const bool buildPurchasesFlag = bool.fromEnvironment(
    'REVENUECAT_PURCHASES_ENABLED',
    defaultValue: false,
  );

  /// Billing may initialize SDK, listen for entitlements, and accept purchases.
  static const bool isEnabled = registryEnabled && buildPurchasesFlag;

  /// Billing UI/routes/CTAs may appear in the production release graph.
  static const bool isProductionReachable = isEnabled;
}
