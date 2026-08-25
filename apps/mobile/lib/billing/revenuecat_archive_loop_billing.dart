import 'package:archiveme_mobile/billing/billing_service.dart';
import 'package:archiveme_mobile/billing/revenuecat_archive_loop_logs.dart';
import 'package:archiveme_mobile/billing/revenuecat_service.dart';
import 'package:archiveme_mobile/features/paywall/archive_loop_entitlements.dart';
import 'package:archiveme_mobile/models/entitlement.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

enum ArchiveLoopPaywallProductPhase {
  loading,
  loaded,
  unavailable,
  purchasing,
  purchaseSuccess,
  purchaseFailed,
  restoring,
}

class ArchiveLoopPaywallProductState {
  const ArchiveLoopPaywallProductState({
    required this.phase,
    this.productId,
    this.priceLine,
    this.package,
    this.failureReason,
    this.isPro = false,
  });

  final ArchiveLoopPaywallProductPhase phase;
  final String? productId;
  final String? priceLine;
  final Package? package;
  final String? failureReason;
  final bool isPro;

  bool get canPurchase =>
      phase == ArchiveLoopPaywallProductPhase.loaded &&
      (package != null || (productId?.isNotEmpty ?? false));

  bool get canRestore =>
      phase != ArchiveLoopPaywallProductPhase.purchasing &&
      phase != ArchiveLoopPaywallProductPhase.restoring;

  bool get showUnavailableFallback =>
      phase == ArchiveLoopPaywallProductPhase.unavailable;

  ArchiveLoopPaywallProductState copyWith({
    ArchiveLoopPaywallProductPhase? phase,
    String? productId,
    String? priceLine,
    Package? package,
    String? failureReason,
    bool? isPro,
  }) {
    return ArchiveLoopPaywallProductState(
      phase: phase ?? this.phase,
      productId: productId ?? this.productId,
      priceLine: priceLine ?? this.priceLine,
      package: package ?? this.package,
      failureReason: failureReason ?? this.failureReason,
      isPro: isPro ?? this.isPro,
    );
  }
}

/// Loads ArchiveMe loop paywall products and handles purchase/restore.
class RevenueCatArchiveLoopBilling {
  RevenueCatArchiveLoopBilling({
    RevenueCatService? revenueCat,
    this._billing,
    Future<ArchiveLoopEntitlementStore?> Function()? entitlementStore,
  }) : _revenueCat = revenueCat ?? RevenueCatService.instance,
       _entitlementStore = entitlementStore ?? _defaultEntitlementStore;

  final RevenueCatService _revenueCat;
  final BillingService? _billing;
  final Future<ArchiveLoopEntitlementStore?> Function() _entitlementStore;

  static Future<ArchiveLoopEntitlementStore?> _defaultEntitlementStore() async {
    if (!AppServices.isInitialized) return null;
    return ArchiveLoopEntitlementStore(AppServices.instance.prefs);
  }

  BillingService? get _liveBilling {
    if (_billing != null) return _billing;
    if (!AppServices.isInitialized) return null;
    return AppServices.instance.billing;
  }

  Future<ArchiveLoopPaywallProductState> loadProduct() async {
    ArchiveLoopRevenueCatLog.productLoading();
    if (!_revenueCat.isConfigured) {
      ArchiveLoopRevenueCatLog.productFailed(reason: 'revenuecat_unavailable');
      return const ArchiveLoopPaywallProductState(
        phase: ArchiveLoopPaywallProductPhase.unavailable,
        failureReason: 'revenuecat_unavailable',
      );
    }

    try {
      final offerings = await _revenueCat.fetchOfferings();
      final current = offerings?.current;
      final package = _selectPackage(current);
      if (package == null) {
        ArchiveLoopRevenueCatLog.productFailed(reason: 'no_package');
        return const ArchiveLoopPaywallProductState(
          phase: ArchiveLoopPaywallProductPhase.unavailable,
          failureReason: 'no_package',
        );
      }

      final product = package.storeProduct;
      final price = product.priceString.trim();
      final productId = product.identifier.trim();
      ArchiveLoopRevenueCatLog.productLoaded(
        productId: productId,
        price: price,
      );
      final priceLine = price.isNotEmpty ? price : null;
      return ArchiveLoopPaywallProductState(
        phase: ArchiveLoopPaywallProductPhase.loaded,
        productId: productId,
        priceLine: priceLine,
        package: package,
      );
    } on Object catch (e, stackTrace) {
      ArchiveLoopRevenueCatLog.productFailed(reason: e.toString());
      return ArchiveLoopPaywallProductState(
        phase: ArchiveLoopPaywallProductPhase.unavailable,
        failureReason: e.toString(),
      );
    }
  }

