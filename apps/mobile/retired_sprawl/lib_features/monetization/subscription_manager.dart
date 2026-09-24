import 'package:archiveme_mobile/billing/store_billing_port.dart';
import 'package:archiveme_mobile/features/monetization/output_format_gate.dart';
import 'package:archiveme_mobile/models/entitlement.dart';
import 'package:archiveme_mobile/storage/entitlement_cache.dart';
import 'package:flutter/widgets.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Store subscriptions through `purchases_flutter`.
///
/// Entitlements come from the already configured RevenueCat client. This
/// class does not call [Purchases.configure], and it does not call the Stripe
/// checkout or webhook routes.
class SubscriptionManager {
  SubscriptionManager({
    required StoreBillingPort store,
    required EntitlementCache cache,
    this.presentPaywallOverride,
  }) : _store = store,
       _cache = cache;

  final StoreBillingPort _store;
  final EntitlementCache _cache;

  final Future<void> Function(BuildContext context)? presentPaywallOverride;

  /// Reads the store receipt. A missing RevenueCat key leaves the user free
  /// and does not fall back to a webhook-fed server entitlement.
  Future<PremiumEntitlements> refresh({
    bool force = false,
    PremiumEntitlements? memory,
  }) async {
    if (!force && memory != null) return memory;
    if (!_store.isConfigured) return PremiumEntitlements.free();
    final live = await _store.refreshEntitlements();
    await _remember(live);
    return live;
  }

  Future<PremiumEntitlements?> readCache() => _cache.load();

  Future<PremiumEntitlements> purchase(Package package) async {
    final entitlements = await _store.purchasePackage(package);
    await _remember(entitlements);
    return entitlements;
  }

  Future<PremiumEntitlements> restore() async {
    final entitlements = await _store.restorePurchases();
    await _remember(entitlements);
    return entitlements;
  }

  Future<void> presentPaywall(BuildContext context) {
    final override = presentPaywallOverride;
    if (override != null) return override(context);
    return OutputFormatGate.presentPaywall(context);
  }

  Future<void> _remember(PremiumEntitlements entitlements) async {
    if (entitlements.isPro) {
      await _cache.save(entitlements);
      return;
    }
    if (_store.isConfigured) {
      await _cache.clear();
    }
  }
}
