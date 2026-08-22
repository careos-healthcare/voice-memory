import 'package:archiveme_mobile/features/tomorrow_return/check_in_reminder_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Real local-notification backend for tomorrow check-in reminders.
///
/// Everything is wrapped so a missing plugin, denied permission, or platform
/// without notifications never crashes the app — it simply reports
/// [isAvailable] as false and the service falls back to its no-op behavior.
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
      tz_data.initializeTimeZones();

      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwin = DarwinInitializationSettings(
        // Permission is requested later, only after the user chooses a check.
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
        settings: settings,
        onDidReceiveNotificationResponse: _handleResponse,
      );

      sharedPlugin = _plugin;

      final android0 = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android0?.createNotificationChannel(
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
        id: _notificationId(checkInId),
        title: title,
        body: body,
        scheduledDate: _toTz(when),
        notificationDetails: const NotificationDetails(
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
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
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
      await _plugin.cancel(id: _notificationId(checkInId));
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
  ///
  /// Anchoring to "now + remaining duration" keeps the fire time correct even
  /// when the timezone database has not been pointed at the device location.
  static tz.TZDateTime _toTz(DateTime when) {
    final now = tz.TZDateTime.now(tz.local);
    final delta = when.difference(DateTime.now());
    return now.add(delta.isNegative ? Duration.zero : delta);
  }
}