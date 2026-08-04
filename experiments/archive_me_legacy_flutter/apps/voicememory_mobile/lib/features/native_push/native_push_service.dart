import '../../push/fcm_service.dart';

/// Facade for native push verification — delegates to [FcmService] (FCM only).
class NativePushService {
  NativePushService(this.fcm);

  final FcmService fcm;

  Future<void> initialize() => fcm.initialize();

  Future<bool> requestPermission() => fcm.requestPermission();

  Future<Map<String, dynamic>> sendBackendTestPush({
    required String targetRoute,
  }) => fcm.sendBackendTestPush(targetRoute: targetRoute);
}
