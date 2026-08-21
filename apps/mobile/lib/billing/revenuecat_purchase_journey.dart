import 'dart:convert';
import 'dart:io';

import 'package:archiveme_mobile/models/entitlement.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Records a physical-device RevenueCat purchase journey for repo evidence export.
class RevenueCatPurchaseJourney {
  RevenueCatPurchaseJourney();

  bool offeringLoaded = false;
  bool purchaseCompleted = false;
  bool entitlementReceived = false;
  bool restoreCompleted = false;
  List<String> productIds = [];
  List<String> entitlementIds = [];
  String? appUserId;
  bool sdkInitialized = false;

  bool get productionPass =>
      purchaseCompleted && entitlementReceived && restoreCompleted;

  void markOfferingsLoaded(List<String> ids) {
    offeringLoaded = true;
    productIds = ids;
  }

  void markPurchaseSuccess(PremiumEntitlements entitlements) {
    purchaseCompleted = true;
    if (entitlements.isPro) {
      entitlementReceived = true;
      entitlementIds = entitlements.entitlementIds;
    }
  }

  void markRestoreSuccess(PremiumEntitlements entitlements) {
    restoreCompleted = true;
    if (entitlements.isPro) {
      entitlementReceived = true;
      entitlementIds = entitlements.entitlementIds;
    }
  }

  Future<String> exportEvidenceJson() async {
    final info = await PackageInfo.fromPlatform();
    var device = '';
    if (Platform.isIOS) {
      final ios = await DeviceInfoPlugin().iosInfo;
      device = ios.utsname.machine;
    } else if (Platform.isAndroid) {
      final android = await DeviceInfoPlugin().androidInfo;
      device = android.model;
    }

    final payload = {
      'success': productionPass,
      'device': device,
      'platform': Platform.isIOS ? 'ios' : 'android',
      'offering_loaded': offeringLoaded,
      'purchase_completed': purchaseCompleted,
      'entitlement_received': entitlementReceived,
      'restore_completed': restoreCompleted,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'sdk_initialized': sdkInitialized,
      'product_ids': productIds,
      'app_user_id': appUserId,
      'entitlement_ids': entitlementIds,
      'app_version': info.version,
      'note':
          'Commit to mobile/evidence/revenuecat_store_tested.json after sandbox purchase + restore on physical device',
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }
}