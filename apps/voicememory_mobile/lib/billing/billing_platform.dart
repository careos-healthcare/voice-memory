import 'package:purchases_flutter/purchases_flutter.dart';

import '../models/entitlement.dart';
import 'revenuecat_diagnostics.dart';

/// Provider-facing billing operations used by subscription infrastructure.
abstract interface class BillingPlatform {
  Future<void> initialize();

  bool get isConfigured;

  bool get apiKeyMissing;

  Stream<PremiumEntitlements> get entitlementStream;

  PremiumEntitlements get latestEntitlements;

  RevenueCatDiagnostics get diagnostics;

  Future<String?> getAppUserId();

  Future<Offerings?> fetchOfferings();

  Future<PremiumEntitlements> purchasePackage(Package package);

  Future<PremiumEntitlements> restorePurchases();

  Future<PremiumEntitlements> syncAndRefreshEntitlements();

  Future<PremiumEntitlements> refreshEntitlements();

  Future<void> logIn(String appUserId);

  Future<void> logOut();

  void dispose();
}
