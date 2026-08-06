import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../features/native_push/native_push_verification.dart';
import 'firebase_bootstrap.dart';
import 'push_background_handler.dart';
import 'push_deep_link_handler.dart';

/// Production FCM — backend sends real pushes; no local notification simulation.
class FcmService {
  FcmService({
    required NativePushVerificationStore store,
    required this._getDeviceId,
    required this._registerToken,
    required this._sendTestPush,
  }) : _store = store,
       deepLink = PushDeepLinkHandler(store);

  final NativePushVerificationStore _store;
  final Future<String> Function() _getDeviceId;
  final PushDeepLinkHandler deepLink;
  final Future<void> Function({
    required String deviceId,
    required String platform,
    required String fcmToken,
  })
  _registerToken;
  final Future<Map<String, dynamic>> Function({
    required String deviceId,
    required String targetRoute,
  })
  _sendTestPush;

  /// Assigned only after [FirebaseBootstrap.tryInitialize] succeeds.
  FirebaseMessaging? _messaging;

  bool _initialized = false;
  String? _fcmToken;
  String? _lastPushRoute;
  DateTime? _lastReceivedAt;
  DateTime? _lastOpenedAt;

  bool get isConfigured => _initialized;
  String? get fcmToken => _fcmToken;
  String? get lastPushRoute => _lastPushRoute;
  DateTime? get lastReceivedAt => _lastReceivedAt;
  DateTime? get lastOpenedAt => _lastOpenedAt;

  String get _platform => Platform.isIOS ? 'ios' : 'android';

  FirebaseMessaging? get _messagingIfReady {
    if (!_initialized || !Firebase.apps.isNotEmpty) return null;
    return _messaging;
  }

  Future<void> _registerTokenSafe(String token) async {
    try {
      await _registerToken(
        deviceId: await _getDeviceId(),
        platform: _platform,
        fcmToken: token,
      );
    } catch (e, st) {
      debugPrint('FCM: push token registration failed — continuing: $e');
      if (kDebugMode) {
        debugPrint('$st');
      }
    }
  }

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;

    if (!FirebaseBootstrap.isConfigured) {
      debugPrint('FCM: Firebase not configured — push disabled');
      return;
    }

    final ready = await FirebaseBootstrap.tryInitialize();
    if (!ready || !Firebase.apps.isNotEmpty) {
      debugPrint('FCM: Firebase unavailable — push disabled');
      return;
    }

    try {
      _messaging = FirebaseMessaging.instance;
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      final messaging = _messaging!;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      final granted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      await _store.patchPlatform(_platform, permissionGranted: granted);

      _fcmToken = await messaging.getToken();
      if (_fcmToken != null) {
        await _registerTokenSafe(_fcmToken!);
      }

      messaging.onTokenRefresh.listen((token) async {
        _fcmToken = token;
        await _registerTokenSafe(token);
      });

      FirebaseMessaging.onMessage.listen((message) async {
        _lastReceivedAt = DateTime.now().toUtc();
        _lastPushRoute = message.data['route']?.toString();
        await deepLink.recordReceived(_platform);
      });

      FirebaseMessaging.onMessageOpenedApp.listen((message) async {
        _lastOpenedAt = DateTime.now().toUtc();
        await deepLink.handleMessageOpen(
          platform: _platform,
          data: message.data,
        );
      });

      final initial = await messaging.getInitialMessage();
      if (initial != null) {
        _lastOpenedAt = DateTime.now().toUtc();
        await deepLink.handleMessageOpen(
          platform: _platform,
          data: initial.data,
        );
      }

      _initialized = true;
    } catch (e, st) {
      _messaging = null;
      _initialized = false;
      debugPrint('FCM: messaging setup failed — push disabled: $e');
      if (kDebugMode) {
        debugPrint('$st');
      }
    }
  }

  Future<bool> requestPermission() async {
    await initialize();
    final messaging = _messagingIfReady;
    if (messaging == null) return false;
    try {
      final settings = await messaging.requestPermission();
      final granted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      await _store.patchPlatform(_platform, permissionGranted: granted);
      if (granted && _fcmToken == null) {
        _fcmToken = await messaging.getToken();
        if (_fcmToken != null) {
          await _registerTokenSafe(_fcmToken!);
        }
      }
      return granted;
    } catch (e) {
      debugPrint('FCM: requestPermission failed — $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> sendBackendTestPush({
    required String targetRoute,
  }) async {
    final deviceId = await _getDeviceId();
    final result = await _sendTestPush(
      deviceId: deviceId,
      targetRoute: targetRoute,
    );
    _lastPushRoute = targetRoute;
    return result;
  }
}
