import 'package:archiveme_mobile/features/curiosity_loop/models/curiosity_hook.dart';
import 'package:archiveme_mobile/features/curiosity_loop/yesterdays_snapshot_copy.dart';
import 'package:archiveme_mobile/features/tomorrow_return/local_check_in_reminder_backend.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Typed payload embedded in curiosity loop notification taps.
abstract final class CuriosityNotificationPayload {
  CuriosityNotificationPayload._();

  static const _prefix = 'curiosity_hook_v1:';

  static String encode(String hookId) {
    final trimmed = hookId.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(hookId, 'hookId', 'must not be empty');
    }
    return '$_prefix$trimmed';
  }

  static String? decodeHookId(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    if (!payload.startsWith(_prefix)) return null;
    final hookId = payload.substring(_prefix.length).trim();
    return hookId.isEmpty ? null : hookId;
  }
}

/// Local notification scheduler for curiosity retention loops.
///
/// Wraps [FlutterLocalNotificationsPlugin] with crash-safe initialization and
/// scheduling — failures never propagate to callers.
class CuriosityNotificationScheduler {
  CuriosityNotificationScheduler({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const channelId = 'curiosity_retention_loops';
  static const channelName = 'Curiosity return loops';
  static const channelDescription =
      "Reminders to carry yesterday's thread forward.";

  static const defaultScheduleAfter = Duration(hours: 24);

  static CuriosityNotificationScheduler? _shared;

  static CuriosityNotificationScheduler instance() =>
      _shared ??= CuriosityNotificationScheduler();

  final FlutterLocalNotificationsPlugin _plugin;

  bool _initialized = false;
  bool _available = false;
  void Function(NotificationResponse)? _responseHandler;

  /// Called when the user taps a scheduled curiosity notification.
  void Function(String hookId)? onTapHookId;

  bool get isAvailable => _available;

  FlutterLocalNotificationsPlugin get _activePlugin =>
      LocalCheckInReminderBackend.sharedPlugin ?? _plugin;

  /// Prepares the plugin and Android/iOS notification channels.
  ///
  /// Safe to call multiple times; never throws.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      tz_data.initializeTimeZones();

      final sharedPlugin = LocalCheckInReminderBackend.sharedPlugin;
      if (sharedPlugin == null) {
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

        _responseHandler ??= _handleResponse;
        await _plugin.initialize(
          settings: settings,
          onDidReceiveNotificationResponse: _responseHandler,
        );
      } else {
        _responseHandler ??= _handleResponse;
        LocalCheckInReminderBackend.addResponseHandler(_responseHandler!);
      }

      final androidPlugin = _activePlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          channelId,
          channelName,
          description: channelDescription,
        ),
      );

      _available = true;
    } catch (_) {
      _available = false;
    }
  }

  /// Reads a curiosity hook id when the app was launched from a notification.
  Future<String?> readColdStartHookId() async {
    if (!_available) return null;
    try {
      final details = await _activePlugin.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp != true) return null;
      return CuriosityNotificationPayload.decodeHookId(
        details?.notificationResponse?.payload,
      );
    } catch (_) {
      return null;
    }
  }

  /// Requests OS notification permission when the plugin is available.
  ///
  /// Returns `false` when unavailable, denied, or when the platform call fails.
  Future<bool> requestPermissions() async {
    if (!_available) return false;
    try {
      final ios = _activePlugin
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

      final android = _activePlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }

      final macos = _activePlugin
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

  /// Schedules a curiosity reminder at [hook.createdAt] + [scheduleAfter].
  ///
  /// Returns `false` when unavailable, the hook is invalid, or the fire time
  /// is already in the past.
  ///
  /// Pass [promptBody] to display a synthesized prompt instead of
  /// [CuriosityHook.dynamicPrompt].
  Future<bool> scheduleCuriosityNotification(
    CuriosityHook hook, {
    Duration scheduleAfter = defaultScheduleAfter,
    String? promptBody,
  }) async {
    if (!_available) return false;

    final hookId = hook.id.trim();
    final body = (promptBody ?? hook.dynamicPrompt).trim();
    if (hookId.isEmpty || body.isEmpty) return false;

    final when = hook.createdAt.toLocal().add(scheduleAfter);
    if (!when.isAfter(DateTime.now())) return false;

    try {
      final payload = CuriosityNotificationPayload.encode(hookId);
      await _activePlugin.zonedSchedule(
        id: _notificationId(hookId),
        title: YesterdaysSnapshotCopy.hookEyebrow,
        body: body,
        scheduledDate: _toTz(when),
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
        payload: payload,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Cancels a previously scheduled curiosity notification for [hookId].
  Future<void> cancelCuriosityNotification(String hookId) async {
    if (!_available) return;
    final trimmed = hookId.trim();
    if (trimmed.isEmpty) return;
    try {
      await _activePlugin.cancel(id: _notificationId(trimmed));
    } catch (_) {}
  }

  void _handleResponse(NotificationResponse response) {
    final hookId = CuriosityNotificationPayload.decodeHookId(response.payload);
    if (hookId == null) return;
    onTapHookId?.call(hookId);
  }

  static int _notificationId(String hookId) => hookId.hashCode & 0x7fffffff;

  static tz.TZDateTime _toTz(DateTime when) {
    final now = tz.TZDateTime.now(tz.local);
    final delta = when.difference(DateTime.now());
    return now.add(delta.isNegative ? Duration.zero : delta);
  }

  /// Resets the shared singleton — test only.
  static void resetForTest() {
    _shared = null;
  }
}