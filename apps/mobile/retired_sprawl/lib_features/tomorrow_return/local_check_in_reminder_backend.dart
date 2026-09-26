import 'package:archiveme_mobile/core/notifications/journal_notification_plan.dart';
import 'package:archiveme_mobile/features/tomorrow_return/check_in_reminder_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// Local notifications for check-in reminders.
///
/// A missing plugin, denied permission, or unsupported platform reports
/// [isAvailable] as false. Scheduled alarms are restored by
/// `ScheduledNotificationBootReceiver` after reboot.
class LocalCheckInReminderBackend implements CheckInReminderBackend {
  LocalCheckInReminderBackend({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  static FlutterLocalNotificationsPlugin? sharedPlugin;
  static final List<void Function(NotificationResponse)> _responseHandlers = [];

  bool _initialized = false;
  bool _available = false;

  /// Called when the user taps a scheduled reminder (payload = checkInId).
  void Function(String payload)? onTapPayload;

  /// Additional tap handlers — e.g. curiosity loop notifications.
  static void addResponseHandler(
    void Function(NotificationResponse response) handler,
  ) {
    if (_responseHandlers.contains(handler)) return;
    _responseHandlers.add(handler);
  }

  @visibleForTesting
  static void resetResponseHandlersForTest() {
    _responseHandlers.clear();
    sharedPlugin = null;
  }

  static const String channelId = 'check_in_reminders';
  static const String channelName = 'Check reminders';
  static const String channelDescription = 'Reminders for checks you chose.';

  @override
  bool get isAvailable => _available;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwin = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const settings = InitializationSettings(
        android: android,
        iOS: darwin,
        macOS: darwin,
      );

      await _plugin.initialize(
        settings,
        onDidReceiveNotificationResponse: _handleResponse,
      );

      sharedPlugin = _plugin;

      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          channelId,
          channelName,
          description: channelDescription,
          importance: Importance.high,
        ),
      );

      _available = true;
    } catch (_) {
      _available = false;
    }
  }

  @override
  Future<bool> requestPermission() async {
    if (!_available) return false;
    try {
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) {
        return await ios.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }
      final macos = _plugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >();
      if (macos != null) {
        return await macos.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> schedule({
    required String checkInId,
    required String title,
    required String body,
    required DateTime when,
    required String payload,
  }) async {
    if (!_available) return;
    try {
      await _plugin.zonedSchedule(
        _notificationId(checkInId),
        title,
        body,
        _toTz(when),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            channelDescription: channelDescription,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
          macOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: journalAndroidScheduleMode,
        payload: payload,
      );
    } catch (_) {
      // Scheduling failures must never crash the loop.
    }
  }

  @override
  Future<void> cancel(String checkInId) async {
    if (!_available) return;
    try {
      await _plugin.cancel(_notificationId(checkInId));
    } catch (_) {}
  }

  @override
  Future<void> clearAll() async {
    if (!_available) return;
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }

  void _handleResponse(NotificationResponse response) {
    for (final handler in _responseHandlers) {
      handler(response);
    }

    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    if (payload.startsWith('curiosity_hook_v1:')) return;
    onTapPayload?.call(payload);
  }

  /// Stable, positive notification id derived from the check-in id.
  static int _notificationId(String checkInId) =>
      checkInId.hashCode & 0x7fffffff;

  /// Builds an absolute scheduled instant from a local wall-clock [when].
  static tz.TZDateTime _toTz(DateTime when) {
    final now = tz.TZDateTime.now(tz.local);
    final delta = when.difference(DateTime.now());
    return now.add(delta.isNegative ? Duration.zero : delta);
  }
}
