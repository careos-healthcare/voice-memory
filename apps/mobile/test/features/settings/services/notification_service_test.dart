import 'package:archiveme_mobile/features/settings/services/notification_service.dart';
import 'package:archiveme_mobile/features/settings/views/debug_menu_view.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  Future<PermissionStatus> granted() async => PermissionStatus.granted;

  setUp(() {
    NotificationService.isNotificationPermissionGranted = true;
    NotificationService.pendingOnThisDay = false;
    NotificationService.scheduledAt.clear();
    WeeklyRecapNotificationService.pendingOpen = false;
    WeeklyRecapNotificationService.onRouteRequested = null;
    NotificationDebugAccess.reset();
  });

  JournalEntry entryOn(DateTime createdAt) {
    return JournalEntry(
      id: 'anniversary',
      createdAt: createdAt,
      transcript: 'Walked home in the rain.',
      durationSeconds: 12,
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

  test('a Wednesday schedules the upcoming Sunday at 18:00', () async {
    DateTime? booked;
    final when = await NotificationService.scheduleWeeklyRecap(
      now: DateTime(2026, 9, 23, 10),
      requestPermission: granted,
      book: ({required title, required when, required payload}) async {
        booked = when;
        expect(title, 'Your week in your own words');
        expect(payload, 'weekly-recap');
      },
    );

    expect(when, DateTime(2026, 9, 27, 18));
    expect(booked, DateTime(2026, 9, 27, 18));
  });

  test('Sunday after 18:00 schedules the following Sunday', () async {
    final when = await NotificationService.scheduleWeeklyRecap(
      now: DateTime(2026, 9, 27, 19),
      requestPermission: granted,
      book: ({required title, required when, required payload}) async {},
    );

    expect(when, DateTime(2026, 10, 4, 18));
  });

  test('an entry from one year ago is scheduled today at 09:00', () async {
    final now = DateTime(2026, 9, 26, 8);
    final when = await NotificationService.scheduleOnThisDay(
      entry: entryOn(DateTime(2025, 9, 26, 15, 30)),
      now: now,
      requestPermission: granted,
      book: ({required title, required when, required payload}) async {
        expect(payload, 'on-this-day');
      },
    );

    expect(when, DateTime(2026, 9, 26, 9));
  });

  test('a permanent denial is logged and blocks scheduling', () async {
    var booked = false;
    final when = await NotificationService.scheduleWeeklyRecap(
      now: DateTime(2026, 9, 23, 10),
      requestPermission: () async => PermissionStatus.permanentlyDenied,
      book: ({required title, required when, required payload}) async {
        booked = true;
      },
    );

    expect(when, isNull);
    expect(booked, isFalse);
    expect(NotificationService.isNotificationPermissionGranted, isFalse);
  });

  test('a test recap uses the weekly title and payload', () async {
    int? shownId;
    String? shownTitle;
    String? shownPayload;
    await NotificationService.triggerTestWeeklyRecapNotification(
      requestPermission: granted,
      show:
          ({
            required int id,
            required String title,
            required String body,
            required String payload,
          }) async {
            shownId = id;
            shownTitle = title;
            shownPayload = payload;
          },
    );

    expect(shownId, NotificationService.weeklyId);
    expect(shownTitle, 'Your week in your own words');
    expect(shownPayload, 'weekly-recap');
  });

  test('pending notifications print id and delivery time', () async {
    NotificationService.scheduledAt[7101] = DateTime(2026, 9, 27, 18);
    final lines = <String>[];
    final printed = await NotificationService.checkPendingNotifications(
      readPending: () async => [
        const PendingNotificationRequest(
          7101,
          'Your week in your own words',
          'Open your week.',
          'weekly-recap',
        ),
      ],
      log: lines.add,
    );

    expect(printed.single, contains('id=7101'));
    expect(printed.single, contains('2026-09-27T18:00:00'));
    expect(lines, printed);
  });

  test('five version taps unlock the debug menu', () {
    expect(NotificationDebugAccess.registerTap(), isFalse);
    expect(NotificationDebugAccess.registerTap(), isFalse);
    expect(NotificationDebugAccess.registerTap(), isFalse);
    expect(NotificationDebugAccess.registerTap(), isFalse);
    expect(NotificationDebugAccess.registerTap(), isTrue);
  });

  testWidgets('debug menu buttons fire the injected checks', (tester) async {
    var weekly = 0;
    var day = 0;
    var pending = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: DebugMenuView(
          onWeekly: () async => weekly += 1,
          onThisDay: () async => day += 1,
          onPending: () async => pending += 1,
        ),
      ),
    );

    await tester.tap(find.text('Fire Weekly Recap Notification Now'));
    await tester.tap(find.text('Fire On This Day Notification Now'));
    await tester.tap(find.text('Log Pending Scheduled Notifications'));
    await tester.pump();

    expect(weekly, 1);
    expect(day, 1);
    expect(pending, 1);
  });
}