  Package? _selectPackage(Offering? offering) {
    final packages = offering?.availablePackages ?? const <Package>[];
    if (packages.isEmpty) return null;
    Package? monthly;
    for (final pkg in packages) {
      if (pkg.packageType == PackageType.monthly) {
        monthly = pkg;
        break;
      }
    }
    return monthly ?? packages.first;
  }

  Future<ArchiveLoopPaywallProductState> purchase(
    ArchiveLoopPaywallProductState current,
  ) async {
    final package = current.package;
    if (package == null) {
      ArchiveLoopRevenueCatLog.purchaseFailed(reason: 'no_package');
      return current.copyWith(
        phase: ArchiveLoopPaywallProductPhase.purchaseFailed,
        failureReason: 'no_package',
      );
    }

    final productId = package.storeProduct.identifier;
    ArchiveLoopRevenueCatLog.purchaseStarted(productId: productId);
    try {
      final billing = _liveBilling;
      final PremiumEntitlements entitlements;
      if (billing != null) {
        entitlements = await billing.purchaseNative(package);
      } else {
        entitlements = await _revenueCat.purchasePackage(package);
      }
      final isPro = entitlements.isPro;
      if (isPro) {
        ArchiveLoopRevenueCatLog.purchaseSuccess(productId: productId);
        await _syncProAccess(isPro: true, source: 'revenuecat');
      } else {
        ArchiveLoopRevenueCatLog.purchaseFailed(reason: 'entitlement_inactive');
      }
      return current.copyWith(
        phase: isPro
            ? ArchiveLoopPaywallProductPhase.purchaseSuccess
            : ArchiveLoopPaywallProductPhase.purchaseFailed,
        isPro: isPro,
        failureReason: isPro ? null : 'entitlement_inactive',
      );
    } on Object catch (e, stackTrace) {
      ArchiveLoopRevenueCatLog.purchaseFailed(reason: e.toString());
      return current.copyWith(
        phase: ArchiveLoopPaywallProductPhase.purchaseFailed,
        failureReason: e.toString(),
      );
    }
  }

  Future<ArchiveLoopPaywallProductState> restore() async {
    ArchiveLoopRevenueCatLog.restoreStarted();
    if (!_revenueCat.isConfigured) {
      ArchiveLoopRevenueCatLog.purchaseFailed(reason: 'revenuecat_unavailable');
      return const ArchiveLoopPaywallProductState(
        phase: ArchiveLoopPaywallProductPhase.unavailable,
        failureReason: 'revenuecat_unavailable',
      );
    }
    try {
      final billing = _liveBilling;
      final PremiumEntitlements entitlements;
      if (billing != null) {
        entitlements = await billing.restoreNative();
      } else {
        entitlements = await _revenueCat.restorePurchases();
      }
      if (entitlements.isPro) {
        ArchiveLoopRevenueCatLog.restoreSuccess();
        await _syncProAccess(isPro: true, source: 'revenuecat');
        return const ArchiveLoopPaywallProductState(
          phase: ArchiveLoopPaywallProductPhase.purchaseSuccess,
          isPro: true,
        );
      }
      ArchiveLoopRevenueCatLog.restoreEmpty();
      return const ArchiveLoopPaywallProductState(
        phase: ArchiveLoopPaywallProductPhase.loaded,
      );
    } on Object catch (e, stackTrace) {
      ArchiveLoopRevenueCatLog.purchaseFailed(reason: e.toString());
      return ArchiveLoopPaywallProductState(
        phase: ArchiveLoopPaywallProductPhase.purchaseFailed,
        failureReason: e.toString(),
      );
    }
  }

