import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../api/api_exceptions.dart';
import '../features/monetization/domain/generated/monetization_policy.g.dart';
import '../models/entitlement.dart';
import 'archive_loop_entitlement_ids.dart';
import 'billing_async_guard.dart';
import 'billing_platform.dart';
import 'purchase_failure.dart';
import 'revenuecat_app_user_id_store.dart';
import 'revenuecat_configuration.dart';
import 'revenuecat_diagnostics.dart';
import 'revenuecat_diagnostics_log.dart';
import 'revenuecat_offerings_debug_log.dart';

/// Native store billing via RevenueCat — no browser checkout.
class RevenueCatService implements BillingPlatform {
  RevenueCatService({RevenueCatConfiguration? configuration})
    : configuration = configuration ?? RevenueCatConfiguration.current;

  static final RevenueCatService instance = RevenueCatService();

  static const String proEntitlementId =
      ArchiveLoopEntitlementIds.archiveLoopPro;
  static const Duration maxOfflineProAge = Duration(days: 5);
  static const String requiredRestoreBehavior = 'Transfer to new App User ID';

  final RevenueCatConfiguration configuration;
  final StreamController<PremiumEntitlements> _entitlementController =
      StreamController<PremiumEntitlements>.broadcast();

  bool _configured = false;
  String? _configuredAppUserId;
  final RevenueCatAppUserIdStore _appUserIdStore = RevenueCatAppUserIdStore();
  PremiumEntitlements _latest = PremiumEntitlements.free();
  RevenueCatDiagnostics _diagnostics = RevenueCatDiagnostics.initial();

  @override
  Stream<PremiumEntitlements> get entitlementStream =>
      _entitlementController.stream;

  @override
  PremiumEntitlements get latestEntitlements => _latest;

  @override
  bool get isConfigured => _configured;

  @override
  RevenueCatDiagnostics get diagnostics => _diagnostics;

  @override
  bool get apiKeyMissing => _diagnostics.apiKeyMissing;

  @override
  Future<String?> getAppUserId() async {
    if (!_configured) return null;
    try {
      return await Purchases.appUserID;
    } catch (e) {
      debugPrint('RevenueCat appUserID: $e');
      return null;
    }
  }

  String get _platformLabel {
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    return 'unknown';
  }

  RevenueCatPlatform get _platform {
    if (Platform.isIOS) return RevenueCatPlatform.ios;
    if (Platform.isAndroid) return RevenueCatPlatform.android;
    return RevenueCatPlatform.unsupported;
  }

