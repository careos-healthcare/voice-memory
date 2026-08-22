import 'package:archiveme_mobile/billing/revenuecat_service.dart';
import 'package:archiveme_mobile/config/app_config.dart';
import 'package:archiveme_mobile/security/release_logger.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Searchable RevenueCat diagnostics — safe for release builds.
abstract final class RevenueCatDiagnosticsLog {
  RevenueCatDiagnosticsLog._();

  static void _log(String message, {ReleaseLogSeverity severity = ReleaseLogSeverity.info}) {
    ReleaseLogger.emit(
      event: 'revenuecat_diagnostics',
      category: ReleaseLogCategory.billing,
      severity: severity,
      fields: {'message': message},
    );
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

  static void offeringsSnapshot({
    required bool configured,
    required int offeringCount,
    required int packageCount,
    String? currentOfferingId,
  }) {
    _log(
      'offeringsSnapshot configured=$configured offeringCount=$offeringCount '
      'packageCount=$packageCount currentOfferingId=${currentOfferingId ?? 'null'}',
      severity: ReleaseLogSeverity.debug,
    );
  }

  static void refreshUnavailableUsingFreeTier() {
    _log(
      'refreshEntitlements unavailable — using free tier',
      severity: ReleaseLogSeverity.info,
    );
  }

  static void operationFailed({
    required String operation,
    required Object error,
    StackTrace? stackTrace,
    ReleaseLogSeverity severity = ReleaseLogSeverity.warn,
  }) {
    _log('operationFailed operation=$operation error=$error', severity: severity);
    if (stackTrace != null) {
      ReleaseLogger.debugDetail(
        event: 'revenuecat_operation_failed_detail',
        category: ReleaseLogCategory.billing,
        fields: {
          'operation': operation,
          'error_type': error.runtimeType.toString(),
          'stack_trace': stackTrace.toString(),
        },
      );
    }
  }

  static void paywallFallback({
    required String reason,
    String? error,
    bool isRetry = false,
    StackTrace? stackTrace,
  }) {
    _log(
      'paywallFallback reason=$reason isRetry=$isRetry error=${error ?? 'none'}',
    );
    if (stackTrace != null) {
      ReleaseLogger.debugDetail(
        event: 'revenuecat_paywall_fallback_detail',
        category: ReleaseLogCategory.billing,
        fields: {
          'reason': reason,
          'stack_trace': stackTrace.toString(),
        },
      );
    }
  }

  static void paywallCriticalFailure({
    required String context,
    required Object error,
  }) {
    _log(
      'paywallCriticalFailure context=$context error=$error',
      severity: ReleaseLogSeverity.warn,
    );
  }

  static void externalLinkFailed({required String url}) {
    _log(
      'externalLinkFailed url=$url',
      severity: ReleaseLogSeverity.warn,
    );
  }
}