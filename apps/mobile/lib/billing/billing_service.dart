import 'package:archiveme_mobile/features/billing/application/billing_notifier.dart';
import 'package:archiveme_mobile/features/recording/recording_dependencies.dart' show AppServices;
import 'package:archiveme_mobile/models/entitlement.dart';
import 'package:archiveme_mobile/services/app_services.dart' show AppServices;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Facade over [BillingNotifier] — preserves the legacy [AppServices.billing] surface.
class BillingService {
  BillingService(this._notifier);

  final BillingNotifier _notifier;

  /// When RevenueCat is configured and reports free, stale cached Pro must not win.
  static PremiumEntitlements mergeEntitlements({
    required PremiumEntitlements? server,
    required PremiumEntitlements store,
    required bool revenueCatConfigured,
  }) {
    if (store.isPro) return store;
    if (revenueCatConfigured && !store.isPro) return store;
    return server ?? store;
  }

  void startListening() => _notifier.startListening();

  void dispose() {}

  Future<PremiumEntitlements?> loadCachedEntitlements() =>
      _notifier.loadCachedEntitlements();

  Future<PremiumEntitlements> loadEntitlements({bool forceRefresh = false}) =>
      _notifier.loadEntitlements(forceRefresh: forceRefresh);

  Future<PremiumEntitlements> purchaseNative(Package package) =>
      _notifier.purchaseNative(package);

  Future<PremiumEntitlements> restoreNative() => _notifier.restoreNative();

  Future<void> resetCachedEntitlementsForAuthChange() =>
      _notifier.resetCachedEntitlementsForAuthChange();
}

BillingService createBillingServiceForTest({
  required ProviderContainer container,
}) {
  return BillingService(container.read(billingProvider.notifier));
}