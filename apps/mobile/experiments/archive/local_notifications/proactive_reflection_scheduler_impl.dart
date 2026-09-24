import 'package:archiveme_mobile/features/reflection/proactive_reflection_scheduler.dart';
import 'package:archiveme_mobile/features/reflection/reflection_prompts.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Plugin delivery for [ProactiveReflectionScheduler].
///
/// Not linked in the V1 beta. Re-enable with the checklist in README.md.
class FlutterLocalNotificationsReflectionBackend
    implements ReflectionNotificationBackend {
  FlutterLocalNotificationsReflectionBackend({
    FlutterLocalNotificationsPlugin? plugin,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const channelId = 'proactive_reflection';
  static const channelName = 'Reflection prompts';
  static const channelDescription = 'Daily and weekly reflection prompts.';

  final FlutterLocalNotificationsPlugin _plugin;
  var _ready = false;

  Future<void> initialize() async {
    if (_ready) return;
    tz_data.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: android,
        iOS: darwin,
        macOS: darwin,
      ),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            channelId,
            channelName,
            description: channelDescription,
          ),
        );
    _ready = true;
  }

  @override
  Future<void> cancelPending() async {}

  @override
  Future<void> schedule(ScheduledReflectionNotification notification) async {
    if (!_ready) await initialize();
    final when = tz.TZDateTime.from(notification.scheduledDate, tz.local);
    await _plugin.zonedSchedule(
      id: notification.id,
      title: notification.title,
      body: notification.body,
      scheduledDate: when,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: notification.payload,
      matchDateTimeComponents: notification.matchComponents == 'time'
          ? DateTimeComponents.time
          : DateTimeComponents.dayOfWeekAndTime,
    );
  }
}
