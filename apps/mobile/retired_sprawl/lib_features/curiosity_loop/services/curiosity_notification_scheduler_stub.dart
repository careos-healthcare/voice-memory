import 'package:archiveme_mobile/features/curiosity_loop/models/curiosity_hook.dart';
import 'package:archiveme_mobile/features/curiosity_loop/services/curiosity_notification_payload.dart';

/// Stub scheduler for V1 beta (`notifications = false`).
///
/// Plugin-backed implementation:
/// `experiments/archive/local_notifications/curiosity_notification_scheduler_impl.dart`
class CuriosityNotificationScheduler {
  CuriosityNotificationScheduler();

  static const defaultScheduleAfter = Duration(hours: 24);

  static CuriosityNotificationScheduler? _shared;

  static CuriosityNotificationScheduler instance() =>
      _shared ??= CuriosityNotificationScheduler();

  /// Called when the user taps a scheduled curiosity notification.
  void Function(String hookId)? onTapHookId;

  bool get isAvailable => false;

  Future<void> initialize() async {}

  Future<String?> readColdStartHookId() async => null;

  Future<bool> requestPermissions() async => false;

  Future<bool> scheduleCuriosityNotification(
    CuriosityHook hook, {
    Duration scheduleAfter = defaultScheduleAfter,
    String? promptBody,
  }) async =>
      false;

  Future<void> cancelCuriosityNotification(String hookId) async {}

  static void resetForTest() {
    _shared = null;
  }
}
