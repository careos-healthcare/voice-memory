import 'package:archiveme_mobile/push/fcm_log.dart';
import 'package:archiveme_mobile/push/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Safe Firebase Core startup — never throws; push can be disabled without crashing the app.
class FirebaseBootstrap {
  FirebaseBootstrap._();

  /// True when dart-define Firebase keys are present for this platform.
  static bool get isConfigured => FirebaseOptionsConfig.isConfigured;

  /// Whether [Firebase.initializeApp] completed for the default app.
  static bool get isInitialized => Firebase.apps.isNotEmpty;

  /// Initializes Firebase when configured. Returns false if skipped or failed.
  static Future<bool> tryInitialize() async {
    if (kIsWeb) return false;

    if (Firebase.apps.isNotEmpty) {
      return true;
    }

    final options = FirebaseOptionsConfig.currentPlatform;
    if (options == null) {
      FcmLog.disabled(reason: 'firebase_options_missing');
      return false;
    }

    try {
      await Firebase.initializeApp(options: options);
    } catch (e, stackTrace) {
      FcmLog.initializeFailed(error: e, stackTrace: stackTrace);
      return false;
    }

    if (Firebase.apps.isEmpty) {
      FcmLog.disabled(reason: 'firebase_app_list_empty');
      return false;
    }

    return true;
  }
}