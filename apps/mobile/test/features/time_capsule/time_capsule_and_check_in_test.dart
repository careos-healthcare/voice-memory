import 'package:archiveme_mobile/core/user/progressive_disclosure.dart';
import 'package:archiveme_mobile/features/daily_check_in/check_in_belief_correlation.dart';
import 'package:archiveme_mobile/features/daily_check_in/daily_check_in_card.dart';
import 'package:archiveme_mobile/features/daily_check_in/daily_check_in_store.dart';
import 'package:archiveme_mobile/features/time_capsule/time_capsule_seal.dart';
import 'package:archiveme_mobile/features/time_capsule/time_capsule_seal_store.dart';
import 'package:archiveme_mobile/models/daily_check_in.dart';
import 'package:archiveme_mobile/models/time_capsule_lock.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../storage/sqlite/support/sqlite_migration_test_harness.dart';

void main() {
  configureSqliteMigrationTests();

  test('sealed capsule stays locked until the date or the milestone', () {
    final evaluation = TimeCapsuleSealEvaluation.evaluate(
      lock: TimeCapsuleLock(
        isTimeCapsule: true,
        unlockDateMillis: DateTime.utc(2026, 10).millisecondsSinceEpoch,
        unlockMilestoneEntryCount: 8,
      ),
      milestones: const UserMilestoneSnapshot(
        journalEntryCount: 3,
        daysActive: 2,
        activeDayKeys: {'2026-09-20', '2026-09-21'},
      ),
      now: DateTime.utc(2026, 9, 21),
    );

    expect(evaluation.locked, isTrue);
    expect(evaluation.daysRemaining, 10);
    expect(evaluation.entriesRemaining, 5);
    expect(evaluation.badgeLabel, contains('10 days'));
    expect(evaluation.badgeLabel, contains('5 more moments'));
  });

  testWidgets('locked countdown badge is shown while criteria are unmet', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: TimeCapsuleSealCard(
            lock: TimeCapsuleLock(
              isTimeCapsule: true,
              unlockDateMillis: DateTime.utc(2026, 10).millisecondsSinceEpoch,
              unlockMilestoneEntryCount: 8,
            ),
            milestones: const UserMilestoneSnapshot(
              journalEntryCount: 3,
              daysActive: 2,
              activeDayKeys: {'2026-09-20', '2026-09-21'},
            ),
            now: DateTime.utc(2026, 9, 21),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('time_capsule_locked_badge')), findsOneWidget);
    expect(find.textContaining('Locked'), findsOneWidget);
    expect(find.byKey(const Key('time_capsule_seal_button')), findsNothing);
  });

  test('daily check-in upserts one row per date', () async {
    final harness = SqliteMigrationTestHarness();
    final db = await harness.openLatest();
    const store = DailyCheckInStore();
    await store.save(
      db,
      DailyCheckIn(
        id: 'check-1',
        dateString: '2026-09-21',
        moodScore: 2,
        energyLevel: 2,
        habitsJson: '["walk"]',
      ),
    );
    await store.save(
      db,
      DailyCheckIn(
        id: 'check-2',
        dateString: '2026-09-21',
        moodScore: 5,
        energyLevel: 4,
        habitsJson: '["walk","sleep"]',
      ),
    );

    final rows = await store.loadAll(db);
    expect(rows, hasLength(1));
    expect(rows.single.moodScore, 5);
    expect(rows.single.energyLevel, 4);
    expect(rows.single.habitsJson, '["walk","sleep"]');
    await db.close();
  });

  test('seal writes the lock columns used by search and embeddings', () async {
    final harness = SqliteMigrationTestHarness();
    final db = await harness.openLatest();
    await db.insert('journal_entries', {
      'id': 'moment-1',
      'created_at': 1,
      'updated_at': 1,
      'transcript': 'A saved moment',
    });
    await const TimeCapsuleSealStore().seal(
      db,
      entryId: 'moment-1',
      unlockDate: DateTime.utc(2026, 12),
      milestoneEntryCount: 12,
    );

    final lock = await const TimeCapsuleSealStore().read(db, 'moment-1');
    expect(lock.isTimeCapsule, isTrue);
    expect(lock.unlockMilestoneEntryCount, 12);
    expect(
      lock.isUnlocked(nowMillis: 1, activeEntryCount: 1),
      isFalse,
    );
    await db.close();
  });

  test('background correlation compares habits with shift deltas', () async {
    final insights = await CheckInBeliefCorrelationAnalyzer.analyze(
      checkIns: [
        DailyCheckIn(
          id: 'a',
          dateString: '2026-09-20',
          moodScore: 3,
          energyLevel: 3,
          habitsJson: '["walk"]',
        ),
        DailyCheckIn(
          id: 'b',
          dateString: '2026-09-21',
          moodScore: 4,
          energyLevel: 4,
          habitsJson: '["walk"]',
        ),
        DailyCheckIn(
          id: 'c',
          dateString: '2026-09-21',
          moodScore: 2,
          energyLevel: 2,
          habitsJson: '["focus"]',
        ),
      ],
      deltas: const [
        BeliefChangeDelta(dateString: '2026-09-20', delta: 4),
        BeliefChangeDelta(dateString: '2026-09-21', delta: 8),
      ],
    );

    expect(insights, hasLength(1));
    expect(insights.single.habit, 'walk');
    expect(insights.single.sampleCount, 2);
    expect(insights.single.averageDelta, 6);
    expect(insights.single.summary, contains('walk'));
    expect(insights.single.summary, contains('+6.0'));
  });

  testWidgets('check-in pills save and surface a local insight', (
    tester,
  ) async {
    var now = DateTime(2026, 9, 21, 12);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: DailyCheckInCard(
            now: () => now,
            beliefDeltas: const [
              BeliefChangeDelta(dateString: '2026-09-21', delta: 4),
              BeliefChangeDelta(dateString: '2026-09-22', delta: 8),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('daily_check_in_habit_walk')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('daily_check_in_mood_5')));
    await tester.tap(find.byKey(const Key('daily_check_in_energy_4')));
    await tester.tap(find.byKey(const Key('daily_check_in_save')));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();

    now = DateTime(2026, 9, 22, 12);
    await tester.tap(find.byKey(const Key('daily_check_in_save')));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();

    expect(find.byKey(const Key('daily_check_in_insight')), findsOneWidget);
    expect(find.textContaining('+6.0'), findsOneWidget);
  });
}
