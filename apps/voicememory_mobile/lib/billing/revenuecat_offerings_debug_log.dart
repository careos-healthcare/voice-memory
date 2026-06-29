import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'revenuecat_service.dart';

/// Debug-only RevenueCat offering / entitlement traces for paywall QA.
///
/// Never shown in consumer UI — grep device logs for `ARCHIVEME_RC_`.
abstract final class RevenueCatOfferingsDebugLog {
  static void offeringsSnapshot({
    required Offerings? offerings,
    String? error,
  }) {
    if (!kDebugMode) return;
    if (offerings == null) {
      debugPrint(
        'ARCHIVEME_RC_OFFERINGS loaded=false error=${error ?? 'null_offerings'}',
      );
      return;
    }

    final all = offerings.all;
    final current = offerings.current;
    final packages = current?.availablePackages ?? const <Package>[];

    debugPrint(
      'ARCHIVEME_RC_OFFERINGS loaded=true offeringCount=${all.length} '
      'requested=current currentOfferingId=${current?.identifier ?? 'null'}',
    );

    if (all.isNotEmpty) {
      debugPrint(
        'ARCHIVEME_RC_OFFERING_IDS ${all.keys.join(',')}',
      );
    }

    if (packages.isEmpty) {
      debugPrint(
        'ARCHIVEME_RC_PACKAGES currentOffering=${current?.identifier ?? 'null'} '
        'packageCount=0 '
        'hint=Mark an offering Current in RevenueCat and attach monthly/annual packages',
      );
      return;
    }

    for (final pkg in packages) {
      debugPrint(
        'ARCHIVEME_RC_PACKAGE '
        'offering=${current?.identifier} '
        'packageId=${pkg.identifier} '
        'packageType=${pkg.packageType.name} '
        'storeProductId=${pkg.storeProduct.identifier}',
      );
    }
  }

  static void entitlementsMapped({
    required CustomerInfo info,
    required String source,
  }) {
    if (!kDebugMode) return;

    final activeKeys = info.entitlements.active.keys.toList()..sort();
    final allKeys = info.entitlements.all.keys.toList()..sort();
    final pro = info.entitlements.active[RevenueCatService.proEntitlementId];
    final proActive = pro != null && pro.isActive;

    debugPrint(
      'ARCHIVEME_RC_ENTITLEMENTS source=$source '
      'expected=${RevenueCatService.proEntitlementId} '
      'proActive=$proActive '
      'activeEntitlements=${activeKeys.isEmpty ? 'none' : activeKeys.join(',')} '
      'allEntitlements=${allKeys.isEmpty ? 'none' : allKeys.join(',')}',
    );
  }

  static void paywallLoadResult({
    required bool billingConfigured,
    required bool offeringsLoaded,
    required int offeringCount,
    required String? currentOfferingId,
    required int packageCount,
    required bool monthlyPackageFound,
    required bool annualPackageFound,
    required bool purchasePlansAvailable,
    required bool showingUnavailable,
    String? error,
  }) {
    if (!kDebugMode) return;

    debugPrint(
      'ARCHIVEME_RC_PAYWALL billingConfigured=$billingConfigured '
      'offeringsLoaded=$offeringsLoaded offeringCount=$offeringCount '
      'currentOfferingId=${currentOfferingId ?? 'null'} packageCount=$packageCount '
      'monthlyPackageFound=$monthlyPackageFound annualPackageFound=$annualPackageFound '
      'purchasePlansAvailable=$purchasePlansAvailable showingUnavailable=$showingUnavailable '
      'error=${error ?? 'none'}',
    );

    if (billingConfigured && showingUnavailable) {
      debugPrint(
        'ARCHIVEME_RC_PAYWALL_UNAVAILABLE '
        'billing is configured but purchase UI is unavailable — '
        'check RevenueCat Current offering, package types (monthly/annual), '
        'and StoreKit product linkage. Restore can still work independently.',
      );
    }
  }
}
