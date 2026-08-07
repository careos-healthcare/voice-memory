import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../config/app_config.dart';
import '../models/entitlement.dart';
import 'archive_loop_entitlement_ids.dart';
import '../api/api_exceptions.dart';
import 'billing_async_guard.dart';
import 'revenuecat_diagnostics.dart';
import 'revenuecat_diagnostics_log.dart';
import 'revenuecat_offerings_debug_log.dart';
import 'store_billing_port.dart';

/// Native store billing via RevenueCat — no browser checkout.
class RevenueCatService implements StoreBillingPort {
  RevenueCatService._();

  static final RevenueCatService instance = RevenueCatService._();

  static const String proEntitlementId = 'pro';

  final StreamController<PremiumEntitlements> _entitlementController =
      StreamController<PremiumEntitlements>.broadcast();

  bool _configured = false;
  PremiumEntitlements _latest = PremiumEntitlements.free();
  RevenueCatDiagnostics _diagnostics = RevenueCatDiagnostics.initial();

  @override
  Stream<PremiumEntitlements> get entitlementStream =>
      _entitlementController.stream;

  PremiumEntitlements get latestEntitlements => _latest;

  @override
  bool get isConfigured => _configured;

  RevenueCatDiagnostics get diagnostics => _diagnostics;

  /// Injectable delay/override for paywall timeout tests.
  @visibleForTesting
  static Future<Offerings?> Function()? fetchOfferingsOverrideForTest;

  /// Exposes entitlement mapping for tests without requiring a configured
  /// RevenueCat SDK instance.
  @visibleForTesting
  PremiumEntitlements mapCustomerInfoForTest(CustomerInfo info) =>
      _mapCustomerInfo(info);

  bool get apiKeyMissing => _diagnostics.apiKeyMissing;

  Future<String?> getAppUserId() async {
    if (!_configured) return null;
    try {
      return await Purchases.appUserID;
    } catch (e) {
      debugPrint('RevenueCat appUserID: $e');
      return null;
    }
  }

  String? get _apiKey {
    if (Platform.isIOS) {
      const key = String.fromEnvironment(
        'REVENUECAT_IOS_API_KEY',
        defaultValue: '',
      );
      if (key.trim().isNotEmpty) return key.trim();
    }
    if (Platform.isAndroid) {
      const key = String.fromEnvironment(
        'REVENUECAT_ANDROID_API_KEY',
        defaultValue: '',
      );
      if (key.trim().isNotEmpty) return key.trim();
    }
    const fallback = String.fromEnvironment(
      'REVENUECAT_API_KEY',
      defaultValue: '',
    );
    return fallback.trim().isEmpty ? null : fallback.trim();
  }

  String get _platformLabel {
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    return 'unknown';
  }

