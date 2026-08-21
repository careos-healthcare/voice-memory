import 'dart:io' show Platform;

import 'package:archiveme_mobile/push/firebase_bootstrap.dart' show FirebaseBootstrap;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Firebase options from dart-define (no secrets in repo).
///
/// Android also expects `android/app/google-services.json` when using the
/// Google Services Gradle plugin. This project initializes via dart-define
/// only; if native config is missing, [FirebaseBootstrap.tryInitialize] fails
/// safely and push is disabled.
class FirebaseOptionsConfig {
  static bool get isConfigured {
    const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
    const appId = String.fromEnvironment('FIREBASE_APP_ID');
    const projectId = String.fromEnvironment(
      'FIREBASE_PROJECT_ID',
    );
    return apiKey.isNotEmpty && appId.isNotEmpty && projectId.isNotEmpty;
  }

  static FirebaseOptions? get currentPlatform {
    if (!isConfigured) return null;

    const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
    const appId = String.fromEnvironment('FIREBASE_APP_ID');
    const projectId = String.fromEnvironment(
      'FIREBASE_PROJECT_ID',
    );
    const messagingSenderId = String.fromEnvironment(
      'FIREBASE_MESSAGING_SENDER_ID',
    );
    const iosBundleId = String.fromEnvironment(
      'FIREBASE_IOS_BUNDLE_ID',
      defaultValue: 'com.voicememory.mobile',
    );

    if (kIsWeb) return null;

    if (Platform.isIOS) {
      return const FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        projectId: projectId,
        messagingSenderId: messagingSenderId,
        iosBundleId: iosBundleId,
      );
    }
    if (Platform.isAndroid) {
      return const FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        projectId: projectId,
        messagingSenderId: messagingSenderId,
      );
    }
    return null;
  }
}