import '../models/entitlement.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Minimal store-billing surface used by [BillingService] — testable via fakes.
abstract class StoreBillingPort {
  bool get isConfigured;

  Stream<PremiumEntitlements> get entitlementStream;

  Future<PremiumEntitlements> restorePurchases();

  Future<PremiumEntitlements> refreshEntitlements();

  Future<PremiumEntitlements> purchasePackage(Package package);
}
