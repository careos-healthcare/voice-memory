import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

import '../models/entitlement.dart';

/// Evidence payload for mobile/evidence/restore_purchases_tested.json
class RestoreProductionEvidence {
  static Future<String> toJson({
    required bool success,
    PremiumEntitlements? entitlements,
  }) async {
    String device = '';
    if (Platform.isIOS) {
      final ios = await DeviceInfoPlugin().iosInfo;
      device = ios.utsname.machine;
    } else if (Platform.isAndroid) {
      final android = await DeviceInfoPlugin().androidInfo;
      device = android.model;
    }

    final proRestored = entitlements?.isPro == true;
    final passing = success && proRestored;

    final payload = {
      'success': passing,
      'device': device,
      'platform': Platform.isIOS ? 'ios' : 'android',
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }
}
