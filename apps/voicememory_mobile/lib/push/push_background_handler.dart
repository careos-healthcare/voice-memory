import 'package:firebase_messaging/firebase_messaging.dart';

import 'firebase_bootstrap.dart';

/// Background FCM handler — must be top-level.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await FirebaseBootstrap.tryInitialize();
  // Delivery recorded when app resumes; deep link handled on open.
}
