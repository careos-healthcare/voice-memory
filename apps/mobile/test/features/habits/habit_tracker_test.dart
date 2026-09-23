import 'dart:io';

import 'package:archiveme_mobile/features/habits/goal_velocity_calculator.dart';
import 'package:archiveme_mobile/features/habits/habit_tracker_service.dart';
import 'package:archiveme_mobile/features/habits/habits_dashboard_screen.dart';
import 'package:archiveme_mobile/storage/sqlite/app_sqlite_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../storage/sqlite/support/sqlite_test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a spoken run links the habit log to that moment', () async {
    final directory = await Directory.systemTemp.createTemp('habits');
    final app = await openTestAppSqliteDatabase(
      filePath: '${directory.path}/archive.db',
    );
    addTearDown(() async {
      await app.close();
      AppSqliteDatabase.resetForTest();
    });
    final db = app.database;
    final entityId = habitEntityId('5km run');
    await db.insert('entities', {
      'id': entityId,
      'name': '5km run',
      'category': 'goals',
      'created_at': 1,
    });
    final tracker = HabitTrackerService(
      database: db,
      clock: () => DateTime(2026, 9, 23),
    );
    final run = await tracker.create(
      title: 'Morning miles',
      entityId: entityId,
    );
    final plain = await tracker.create(title: 'run');

    final linked = await tracker.detectFromMoment(
      entryId: 'moment-1',
      transcript: 'Went for a 5km run',
    );
    expect(linked.map((log) => log.habitId), containsAll([run.id, plain.id]));
    expect(linked.every((log) => log.entryId == 'moment-1'), isTrue);

    final again = await tracker.detectFromMoment(
      entryId: 'moment-1',
      transcript: 'Went for a 5km run',
    );
    expect(again, isEmpty);
    expect(await tracker.logsFor(run.id), hasLength(1));

    final wish = await tracker.detectFromMoment(
      entryId: 'moment-2',
      transcript: 'I want to run',
    );
    expect(wish, isEmpty);

    final didRun = await tracker.detectFromMoment(
      entryId: 'moment-3',
      transcript: 'Went for a run',
    );
    expect(didRun.single.habitId, plain.id);

    final manual = await tracker.logManual(run.id);
    expect(manual.entryId, isNull);
    expect(await tracker.logsFor(run.id), hasLength(2));
  });

  test('velocity covers 30 and 90 days and compares tone', () {
    final now = DateTime(2026, 9, 23);
    final habit = Habit(
      id: 'habit-run',
      title: '5km run',
      frequency: HabitFrequency.daily,
      targetCount: 1,
      createdAt: DateTime(2026, 8, 25),
    );
    final logs = [
      for (final day in [25, 32, 39, 46, 53])
        HabitLog(
          id: 'log-$day',
          habitId: habit.id,
          entryId: 'moment-$day',
          loggedAt: DateTime(2026, 8, 25).add(Duration(days: day - 25)),
        ),
    ];
    final report = GoalVelocityCalculator.report(
      habit: habit,
      logs: logs,
      now: now,
      sentimentByDay: {
        DateTime(2026, 9, 22): GoalVelocityCalculator.sentimentOf(
          'happy calm grateful',
        ),
        DateTime(2026, 9, 21): GoalVelocityCalculator.sentimentOf(
          'anxious sad tired',
        ),
      },
    );

    expect(report.days30.consistency, closeTo(5 / 30, 0.001));
    expect(report.days30.weeklyStreak, 5);
    expect(report.days30.perWeek, closeTo(5 / (30 / 7), 0.001));
    expect(report.days30.weeklyCounts, isNotEmpty);
    expect(report.days30.entryIds, contains('moment-53'));
    expect(
      report.days30.completedSentiment,
      greaterThan(report.days30.missedSentiment!),
    );
    expect(report.days90.days, 90);
    expect(report.days90.consistency, closeTo(5 / 30, 0.001));
  });

  testWidgets('the dashboard shows the streak, sparkline, and moment link', (
    tester,
  ) async {
    final now = DateTime(2026, 9, 23);
    final habit = Habit(
      id: 'habit-run',
      title: '5km run',
      frequency: HabitFrequency.daily,
      targetCount: 1,
      createdAt: DateTime(2026, 8, 25),
    );
    final window = GoalVelocityCalculator.window(
      habit: habit,
      logs: [
        HabitLog(
          id: 'log-1',
          habitId: habit.id,
          entryId: 'moment-1',
          loggedAt: DateTime(2026, 9, 22),
        ),
      ],
      sentimentByDay: const {},
      now: now,
      days: 30,
    );
    var logged = 0;
    String? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: HabitsDashboardScreen(
          cards: [
            HabitDashboardCard(
              habit: habit,
              window: window,
              momentLabels: const {'moment-1': 'Went for a 5km run'},
            ),
          ],
          onLogHabit: () => logged += 1,
          onOpenMoment: (entryId) => opened = entryId,
        ),
      ),
    );

    expect(find.byKey(const Key('habit_streak_grid')), findsOneWidget);
    expect(find.byKey(const Key('habit_velocity_sparkline')), findsOneWidget);
    expect(find.text('1-week streak'), findsOneWidget);
    expect(find.text('+ Log Habit'), findsOneWidget);

    await tester.tap(find.byKey(const Key('habit_log_action')));
    expect(logged, 1);

    await tester.tap(find.byKey(const Key('habit_moment_moment-1')));
    expect(opened, 'moment-1');

    await tester.tap(find.text('· View evidence'));
    expect(opened, 'moment-1');
  });
}