  Future<void> initialize() async {
    if (_configured) return;
    final apiKey = _apiKey;
    RevenueCatDiagnosticsLog.configureStarted(
      platform: _platformLabel,
      apiKeyPresent: apiKey != null,
      apiKey: apiKey,
    );
    debugPrint('RevenueCat: startup — platform=$_platformLabel');
    if (apiKey == null) {
      debugPrint(
        'RevenueCat: disabled — no API key (set REVENUECAT_${_platformLabel.toUpperCase()}_API_KEY or REVENUECAT_API_KEY at build time)',
      );
      _diagnostics = RevenueCatDiagnostics.initial();
      RevenueCatDiagnosticsLog.configureFinished(
        success: false,
        reason: 'api_key_missing',
      );
      return;
    }
    debugPrint('RevenueCat: API key detected for $_platformLabel');
    try {
      await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.warn);
      final config = PurchasesConfiguration(apiKey);
      if (AppConfig.bundleId.isNotEmpty) {
        // App user id can be linked after sign-in via logIn().
      }
      await Purchases.configure(config).timeout(billingOperationTimeout);
      Purchases.addCustomerInfoUpdateListener(_onCustomerInfo);
      _configured = true;
      _diagnostics = _diagnostics.copyWith(
        revenueCatConfigured: true,
        apiKeyMissing: false,
        clearError: true,
      );
      debugPrint('RevenueCat: configured successfully');
      RevenueCatDiagnosticsLog.configureFinished(success: true);
      await refreshEntitlements();
    } on TimeoutException {
      _configured = false;
      _diagnostics = _diagnostics.copyWith(
        revenueCatConfigured: false,
        apiKeyMissing: false,
        lastRevenueCatError: 'configure_timeout',
      );
      debugPrint('RevenueCat: configure timed out — billing disabled');
      RevenueCatDiagnosticsLog.configureFinished(
        success: false,
        reason: 'configure_timeout_${billingOperationTimeout.inSeconds}s',
      );
      _emit(PremiumEntitlements.free());
    } catch (e, st) {
      _configured = false;
      _diagnostics = _diagnostics.copyWith(
        revenueCatConfigured: false,
        apiKeyMissing: false,
        lastRevenueCatError: e.toString(),
      );
      debugPrint('RevenueCat: configure failed — billing disabled: $e');
      if (kDebugMode) debugPrint('$st');
      RevenueCatDiagnosticsLog.configureFinished(
        success: false,
        reason: e.toString(),
      );
      _emit(PremiumEntitlements.free());
    }
  }

  void _onCustomerInfo(CustomerInfo info) {
    _emit(_mapCustomerInfo(info));
  }

  void _emit(PremiumEntitlements entitlements) {
    _latest = entitlements;
    if (!_entitlementController.isClosed) {
      _entitlementController.add(entitlements);
    }
  }

  PremiumEntitlements _mapCustomerInfo(CustomerInfo info) {
    RevenueCatDiagnosticsLog.entitlementsChecked(
      source: 'mapCustomerInfo',
      info: info,
    );
    RevenueCatOfferingsDebugLog.entitlementsMapped(
      info: info,
      source: 'mapCustomerInfo',
    );
    final active = info.entitlements.active;
    // P0 fix — billing entitlement ID conflict: the RevenueCat dashboard's
    // primary product entitlement is `archive_loop_pro`
    // (ArchiveLoopEntitlementIds.archiveLoopPro), but this mapper used to
    // only ever check the legacy `pro` id (proEntitlementId), so a customer
    // correctly entitled under the newer id appeared free. Accept either —
    // whichever the dashboard actually reports as active — rather than
    // hard-coding a single "authoritative" id.
    final matchedIds = ArchiveLoopEntitlementIds.revenueCatEntitlementIds
        .where((id) => active[id]?.isActive == true)
        .toList(growable: false);
    final isPro = matchedIds.isNotEmpty;
    return PremiumEntitlements(
      tier: isPro ? BillingTier.pro : BillingTier.free,
      entitlementIds: matchedIds,
      billingConnected: _configured,
      source: 'revenuecat',
    );
  }

  void _recordOfferings(Offerings? offerings, {String? error}) {
    final all = offerings?.all ?? {};
    final current = offerings?.current;
    final packages = current?.availablePackages ?? const <Package>[];
    final productIds = packages
        .map((p) => p.storeProduct.identifier)
        .toList(growable: false);

    _diagnostics = _diagnostics.copyWith(
      revenueCatConfigured: _configured,
      apiKeyMissing: false,
      offeringsLoaded: offerings != null,
      offeringCount: all.length,
      packageCount: packages.length,
      requestedOfferingId: 'current',
      currentOfferingId: current?.identifier,
      productIdentifiers: productIds,
      lastRevenueCatError: error,
      clearError: error == null,
    );

    debugPrint(
      'RevenueCat diagnostics: configured=$_configured offerings=${all.length} '
      'packages=${packages.length} current=${current?.identifier}',
    );
  }

  Future<Offerings?> fetchOfferings() async {
    final override = fetchOfferingsOverrideForTest;
    if (override != null) {
      RevenueCatDiagnosticsLog.fetchOfferingsStarted(
        billingConfigured: _configured,
      );
      try {
        final offerings = await override().timeout(billingOperationTimeout);
        final fetchError = offerings == null
            ? 'fetchOfferings_override_null'
            : null;
        _recordOfferings(offerings, error: fetchError);
        RevenueCatDiagnosticsLog.fetchOfferingsFinished(
          success: offerings != null,
          offerings: offerings,
          error: fetchError,
        );
        return offerings;
      } on TimeoutException {
        _recordOfferings(null, error: 'fetchOfferings_override_timeout');
        RevenueCatDiagnosticsLog.fetchOfferingsFinished(
          success: false,
          offerings: null,
          error:
              'fetchOfferings_override_timeout_${billingOperationTimeout.inSeconds}s',
        );
        return null;
      } catch (e) {
        _recordOfferings(null, error: e.toString());
        RevenueCatDiagnosticsLog.fetchOfferingsFinished(
          success: false,
          offerings: null,
          error: e.toString(),
        );
        return null;
      }
    }

    if (!_configured) {
      RevenueCatDiagnosticsLog.fetchOfferingsStarted(billingConfigured: false);
      RevenueCatOfferingsDebugLog.fetchOfferingsStarted(
        billingConfigured: false,
      );
      _recordOfferings(null, error: 'revenuecat_not_configured');
      RevenueCatDiagnosticsLog.fetchOfferingsFinished(
        success: false,
        offerings: null,
        error: 'revenuecat_not_configured',
      );
      RevenueCatOfferingsDebugLog.fetchOfferingsFinished(
        offerings: null,
        error: 'revenuecat_not_configured',
      );
      return null;
    }
    RevenueCatDiagnosticsLog.fetchOfferingsStarted(billingConfigured: true);
    RevenueCatOfferingsDebugLog.fetchOfferingsStarted(billingConfigured: true);
    try {
      final offerings = await withBillingTimeout(
        Purchases.getOfferings(),
        label: 'fetchOfferings',
      );
      final fetchError = offerings == null
          ? 'fetchOfferings timeout or null response'
          : null;
      _recordOfferings(offerings, error: fetchError);
      RevenueCatDiagnosticsLog.fetchOfferingsFinished(
        success: offerings != null,
        offerings: offerings,
        error: fetchError,
      );
      RevenueCatOfferingsDebugLog.fetchOfferingsFinished(
        offerings: offerings,
        error: fetchError,
      );
      return offerings;
    } catch (e) {
      debugPrint('RevenueCat fetchOfferings: $e');
      _recordOfferings(null, error: e.toString());
      RevenueCatDiagnosticsLog.fetchOfferingsFinished(
        success: false,
        offerings: null,
        error: e.toString(),
      );
      RevenueCatOfferingsDebugLog.fetchOfferingsFinished(
        offerings: null,
        error: e.toString(),
      );
      return null;
    }
  }

  @override
  Future<PremiumEntitlements> purchasePackage(Package package) async {
    if (!_configured) {
      throw BillingUnavailableException();
    }
    final result = await Purchases.purchasePackage(package);
    final mapped = _mapCustomerInfo(result);
    _emit(mapped);
    return mapped;
  }

  @override
  Future<PremiumEntitlements> restorePurchases() async {
    if (!_configured) {
      throw BillingUnavailableException();
    }
    final info = await withBillingTimeoutRequired(
      Purchases.restorePurchases(),
      label: 'restorePurchases',
    );
    final mapped = _mapCustomerInfo(info);
    _emit(mapped);
    return mapped;
  }

  /// iOS StoreKit sync — refreshes local receipt state before reading entitlements.
  Future<PremiumEntitlements> syncAndRefreshEntitlements() async {
    if (!_configured) {
      final free = PremiumEntitlements.free();
      _emit(free);
      return free;
    }
    try {
      await withBillingTimeoutRequired(
        Purchases.syncPurchases(),
        label: 'syncPurchases',
      );
    } catch (e) {
      debugPrint('RevenueCat syncPurchases: $e');
    }
    return refreshEntitlements();
  }

  @override
  Future<PremiumEntitlements> refreshEntitlements() async {
    if (!_configured) {
      final free = PremiumEntitlements.free();
      _emit(free);
      return free;
    }
    try {
      final info = await withBillingTimeout(
        Purchases.getCustomerInfo(),
        label: 'refreshEntitlements',
      );
      if (info == null) {
        debugPrint('RevenueCat refresh: unavailable — using free tier');
        final free = PremiumEntitlements.free();
        _emit(free);
        return free;
      }
      final mapped = _mapCustomerInfo(info);
      _emit(mapped);
      return mapped;
    } catch (e) {
      debugPrint('RevenueCat refresh: $e — using free tier');
      final free = PremiumEntitlements.free();
      _emit(free);
      return free;
    }
  }

  Future<void> logIn(String appUserId) async {
    if (!_configured) return;
    try {
      final result = await Purchases.logIn(appUserId);
      _emit(_mapCustomerInfo(result.customerInfo));
    } catch (e) {
      debugPrint('RevenueCat logIn: $e');
    }
  }

  Future<void> logOut() async {
    if (!_configured) return;
    try {
      final info = await Purchases.logOut();
      _emit(_mapCustomerInfo(info));
    } catch (e) {
      debugPrint('RevenueCat logOut: $e');
    }
  }

  void dispose() {
    _entitlementController.close();
  }
}
