import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/features/native_push/native_push_verification.dart';
import 'package:archiveme_mobile/push/fcm_log.dart';
import 'package:archiveme_mobile/push/push_deep_link_handler.dart';
import 'package:flutter/foundation.dart';

/// Push registration stub.
///
/// `firebase_messaging` is not a v1 dependency. [V1CapabilityRegistry.notifications]
/// is false, so nothing in the default launch path calls Firebase Messaging.
class FcmService {
  FcmService({
    required NativePushVerificationStore store,
    required Future<String> Function() getDeviceId,
    required Future<void> Function({
      required String deviceId,
      required String platform,
      required String fcmToken,
    })
    registerToken,
    required this._sendTestPush,
  }) : _getDeviceId = getDeviceId,
       _registerToken = registerToken,
       deepLink = PushDeepLinkHandler(store);

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

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;
    if (!V1CapabilityRegistry.notifications) {
      FcmLog.disabled(reason: 'notifications_disabled');
      return;
    }
    // Kept so a later notifications=true build still has a registration hook
    // without linking firebase_messaging in the default launch.
    final deviceId = await _getDeviceId();
    await _registerToken(
      deviceId: deviceId,
      platform: 'unknown',
      fcmToken: '',
    );
    FcmLog.disabled(reason: 'firebase_messaging_not_linked');
  }

  Future<bool> requestPermission() async {
    await initialize();
    return false;
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