  Future<void> refreshEntitlements({bool fromCache = false}) async {
    final billing = _liveBilling;
    if (billing == null) return;
    if (fromCache) {
      final cached = await billing.loadCachedEntitlements();
      final active = cached?.isPro ?? false;
      ArchiveLoopRevenueCatLog.entitlementCacheUsed(active: active);
      if (active) {
        await _syncProAccess(isPro: true, source: 'cache');
      }
      return;
    }
    final entitlements = await billing.loadEntitlements(forceRefresh: true);
    final active = entitlements.isPro;
    ArchiveLoopRevenueCatLog.entitlementRefreshed(
      source: 'revenuecat',
      active: active,
    );
    if (active) {
      await _syncProAccess(isPro: true, source: 'revenuecat');
    }
  }

  Future<void> syncProAccess({
    required bool isPro,
    required String source,
  }) async {
    if (!isPro) return;
    final store = await _entitlementStore();
    await store?.setPro(true);
    ArchiveLoopEntitlementLog.logProActive(source: source);
    ArchiveLoopRevenueCatLog.entitlementPersisted(active: true);
  }

  Future<void> _syncProAccess({required bool isPro, required String source}) =>
      syncProAccess(isPro: isPro, source: source);
}

/// Test double for paywall product flows without RevenueCat SDK.
class FakeRevenueCatArchiveLoopBilling extends RevenueCatArchiveLoopBilling {
  FakeRevenueCatArchiveLoopBilling({
    required this.configured,
    this.productId = 'archive_loop_pro_monthly',
    this.priceLine = r'$4.99 / month',
    this.purchaseSucceeds = true,
    this.restoreHasPro = false,
    this.loadFails = false,
    super.entitlementStore,
  }) : super(revenueCat: RevenueCatService.instance);

  final bool configured;
  final String productId;
  final String priceLine;
  final bool purchaseSucceeds;
  final bool restoreHasPro;
  final bool loadFails;

  @override
  Future<ArchiveLoopPaywallProductState> loadProduct() async {
    ArchiveLoopRevenueCatLog.productLoading();
    if (!configured || loadFails) {
      ArchiveLoopRevenueCatLog.productFailed(reason: 'revenuecat_unavailable');
      return const ArchiveLoopPaywallProductState(
        phase: ArchiveLoopPaywallProductPhase.unavailable,
        failureReason: 'revenuecat_unavailable',
      );
    }
    ArchiveLoopRevenueCatLog.productLoaded(
      productId: productId,
      price: priceLine,
    );
    return ArchiveLoopPaywallProductState(
      phase: ArchiveLoopPaywallProductPhase.loaded,
      productId: productId,
      priceLine: priceLine,
    );
  }

  @override
  Future<ArchiveLoopPaywallProductState> purchase(
    ArchiveLoopPaywallProductState current,
  ) async {
    ArchiveLoopRevenueCatLog.purchaseStarted(productId: productId);
    if (!purchaseSucceeds) {
      ArchiveLoopRevenueCatLog.purchaseFailed(reason: 'sandbox_declined');
      return current.copyWith(
        phase: ArchiveLoopPaywallProductPhase.purchaseFailed,
        failureReason: 'sandbox_declined',
      );
    }
    ArchiveLoopRevenueCatLog.purchaseSuccess(productId: productId);
    await syncProAccess(isPro: true, source: 'revenuecat');
    return current.copyWith(
      phase: ArchiveLoopPaywallProductPhase.purchaseSuccess,
      isPro: true,
    );
  }

  @override
  Future<ArchiveLoopPaywallProductState> restore() async {
    ArchiveLoopRevenueCatLog.restoreStarted();
    if (restoreHasPro) {
      ArchiveLoopRevenueCatLog.restoreSuccess();
      await syncProAccess(isPro: true, source: 'revenuecat');
      return const ArchiveLoopPaywallProductState(
        phase: ArchiveLoopPaywallProductPhase.purchaseSuccess,
        isPro: true,
      );
    }
    ArchiveLoopRevenueCatLog.restoreEmpty();
    return const ArchiveLoopPaywallProductState(
      phase: ArchiveLoopPaywallProductPhase.loaded,
    );
  }
}