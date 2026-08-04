import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../billing/billing_platform.dart';
import '../../billing/purchase_failure.dart';
import '../../billing/revenuecat_configuration.dart';
import '../../features/monetization/domain/generated/monetization_policy.g.dart';
import '../domain/subscription_models.dart';
import 'legacy_subscription_mapper.dart';
import 'subscription_data_sources.dart';

class RevenueCatSubscriptionDataSource implements SubscriptionStoreDataSource {
  RevenueCatSubscriptionDataSource({
    required this.billingPlatform,
    RevenueCatConfiguration? configuration,
  }) : configuration = configuration ?? RevenueCatConfiguration.current;

  final BillingPlatform billingPlatform;
  final RevenueCatConfiguration configuration;
  final Map<String, Package> _packageHandles = {};
  int _nextOfferId = 0;

  @override
  SubscriptionAvailability get availability => billingPlatform.isConfigured
      ? SubscriptionAvailability.available
      : SubscriptionAvailability.notConfigured;

  @override
  Stream<SubscriptionState> get stateChanges => billingPlatform
      .entitlementStream
      .map(LegacySubscriptionMapper.fromEntitlements);

  @override
  Future<SubscriptionState> refresh() async {
    final value = await billingPlatform.refreshEntitlements();
    return LegacySubscriptionMapper.fromEntitlements(value);
  }

  @override
  Future<List<SubscriptionOffer>> loadOffers() async {
    final offerings = await billingPlatform.fetchOfferings();
    final configuredOfferingId = configuration.offeringId?.trim();
    final offering = configuredOfferingId?.isNotEmpty == true
        ? offerings?.all[configuredOfferingId]
        : offerings?.current;
    final packages = offering?.availablePackages ?? const <Package>[];
    _packageHandles.clear();
    final eligiblePackages = packages
        .where((package) => isCurrentSubscriptionPackage(package.packageType))
        .toList(growable: false);
    final mapped = eligiblePackages.map(_mapPackage).toList(growable: false);
    if (mapped.any((offer) => offer.price.trim().isEmpty)) {
      _packageHandles.clear();
      throw const RevenueCatOfferingConfigurationException(
        'missing_localized_price',
      );
    }
    final validation = configuration.validateOffers(
      mapped,
      offeringExists: offering != null,
    );
    if (!validation.isValid) {
      _packageHandles.clear();
      debugPrint(
        'RevenueCat offering rejected: ${validation.code}; '
        'purchase controls disabled',
      );
      throw RevenueCatOfferingConfigurationException(
        validation.code ?? 'invalid_offering',
      );
    }
    return mapped;
  }

  SubscriptionOffer _mapPackage(Package package) {
    final id = 'offer-${++_nextOfferId}';
    _packageHandles[id] = package;
    final product = package.storeProduct;
    final intro = product.introductoryPrice;
    return SubscriptionOffer(
      id: id,
      productIdentifier: product.identifier,
      price: product.priceString,
      period: package.packageType == PackageType.monthly
          ? SubscriptionPeriod.monthly
          : SubscriptionPeriod.annual,
      title: product.title,
      description: product.description,
      hasFreeTrial: intro?.price == 0,
      introductoryPrice: intro?.priceString,
      introductoryPeriod: intro?.period,
      introductoryCycles: intro?.cycles,
    );
  }

  @visibleForTesting
  static bool isCurrentSubscriptionPackage(PackageType packageType) {
    final kind = switch (packageType) {
      PackageType.monthly => 'monthly',
      PackageType.annual => 'annual',
      PackageType.lifetime => 'lifetime',
      _ => packageType.name,
    };
    return MonetizationPolicy.currentOfferingPackageKinds.contains(kind) &&
        !MonetizationPolicy.blockedCurrentPackageKinds.contains(kind);
  }

  @override
  Future<SubscriptionState> purchase(String offerId) async {
    final package = _packageHandles[offerId];
    if (package == null) {
      throw StateError('Unknown or expired subscription offer');
    }
    if (!isCurrentSubscriptionPackage(package.packageType)) {
      throw SubscriptionPurchaseException(
        SubscriptionPurchaseFailureKind.productUnavailable,
        cause: StateError('Lifetime and non-subscription packages are blocked'),
      );
    }
    try {
      final value = await billingPlatform.purchasePackage(package);
      return LegacySubscriptionMapper.fromEntitlements(value);
    } on PurchaseFailure catch (error) {
      throw SubscriptionPurchaseException(
        _mapPurchaseFailure(error.kind),
        cause: error.cause,
      );
    } on Object catch (error) {
      throw SubscriptionPurchaseException(
        SubscriptionPurchaseFailureKind.unexpected,
        cause: error,
      );
    }
  }

  @override
  Future<SubscriptionState> restore() async {
    final value = await billingPlatform.restorePurchases();
    return LegacySubscriptionMapper.fromEntitlements(value);
  }

  @override
  Future<String?> updateIdentity(String? identity) async {
    if (identity == null) {
      await billingPlatform.logOut();
    } else {
      await billingPlatform.logIn(identity);
    }
    return billingPlatform.getAppUserId();
  }

  @override
  Future<SubscriptionDiagnostics> loadDiagnostics() async {
    final value = billingPlatform.diagnostics;
    return SubscriptionDiagnostics(
      availability: availability,
      offersLoaded: value.offeringsLoaded,
      offerCount: value.packageCount,
      lastError: value.lastRevenueCatError,
    );
  }

  SubscriptionPurchaseFailureKind _mapPurchaseFailure(
    PurchaseFailureKind kind,
  ) {
    return switch (kind) {
      PurchaseFailureKind.cancelled =>
        SubscriptionPurchaseFailureKind.cancelled,
      PurchaseFailureKind.temporary =>
        SubscriptionPurchaseFailureKind.temporary,
      PurchaseFailureKind.pending => SubscriptionPurchaseFailureKind.pending,
      PurchaseFailureKind.productUnavailable =>
        SubscriptionPurchaseFailureKind.productUnavailable,
      PurchaseFailureKind.verification =>
        SubscriptionPurchaseFailureKind.verification,
      PurchaseFailureKind.unexpected =>
        SubscriptionPurchaseFailureKind.unexpected,
    };
  }
}
