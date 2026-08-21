import 'package:archiveme_mobile/billing/archive_loop_entitlement_ids.dart';
import 'package:archiveme_mobile/billing/revenuecat_configuration.dart';
import 'package:archiveme_mobile/billing/revenuecat_service.dart';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Per-seat professional / coach tier billing gate.
abstract final class ProfessionalCoachEntitlementGate {
  ProfessionalCoachEntitlementGate._();

  static const paywallFeatureName = 'Professional coach dashboard';

  /// RevenueCat entitlement for per-seat coach access.
  static const String entitlementId =
      ArchiveLoopEntitlementIds.professionalCoachPerSeat;

  @visibleForTesting
  static bool? debugHasProfessionalSeat;

  static Future<bool> hasActiveProfessionalSeat() async {
    if (debugHasProfessionalSeat != null) {
      return debugHasProfessionalSeat!;
    }

    final cached = RevenueCatService.instance.latestEntitlements;
    if (cached.hasProfessionalCoachSeat) return true;

    try {
      final info = await Purchases.getCustomerInfo();
      return info.entitlements.active.containsKey(entitlementId);
    } catch (_, stackTrace) {
      return false;
    }
  }

  /// Resolves the coach-seat store product from RevenueCat offerings.
  static Future<Package?> resolveCoachSeatPackage() async {
    const config = RevenueCatConfiguration.current;
    final productId = _configuredProductId(config.coachSeatProductIdentifier);
    if (productId == null) return null;

    final offerings = await RevenueCatService.instance.fetchOfferings();
    if (offerings == null) return null;

    final offering = _resolveOffering(offerings, config.coachSeatOfferingId);
    if (offering == null) return null;

    for (final package in offering.availablePackages) {
      if (package.storeProduct.identifier == productId) {
        return package;
      }
    }
    return null;
  }

  static Offering? _resolveOffering(Offerings offerings, String? offeringId) {
    final trimmed = offeringId?.trim() ?? '';
    if (trimmed.isNotEmpty) {
      return offerings.all[trimmed];
    }
    return offerings.current;
  }

  static String? _configuredProductId(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }
}