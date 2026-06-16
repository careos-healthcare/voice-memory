import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'firebase_options.dart';

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
      debugPrint(
        'FCM: Firebase not configured (missing dart-define / google-services setup) — '
        'push disabled',
      );
      return false;
    }

    try {
      await Firebase.initializeApp(options: options);
    } catch (e, st) {
      debugPrint(
        'FCM: Firebase.initializeApp failed (check google-services.json on Android) — '
        'push disabled: $e',
      );
      if (kDebugMode) {
        debugPrint('$st');
      }
      return false;
    }

    if (Firebase.apps.isEmpty) {
      debugPrint(
        'FCM: Firebase app list empty after initializeApp — push disabled',
      );
      return false;
    }

    return true;
  }
}