  @override
  Future<void> initialize() async {
    if (_configured) return;
    if (!configuration.purchasesEnabled) {
      debugPrint('RevenueCat: purchases explicitly disabled for this build');
      _diagnostics = RevenueCatDiagnostics.initial();
      return;
    }
    final validationErrors = configuration.validationErrorsFor(_platform);
    if (validationErrors.isNotEmpty) {
      RevenueCatDiagnosticsLog.configureFinished(
        success: false,
        reason: validationErrors.join(','),
      );
      if (kReleaseMode) {
        throw StateError(
          'Paid build has invalid RevenueCat public configuration: '
          '${validationErrors.join(', ')}',
        );
      }
      debugPrint(
        'RevenueCat: disabled — invalid public configuration '
        '(${validationErrors.join(', ')})',
      );
      _diagnostics = RevenueCatDiagnostics.initial();
      return;
    }
    final apiKey = configuration.publicSdkKeyFor(_platform);
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
      final appUserId = await _appUserIdStore.getOrCreate();
      await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.warn);
      final config = buildConfiguration(apiKey, appUserId);
      await Purchases.configure(config).timeout(billingOperationTimeout);
      Purchases.addCustomerInfoUpdateListener(_onCustomerInfo);
      _configured = true;
      _configuredAppUserId = appUserId;
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
    }
  }

  @visibleForTesting
  static PurchasesConfiguration buildConfiguration(
    String apiKey,
    String appUserId,
  ) {
    if (!RevenueCatAppUserIdStore.isValidUuid(appUserId)) {
      throw ArgumentError.value(appUserId, 'appUserId', 'must be a UUID v4');
    }
    return PurchasesConfiguration(apiKey)..appUserID = appUserId;
  }

  void _onCustomerInfo(CustomerInfo info) {
    _emit(_mapCustomerInfo(info));
  }

  void _emit(PremiumEntitlements entitlements) {
    if (_latest.isPro && !entitlements.isPro && !entitlements.canDowngrade) {
      entitlements = unavailableFrom(_latest, source: entitlements.source);
    }
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
    final activeProIds = ArchiveLoopEntitlementIds.revenueCatEntitlementIds
        .where((id) => active[id]?.isActive == true)
        .toList(growable: false);
    final pro = activeProIds.isEmpty ? null : active[activeProIds.first];
    return mapEntitlementInfo(
      entitlement: pro,
      activeProIds: activeProIds,
      requestDate: info.requestDate,
      billingConnected: _configured,
    );
  }

  @visibleForTesting
  static PremiumEntitlements mapEntitlementInfo({
    required EntitlementInfo? entitlement,
    required List<String> activeProIds,
    required String requestDate,
    required bool billingConnected,
    DateTime? now,
  }) {
    final verifiedAt = DateTime.tryParse(requestDate);
    final responseIsFresh = isVerificationFresh(
      requestDate,
      now: now ?? DateTime.now(),
    );
    // RevenueCat may return cached CustomerInfo while offline. Preserve its
    // renewal metadata, but do not let an arbitrarily old SDK cache bypass the
    // same five-day offline-access boundary used by EntitlementCache.
    final isPro =
        entitlement != null && entitlement.isActive && responseIsFresh;
    final expirationDate = DateTime.tryParse(entitlement?.expirationDate ?? '');
    final productIdentifier = entitlement?.productIdentifier;
    final isVerifiedLegacyLifetime =
        isPro &&
        productIdentifier != null &&
        MonetizationPolicy.legacyGrandfatheredProductIds.contains(
          productIdentifier,
        );
    final subscriptionState = !responseIsFresh
        ? PolicySubscriptionState.unknown
        : isVerifiedLegacyLifetime
        ? PolicySubscriptionState.legacyGrandfathered
        : entitlement?.billingIssueDetectedAt != null && isPro
        ? PolicySubscriptionState.gracePeriod
        : entitlement?.billingIssueDetectedAt != null
        ? PolicySubscriptionState.billingIssue
        : isPro && entitlement.periodType.name == 'trial'
        ? PolicySubscriptionState.trial
        : isPro
        ? PolicySubscriptionState.active
        : entitlement == null
        ? PolicySubscriptionState.free
        : PolicySubscriptionState.revoked;
    return PremiumEntitlements(
      tier: isPro ? BillingTier.pro : BillingTier.free,
      entitlementIds: isPro ? activeProIds : [],
      billingConnected: billingConnected,
      source: responseIsFresh ? 'revenuecat' : 'revenuecat_stale',
      verifiedAt: verifiedAt,
      verification: responseIsFresh
          ? EntitlementVerification.verified
          : EntitlementVerification.cached,
      expirationDate: expirationDate,
      willRenew: entitlement?.willRenew,
      unsubscribeDetectedAt: DateTime.tryParse(
        entitlement?.unsubscribeDetectedAt ?? '',
      ),
      billingIssueDetectedAt: DateTime.tryParse(
        entitlement?.billingIssueDetectedAt ?? '',
      ),
      productIdentifier: productIdentifier,
      accessKind: isVerifiedLegacyLifetime
          ? PlanKind.legacyGrandfathered
          : isPro
          ? PlanKind.pro
          : PlanKind.free,
      subscriptionState: subscriptionState,
    );
  }

  @visibleForTesting
  static PremiumEntitlements unavailableFrom(
    PremiumEntitlements latest, {
    required String source,
  }) => latest.copyWith(
    billingConnected: false,
    source: source,
    verification: latest.isPro
        ? EntitlementVerification.cached
        : EntitlementVerification.unavailable,
  );

  @visibleForTesting
  static bool isVerificationFresh(String requestDate, {required DateTime now}) {
    final verifiedAt = DateTime.tryParse(requestDate);
    if (verifiedAt == null) return false;
    final age = now.toUtc().difference(verifiedAt.toUtc());
    return !age.isNegative && age < maxOfflineProAge;
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

  @override
  Future<Offerings?> fetchOfferings() async {
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
      throw PurchaseFailure(
        PurchaseFailureKind.productUnavailable,
        cause: BillingUnavailableException(),
      );
    }
    if (!_isPurchasablePackageType(package.packageType)) {
      throw PurchaseFailure(
        PurchaseFailureKind.productUnavailable,
        cause: StateError('Only monthly and annual packages can be purchased'),
      );
    }
    try {
      final result = await withBillingTimeoutRequired(
        Purchases.purchase(PurchaseParams.package(package)),
        label: 'purchasePackage',
      );
      final mapped = _mapCustomerInfo(result.customerInfo);
      _emit(mapped);
      return mapped;
    } on Object catch (error) {
      throw PurchaseFailureMapper.from(error);
    }
  }

  static bool _isPurchasablePackageType(PackageType type) {
    final kind = switch (type) {
      PackageType.monthly => 'monthly',
      PackageType.annual => 'annual',
      PackageType.lifetime => 'lifetime',
      _ => type.name,
    };
    return MonetizationPolicy.currentOfferingPackageKinds.contains(kind) &&
        !MonetizationPolicy.blockedCurrentPackageKinds.contains(kind);
  }

  @override
  Future<PremiumEntitlements> restorePurchases() async {
    if (!_configured) {
      throw BillingUnavailableException();
    }
    final configuredAppUserId = _configuredAppUserId;
    final activeAppUserId = await Purchases.appUserID;
    if (!identityAllowsRestore(configuredAppUserId, activeAppUserId)) {
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

  @visibleForTesting
  static bool identityAllowsRestore(String? configured, String active) =>
      configured != null && configured == active;

  /// iOS StoreKit sync — refreshes local receipt state before reading entitlements.
  @override
  Future<PremiumEntitlements> syncAndRefreshEntitlements() async {
    if (!_configured) {
      final unavailable = unavailableFrom(
        _latest,
        source: 'revenuecat_not_configured',
      );
      _emit(unavailable);
      return unavailable;
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
      final unavailable = unavailableFrom(
        _latest,
        source: 'revenuecat_not_configured',
      );
      _emit(unavailable);
      return unavailable;
    }
    try {
      final info = await withBillingTimeout(
        Purchases.getCustomerInfo(),
        label: 'refreshEntitlements',
      );
      if (info == null) {
        debugPrint('RevenueCat refresh: unavailable — retaining latest state');
        final unavailable = unavailableFrom(
          _latest,
          source: 'revenuecat_refresh_unavailable',
        );
        _emit(unavailable);
        return unavailable;
      }
      final mapped = _mapCustomerInfo(info);
      _emit(mapped);
      return mapped;
    } catch (e) {
      debugPrint('RevenueCat refresh: $e — retaining latest state');
      final unavailable = unavailableFrom(
        _latest,
        source: 'revenuecat_refresh_error',
      );
      _emit(unavailable);
      return unavailable;
    }
  }

  @override
  Future<void> logIn(String appUserId) async {
    if (!_configured) return;
    try {
      final result = await Purchases.logIn(appUserId);
      _configuredAppUserId = await Purchases.appUserID;
      _emit(_mapCustomerInfo(result.customerInfo));
    } catch (e) {
      debugPrint('RevenueCat logIn: $e');
      rethrow;
    }
  }

  @override
  Future<void> logOut() async {
    if (!_configured) return;
    try {
      final info = await Purchases.logOut();
      _configuredAppUserId = await Purchases.appUserID;
      _emit(_mapCustomerInfo(info));
    } catch (e) {
      debugPrint('RevenueCat logOut: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    _entitlementController.close();
  }
}
