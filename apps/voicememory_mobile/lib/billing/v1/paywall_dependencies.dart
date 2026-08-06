import 'dart:async';

import 'package:purchases_flutter/purchases_flutter.dart';

import '../../models/entitlement.dart';

/// Injectable dependencies for [PaywallController] — keeps the screen free of
/// direct service-locator access for billing operations.
abstract class PaywallDependencies {
  Duration get loadTimeout;

  bool get appServicesInitialized;

  bool isBillingReady();

  Future<void> initializeBilling();

  Future<Offerings?> fetchOfferings();

  Future<PremiumEntitlements> loadEntitlements({required bool forceRefresh});

  Future<PremiumEntitlements> mergeReviewProEntitlements(
    PremiumEntitlements entitlements,
  );

  Future<PremiumEntitlements> purchasePackage(Package package);

  PremiumEntitlements get latestEntitlements;
}
