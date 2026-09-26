import 'package:archiveme_mobile/features/settings/services/notification_service.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Five taps on the settings version, or a `DEBUG_MODE` launch flag.
class NotificationDebugAccess {
  NotificationDebugAccess._();

  static const unlockTaps = 5;
  static const debugMode = bool.fromEnvironment(
    'DEBUG_MODE',
    defaultValue: false,
  );

  static int taps = 0;

  static bool registerTap() {
    if (debugMode) return true;
    taps += 1;
    if (taps < unlockTaps) return false;
    taps = 0;
    return true;
  }

  static void reset() => taps = 0;
}

/// Instant Sunday recap and On This Day notification checks.
class DebugMenuView extends StatefulWidget {
  const DebugMenuView({
    this.onWeekly,
    this.onThisDay,
    this.onPending,
    this.openSettings,
    super.key,
  });

  final Future<void> Function()? onWeekly;
  final Future<void> Function()? onThisDay;
  final Future<void> Function()? onPending;
  final Future<void> Function()? openSettings;

  @override
  State<DebugMenuView> createState() => _DebugMenuViewState();
}

class _DebugMenuViewState extends State<DebugMenuView> {
  String _status = '';

  Future<void> _run(Future<void> Function() action) async {
    await action();
    if (!mounted) return;
    setState(() {
      _status = NotificationService.isNotificationPermissionGranted
          ? 'Notification requested.'
          : 'Notifications are off. Open Settings to allow them.';
    });
  }

  JournalEntry _anniversaryEntry() {
    final now = DateTime.now();
    return JournalEntry(
      id: 'debug-on-this-day',
      createdAt: DateTime(now.year - 1, now.month, now.day, 12),
      transcript: 'A moment from this day last year.',
      durationSeconds: 1,
      reflection: const Reflection(
        mood: 'steady',
        emotionalIntensity: 1,
        recurringThemes: [],
        exactLanguagePattern: '',
        concreteObservation: '',
        repeatedSignal: '',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notification debug')),
      body: ListView(
        children: [
          ListTile(
            key: const Key('debug_fire_weekly_recap'),
            title: const Text('Fire Weekly Recap Notification Now'),
            onTap: () => _run(
              widget.onWeekly ??
                  NotificationService.triggerTestWeeklyRecapNotification,
            ),
          ),
          ListTile(
            key: const Key('debug_fire_on_this_day'),
            title: const Text('Fire On This Day Notification Now'),
            onTap: () => _run(
              widget.onThisDay ??
                  () => NotificationService.triggerTestOnThisDayNotification(
                    _anniversaryEntry(),
                  ),
            ),
          ),
          ListTile(
            key: const Key('debug_log_pending'),
            title: const Text('Log Pending Scheduled Notifications'),
            onTap: () => _run(
              widget.onPending ??
                  () async {
                    await NotificationService.checkPendingNotifications();
                  },
            ),
          ),
          if (!NotificationService.isNotificationPermissionGranted)
            ListTile(
              key: const Key('debug_open_notification_settings'),
              title: const Text('Open Settings'),
              subtitle: Text(_status),
              onTap: widget.openSettings ?? openAppSettings,
            )
          else if (_status.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_status),
            ),
        ],
      ),
    );
  }
}
