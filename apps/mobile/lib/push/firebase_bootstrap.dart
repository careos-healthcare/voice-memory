import 'package:archiveme_mobile/push/fcm_log.dart';
import 'package:archiveme_mobile/push/firebase_options.dart';
import 'package:flutter/foundation.dart';

/// Firebase is not linked. Push startup is a no-op so the app never
/// initializes a Firebase app or collects a device identifier.
class FirebaseBootstrap {
  FirebaseBootstrap._();

  static bool get isConfigured => FirebaseOptionsConfig.isConfigured;

  static bool get isInitialized => false;

  static Future<bool> tryInitialize() async {
    if (kIsWeb) return false;
    FcmLog.disabled(reason: 'firebase_removed');
    return false;
  }
}
