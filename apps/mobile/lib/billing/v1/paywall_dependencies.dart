import 'dart:async';

import 'package:archiveme_mobile/billing/v1/paywall_controller.dart' show PaywallController;
import 'package:archiveme_mobile/models/entitlement.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Injectable dependencies for [PaywallController] — keeps the screen free of
/// direct service-locator access for billing operations.
abstract class PaywallDependencies {
  Duration get loadTimeout;

  bool get appServicesInitialized;

  bool isBillingReady();

  Future<void> initializeBilling();

  Future<Offerings?> fetchOfferings();

  Future<PremiumEntitlements> loadEntitlements({required bool forceRefresh});

  Future<PremiumEntitlements?> loadCachedEntitlements();

  Future<PremiumEntitlements> mergeReviewProEntitlements(
    PremiumEntitlements entitlements,
  );

  Future<PremiumEntitlements> purchasePackage(Package package);

  PremiumEntitlements get latestEntitlements;
}