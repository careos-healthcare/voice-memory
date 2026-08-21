import 'dart:async';
import 'dart:io';

import 'package:archiveme_mobile/billing/archive_loop_entitlement_ids.dart';
import 'package:archiveme_mobile/billing/revenuecat_configuration.dart';
import 'package:archiveme_mobile/billing/revenuecat_service.dart';
import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/features/billing/application/billing_notifier.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

final subscriptionProvider =
    NotifierProvider<SubscriptionNotifier, SubscriptionState>(
      SubscriptionNotifier.new,
    );

/// Read/write Pro entitlement — mirrors RevenueCat customer info.
final subscriptionNotifierProvider = Provider<SubscriptionNotifier>(
  (ref) => ref.read(subscriptionProvider.notifier),
);

final isProUserProvider = Provider<bool>(
  (ref) => ref.watch(subscriptionProvider).isPro,
);

/// Backward-compatible alias for screens that call `ensureInitialized()`.
final Provider<SubscriptionNotifier> subscriptionControllerProvider = subscriptionNotifierProvider;

class SubscriptionState {
  const SubscriptionState({
    this.isPro = false,
    this.isLoading = true,
    this.errorMessage,
    this.billingConfigured = false,
    this.purchasesEnabled = RevenueCatConfiguration.purchasesEnabledAtBuildTime,
    this.monthlyPriceLabel,
    this.yearlyPriceLabel,
  });

  final bool isPro;
  final bool isLoading;
  final String? errorMessage;
  final bool billingConfigured;
  final bool purchasesEnabled;
  final String? monthlyPriceLabel;
  final String? yearlyPriceLabel;

  static const String proPriceRangeHint = r'$7–$9/month';

  String get monthlyPriceDisplay =>
      monthlyPriceLabel?.trim().isNotEmpty == true
          ? monthlyPriceLabel!
          : proPriceRangeHint;

  SubscriptionState copyWith({
    bool? isPro,
    bool? isLoading,
    String? errorMessage,
    bool? billingConfigured,
    bool? purchasesEnabled,
    String? monthlyPriceLabel,
    String? yearlyPriceLabel,
    bool clearError = false,
  }) {
    return SubscriptionState(
      isPro: isPro ?? this.isPro,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      billingConfigured: billingConfigured ?? this.billingConfigured,
      purchasesEnabled: purchasesEnabled ?? this.purchasesEnabled,
      monthlyPriceLabel: monthlyPriceLabel ?? this.monthlyPriceLabel,
      yearlyPriceLabel: yearlyPriceLabel ?? this.yearlyPriceLabel,
    );
  }
}

class SubscriptionNotifier extends Notifier<SubscriptionState> {
  @override
  SubscriptionState build() {
    unawaited(_initRevenueCat());
    return const SubscriptionState();
  }

  RevenueCatService get _revenueCat => RevenueCatService.instance;

  /// Idempotent bootstrap for billing settings and Tier 2 gates.
  Future<void> ensureInitialized() => _initRevenueCat();

  Future<void> refreshEntitlements() => checkSubscriptionStatus();

  Future<void> openManageSubscriptions() => _revenueCat.openManageSubscriptions();

  Future<void> _initRevenueCat() async {
    if (!RevenueCatConfiguration.purchasesEnabledAtBuildTime) {
      state = state.copyWith(isLoading: false, billingConfigured: false);
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _revenueCat.initialize();
      ref.read(billingProvider.notifier).startListening();
      await checkSubscriptionStatus();
      await _refreshOfferingsPriceLabels();
    } catch (e, stackTrace) {
      state = state.copyWith(
        isLoading: false,
        billingConfigured: _revenueCat.isConfigured,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> checkSubscriptionStatus() async {
    if (!RevenueCatConfiguration.purchasesEnabledAtBuildTime) {
      state = state.copyWith(isLoading: false, billingConfigured: false);
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      if (!_revenueCat.isConfigured) {
        await _revenueCat.initialize();
      }

      final entitlements = await _revenueCat.refreshEntitlements();
      state = state.copyWith(
        isPro: entitlements.isPro,
        isLoading: false,
        billingConfigured: _revenueCat.isConfigured,
      );
    } catch (e, stackTrace) {
      state = state.copyWith(
        isLoading: false,
        billingConfigured: _revenueCat.isConfigured,
        errorMessage: e.toString(),
      );
    }
  }

  Future<bool> purchasePackage(Package package) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final entitlements = await _revenueCat.purchasePackage(package);
      state = state.copyWith(
        isPro: entitlements.isPro,
        isLoading: false,
        billingConfigured: true,
      );
      return entitlements.isPro;
    } catch (e, stackTrace) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<void> restorePurchases() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final entitlements = await _revenueCat.restorePurchases();
      state = state.copyWith(
        isPro: entitlements.isPro,
        isLoading: false,
        billingConfigured: _revenueCat.isConfigured,
      );
    } catch (e, stackTrace) {
      state = state.copyWith(
        isLoading: false,
        billingConfigured: _revenueCat.isConfigured,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> _refreshOfferingsPriceLabels() async {
    if (!_revenueCat.isConfigured) return;

    try {
      final offerings = await _revenueCat.fetchOfferings();
      final packages = offerings?.current?.availablePackages ?? const [];
      String? monthly;
      String? yearly;

      for (final package in packages) {
        final price = package.storeProduct.priceString;
        switch (package.packageType) {
          case PackageType.monthly:
            monthly = price;
          case PackageType.annual:
            yearly = price;
          default:
            break;
        }
      }

      state = state.copyWith(
        monthlyPriceLabel: monthly,
        yearlyPriceLabel: yearly,
      );
    } catch (e, stackTrace) {
      AppLogger.error('Unhandled error caught', error: e, stackTrace: stackTrace);
      AppLogger.debug('SubscriptionNotifier: offerings refresh skipped — $e');
    }
  }

  /// Maps RevenueCat [CustomerInfo] to Pro — honors dashboard entitlement ids.
  @visibleForTesting
  static bool isProFromCustomerInfo(CustomerInfo customerInfo) {
    final active = customerInfo.entitlements.active;
    return ArchiveLoopEntitlementIds.revenueCatEntitlementIds.any(
      (id) => active[id]?.isActive == true,
    );
  }
}

/// Platform RevenueCat public SDK key from build configuration — never hardcode.
String? revenueCatPublicApiKeyForCurrentPlatform() {
  final platform = Platform.isIOS
      ? RevenueCatPlatform.ios
      : Platform.isAndroid
      ? RevenueCatPlatform.android
      : RevenueCatPlatform.unsupported;
  return RevenueCatConfiguration.current.publicSdkKeyFor(platform);
}
