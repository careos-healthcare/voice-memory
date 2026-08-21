import 'dart:async';

import 'package:archiveme_mobile/billing/revenuecat_service.dart';
import 'package:archiveme_mobile/billing/v1/paywall_dependencies.dart';
import 'package:archiveme_mobile/features/paywall/archive_loop_entitlements.dart';
import 'package:archiveme_mobile/models/entitlement.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Production [PaywallDependencies] backed by [AppServices] and RevenueCat.
class AppServicesPaywallDependencies implements PaywallDependencies {
  AppServicesPaywallDependencies({
    this.billingReady,
    this.loadTimeout = const Duration(seconds: 12),
  });

  final bool Function()? billingReady;

  @override
  final Duration loadTimeout;

  @override
  bool get appServicesInitialized => AppServices.isInitialized;

  @override
  bool isBillingReady() =>
      billingReady?.call() ?? RevenueCatService.instance.isConfigured;

  @override
  Future<void> initializeBilling() => RevenueCatService.instance.initialize();

  @override
  Future<Offerings?> fetchOfferings() =>
      RevenueCatService.instance.fetchOfferings();

  @override
  Future<PremiumEntitlements?> loadCachedEntitlements() {
    return AppServices.instance.billing.loadCachedEntitlements();
  }

  @override
  Future<PremiumEntitlements> loadEntitlements({required bool forceRefresh}) {
    return AppServices.instance.billing.loadEntitlements(
      forceRefresh: forceRefresh,
    );
  }

  @override
  Future<PremiumEntitlements> purchasePackage(Package package) {
    return AppServices.instance.billing.purchaseNative(package);
  }

  @override
  PremiumEntitlements get latestEntitlements =>
      RevenueCatService.instance.latestEntitlements;

  @override
  Future<PremiumEntitlements> mergeReviewProEntitlements(
    PremiumEntitlements entitlements,
  ) async {
    if (!AppServices.isInitialized || entitlements.isPro) return entitlements;
    try {
      final loopState =
          await ArchiveLoopEntitlementStore(
            AppServices.instance.prefs,
          ).load().timeout(
            const Duration(seconds: 2),
            onTimeout: () => ArchiveLoopEntitlementState.empty,
          );
      if (!loopState.isPro) return entitlements;
      return const PremiumEntitlements(
        tier: BillingTier.pro,
        entitlementIds: [],
        billingConnected: false,
        source: 'app_review',
      );
    } catch (_, stackTrace) {
      return entitlements;
    }
  }
}

/// Test double for paywall controller unit tests.
class FakePaywallDependencies implements PaywallDependencies {
  FakePaywallDependencies({
    this.billingReady = true,
    this.appServicesInitialized = true,
    this.offerings,
    PremiumEntitlements? entitlements,
    this.loadTimeout = const Duration(seconds: 12),
    this.throwOnFetch = false,
  }) : entitlements = entitlements ?? PremiumEntitlements.free();

  @override
  final Duration loadTimeout;

  @override
  final bool appServicesInitialized;

  final bool billingReady;
  final Offerings? offerings;
  PremiumEntitlements entitlements;
  final bool throwOnFetch;
  int purchaseCalls = 0;

  @override
  bool isBillingReady() => billingReady;

  @override
  Future<void> initializeBilling() async {}

  @override
  Future<Offerings?> fetchOfferings() async {
    if (throwOnFetch) throw StateError('fetch failed');
    return offerings;
  }

  @override
  Future<PremiumEntitlements?> loadCachedEntitlements() async => entitlements;

  @override
  Future<PremiumEntitlements> loadEntitlements({
    required bool forceRefresh,
  }) async => entitlements;

  @override
  Future<PremiumEntitlements> mergeReviewProEntitlements(
    PremiumEntitlements value,
  ) async => value;

  @override
  Future<PremiumEntitlements> purchasePackage(Package package) async {
    purchaseCalls++;
    entitlements = const PremiumEntitlements(
      tier: BillingTier.pro,
      entitlementIds: ['pro'],
      billingConnected: true,
      source: 'test_purchase',
    );
    return entitlements;
  }

  @override
  PremiumEntitlements get latestEntitlements => entitlements;
}