import 'package:flutter/foundation.dart';

import 'archive_loop_entitlement_ids.dart';

abstract class ArchiveLoopRevenueCatLog {
  ArchiveLoopRevenueCatLog._();

  static void configured({
    required String platform,
    required String source,
  }) {
    debugPrint(
      'ARCHIVEME_REVENUECAT_CONFIGURED platform=$platform source=$source',
    );
  }

  static void disabled({required String reason}) {
    debugPrint('ARCHIVEME_REVENUECAT_DISABLED reason=$reason');
  }

  static void productLoading() {
    debugPrint('ARCHIVEME_PAYWALL_PRODUCT_LOADING');
  }

  static void productLoaded({
    required String productId,
    required String price,
  }) {
    debugPrint(
      'ARCHIVEME_PAYWALL_PRODUCT_LOADED productId=$productId price=$price',
    );
  }

  static void productFailed({required String reason}) {
    debugPrint('ARCHIVEME_PAYWALL_PRODUCT_FAILED reason=$reason');
  }

  static void productUnavailableShown() {
    debugPrint('ARCHIVEME_PAYWALL_PRODUCT_UNAVAILABLE_SHOWN');
  }

  static void purchaseStarted({required String productId}) {
    debugPrint('ARCHIVEME_PURCHASE_STARTED productId=$productId');
  }

  static void purchaseSuccess({
    required String productId,
    String entitlement = ArchiveLoopEntitlementIds.logEntitlementId,
  }) {
    debugPrint(
      'ARCHIVEME_PURCHASE_SUCCESS productId=$productId entitlement=$entitlement',
    );
  }

  static void purchaseFailed({required String reason}) {
    debugPrint('ARCHIVEME_PURCHASE_FAILED reason=$reason');
  }

  static void restoreStarted() {
    debugPrint('ARCHIVEME_RESTORE_STARTED');
  }

  static void restoreSuccess({
    String entitlement = ArchiveLoopEntitlementIds.logEntitlementId,
  }) {
    debugPrint('ARCHIVEME_RESTORE_SUCCESS entitlement=$entitlement');
  }

  static void restoreEmpty() {
    debugPrint('ARCHIVEME_RESTORE_EMPTY');
  }

  static void entitlementRefreshed({
    required String source,
    required bool active,
  }) {
    debugPrint(
      'ARCHIVEME_ENTITLEMENT_REFRESHED source=$source active=$active',
    );
  }

  static void entitlementCacheUsed({required bool active}) {
    debugPrint('ARCHIVEME_ENTITLEMENT_CACHE_USED active=$active');
  }

  static void entitlementPersisted({required bool active}) {
    debugPrint('ARCHIVEME_ENTITLEMENT_PERSISTED active=$active');
  }

  static void sandboxStep(String step) {
    debugPrint('ARCHIVEME_REVENUECAT_SANDBOX_STEP step=$step');
  }
}
