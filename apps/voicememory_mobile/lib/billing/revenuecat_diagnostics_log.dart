import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../config/app_config.dart';
import 'revenuecat_service.dart';

/// Searchable RevenueCat diagnostics for device logs — safe for release builds.
///
/// Grep for `ARCHIVEME_REVENUECAT:` (never logs full API keys).
abstract final class RevenueCatDiagnosticsLog {
  RevenueCatDiagnosticsLog._();

  static void _log(String message) {
    debugPrint('ARCHIVEME_REVENUECAT: $message');
  }

  static String keyFingerprint(String? key) {
    if (key == null || key.isEmpty) return 'missing';
    final trimmed = key.trim();
    if (trimmed.length <= 8) return '$trimmed…';
    return '${trimmed.substring(0, 8)}…';
  }

  static void configureStarted({
    required String platform,
    required bool apiKeyPresent,
    String? apiKey,
  }) {
    _log(
      'configure started platform=$platform apiKeyPresent=$apiKeyPresent '
      'apiKeyPrefix=${keyFingerprint(apiKey)} bundleId=${AppConfig.bundleId}',
    );
  }

  static void configureFinished({required bool success, String? reason}) {
    _log('configure finished success=$success reason=${reason ?? 'none'}');
  }

  static void fetchOfferingsStarted({required bool billingConfigured}) {
    _log('fetchOfferings started billingConfigured=$billingConfigured');
  }

  static void fetchOfferingsFinished({
    required bool success,
    Offerings? offerings,
    String? error,
  }) {
    if (!success || offerings == null) {
      _log(
        'fetchOfferings finished success=false error=${error ?? 'null_offerings'}',
      );
      return;
    }

    final current = offerings.current;
    final packages = current?.availablePackages ?? const <Package>[];
    final productIds = packages
        .map((package) => package.storeProduct.identifier)
        .toList(growable: false);

    _log(
      'fetchOfferings finished success=true offeringCount=${offerings.all.length} '
      'currentOfferingId=${current?.identifier ?? 'null'} packageCount=${packages.length} '
      'productIds=${productIds.isEmpty ? 'none' : productIds.join(',')}',
    );
  }

  static void entitlementsChecked({
    required String source,
    required CustomerInfo info,
  }) {
    final activeKeys = info.entitlements.active.keys.toList()..sort();
    final pro = info.entitlements.active[RevenueCatService.proEntitlementId];
    _log(
      'entitlementsChecked source=$source expected=${RevenueCatService.proEntitlementId} '
      'proActive=${pro != null && pro.isActive} '
      'activeEntitlements=${activeKeys.isEmpty ? 'none' : activeKeys.join(',')}',
    );
  }

  static void paywallFallback({
    required String reason,
    String? error,
    bool isRetry = false,
  }) {
    _log(
      'paywallFallback reason=$reason isRetry=$isRetry error=${error ?? 'none'}',
    );
  }

  static void paywallCriticalFailure({
    required String context,
    required Object error,
  }) {
    _log('paywallCriticalFailure context=$context error=$error');
  }
}
