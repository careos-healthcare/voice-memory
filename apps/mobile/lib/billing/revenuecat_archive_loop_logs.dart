import 'package:archiveme_mobile/billing/archive_loop_entitlement_ids.dart';
import 'package:archiveme_mobile/security/release_logger.dart';

/// Structured billing logs for archive-loop RevenueCat flows.
abstract final class ArchiveLoopRevenueCatLog {
  ArchiveLoopRevenueCatLog._();

  static void configured({required String platform, required String source}) {
    ReleaseLogger.emit(
      event: 'revenuecat_configured',
      category: ReleaseLogCategory.billing,
      fields: {'platform': platform, 'source': source},
    );
  }

  static void disabled({required String reason}) {
    ReleaseLogger.emit(
      event: 'revenuecat_disabled',
      category: ReleaseLogCategory.billing,
      severity: ReleaseLogSeverity.info,
      fields: {'reason': reason},
    );
  }

  static void productLoading() {
    ReleaseLogger.emit(
      event: 'paywall_product_loading',
      category: ReleaseLogCategory.billing,
      severity: ReleaseLogSeverity.debug,
    );
  }

  static void productLoaded({
    required String productId,
    required String price,
  }) {
    ReleaseLogger.emit(
      event: 'paywall_product_loaded',
      category: ReleaseLogCategory.billing,
      fields: {'product_id': productId, 'price': price},
    );
  }

  static void productFailed({required String reason}) {
    ReleaseLogger.emit(
      event: 'paywall_product_failed',
      category: ReleaseLogCategory.billing,
      severity: ReleaseLogSeverity.warn,
      fields: {'reason': reason},
    );
  }

  static void productUnavailableShown() {
    ReleaseLogger.emit(
      event: 'paywall_product_unavailable_shown',
      category: ReleaseLogCategory.billing,
      severity: ReleaseLogSeverity.info,
    );
  }

  static void purchaseStarted({required String productId}) {
    ReleaseLogger.emit(
      event: 'purchase_started',
      category: ReleaseLogCategory.billing,
      fields: {'product_id': productId},
    );
  }

  static void purchaseSuccess({
    required String productId,
    String entitlement = ArchiveLoopEntitlementIds.logEntitlementId,
  }) {
    ReleaseLogger.emit(
      event: 'purchase_success',
      category: ReleaseLogCategory.billing,
      fields: {'product_id': productId, 'entitlement': entitlement},
    );
  }

  static void purchaseFailed({required String reason}) {
    ReleaseLogger.emit(
      event: 'purchase_failed',
      category: ReleaseLogCategory.billing,
      severity: ReleaseLogSeverity.warn,
      fields: {'reason': reason},
    );
  }

  static void restoreStarted() {
    ReleaseLogger.emit(
      event: 'restore_started',
      category: ReleaseLogCategory.billing,
    );
  }

  static void restoreSuccess({
    String entitlement = ArchiveLoopEntitlementIds.logEntitlementId,
  }) {
    ReleaseLogger.emit(
      event: 'restore_success',
      category: ReleaseLogCategory.billing,
      fields: {'entitlement': entitlement},
    );
  }

  static void restoreEmpty() {
    ReleaseLogger.emit(
      event: 'restore_empty',
      category: ReleaseLogCategory.billing,
      severity: ReleaseLogSeverity.info,
    );
  }

  static void entitlementRefreshed({
    required String source,
    required bool active,
  }) {
    ReleaseLogger.emit(
      event: 'entitlement_refreshed',
      category: ReleaseLogCategory.billing,
      fields: {'source': source, 'active': active},
    );
  }

  static void entitlementCacheUsed({required bool active}) {
    ReleaseLogger.debugDetail(
      event: 'entitlement_cache_used',
      category: ReleaseLogCategory.billing,
      fields: {'active': active},
    );
  }

  static void entitlementPersisted({required bool active}) {
    ReleaseLogger.debugDetail(
      event: 'entitlement_persisted',
      category: ReleaseLogCategory.billing,
      fields: {'active': active},
    );
  }

  static void sandboxStep(String step) {
    ReleaseLogger.debugDetail(
      event: 'revenuecat_sandbox_step',
      category: ReleaseLogCategory.billing,
      fields: {'step': step},
    );
  }
}
