import 'dart:io';

import 'package:archiveme_mobile/features/memos/archive_home_host.dart';
import 'package:archiveme_mobile/features/memos/life_memo_background.dart';
import 'package:archiveme_mobile/features/memos/life_memo_generator.dart';
import 'package:archiveme_mobile/features/memos/life_memo_schedule.dart';
import 'package:archiveme_mobile/features/memos/life_memo_store.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_022_life_memos.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test('Sunday 20:00 is the next weekly slot', () {
    final before = DateTime(2026, 9, 27, 19);
    expect(before.weekday, DateTime.sunday);
    expect(
      LifeMemoSchedule.upcomingSundayAt20(before),
      DateTime(2026, 9, 27, 20),
    );
    expect(
      LifeMemoSchedule.initialDelay(before),
      const Duration(hours: 1),
    );

    final after = DateTime(2026, 9, 27, 21);
    expect(
      LifeMemoSchedule.upcomingSundayAt20(after),
      DateTime(2026, 10, 4, 20),
    );
    expect(LifeMemoSchedule.currentSlot(after), DateTime(2026, 9, 27, 20));
    expect(
      LifeMemoSchedule.isMonthlySlot(DateTime(2026, 9, 6, 20)),
      isTrue,
    );
  });

  test('the Sunday task is registered every 7 days', () async {
    Duration? seenFrequency;
    Duration? seenDelay;
    await LifeMemoWorkScheduler.registerSundayTask(
      now: DateTime(2026, 9, 23, 10),
      register:
          ({required frequency, required initialDelay}) async {
            seenFrequency = frequency;
            seenDelay = initialDelay;
          },
    );
    expect(seenFrequency, const Duration(days: 7));
    expect(seenDelay, isNotNull);
    expect(seenDelay!.inHours, greaterThan(0));
  });

  test('a week and a month produce the four memo sections', () {
    final slot = DateTime(2026, 9, 27, 20);
    final entries = [
      MemoSourceEntry(
        id: 'old',
        createdAt: DateTime(2026, 9, 1, 9),
        transcript: 'I want to walk more when evenings get quiet',
      ),
      MemoSourceEntry(
        id: 'recent',
        createdAt: DateTime(2026, 9, 25, 9),
        transcript: 'A calm grateful walk with Ada',
      ),
      MemoSourceEntry(
        id: 'again',
        createdAt: DateTime(2026, 9, 26, 9),
        transcript: 'Another calm walk after a tired afternoon',
      ),
    ];
    final entities = [
      MemoSourceEntity(
        name: 'walk more',
        category: 'goals',
        createdAt: DateTime(2026, 9, 1, 9),
      ),
      MemoSourceEntity(
        name: 'Ada',
        category: 'people',
        createdAt: DateTime(2026, 9, 25, 9),
      ),
    ];

    final weekly = LifeMemoGenerator.generate(
      windowEnd: slot,
      period: LifeMemoPeriod.weekly,
      entries: entries,
      entities: entities,
    );
    expect(weekly.markdown, contains('## Key Achievements'));
    expect(weekly.markdown, contains('## Recurring Themes & Triggers'));
    expect(weekly.markdown, contains('## Emotional Health Summary'));
    expect(weekly.markdown, contains('## Open Action Items'));
    expect(weekly.markdown, contains('Ada'));
    expect(weekly.markdown, contains('calm grateful walk'));
    expect(weekly.markdown, isNot(contains('walk more')));
    expect(weekly.evidenceEntryIds, ['recent', 'again']);

    final monthly = LifeMemoGenerator.generate(
      windowEnd: slot,
      period: LifeMemoPeriod.monthly,
      entries: entries,
      entities: entities,
    );
    expect(monthly.markdown, contains('walk more'));
    expect(monthly.evidenceEntryIds, contains('old'));

    final due = LifeMemoGenerator.generateDue(
      now: DateTime(2026, 9, 6, 20),
      entries: entries,
      entities: entities,
    );
    expect(due.map((memo) => memo.period), [
      LifeMemoPeriod.weekly,
      LifeMemoPeriod.monthly,
    ]);
  });

  test('memos round-trip through life_memos', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final path =
        '${Directory.systemTemp.path}/life_memos_${DateTime.now().microsecondsSinceEpoch}.db';
    final db = await databaseFactory.openDatabase(path);
    await Migration022LifeMemos().up(db);
    final memo = LifeMemoGenerator.generate(
      windowEnd: DateTime(2026, 9, 27, 20),
      period: LifeMemoPeriod.weekly,
      entries: [
        MemoSourceEntry(
          id: 'recent',
          createdAt: DateTime(2026, 9, 25, 9),
          transcript: 'A calm walk',
        ),
      ],
      entities: const [],
    );
    await LifeMemoStore.save(db, memo);
    final loaded = await LifeMemoStore.list(db);
    expect(loaded.single.id, memo.id);
    expect(loaded.single.markdown, contains('Key Achievements'));
    expect(loaded.single.evidenceEntryIds, ['recent']);
    await db.close();
  });

  testWidgets('Life Memos tab renders Markdown and shares it', (tester) async {
    LifeMemo? shared;
    final memo = LifeMemoGenerator.generate(
      windowEnd: DateTime(2026, 9, 27, 20),
      period: LifeMemoPeriod.weekly,
      entries: [
        MemoSourceEntry(
          id: 'recent',
          createdAt: DateTime(2026, 9, 25, 9),
          transcript: 'A calm grateful walk',
        ),
      ],
      entities: const [],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ArchiveHomeHost(
          archive: const Text('Archive body'),
          memos: [memo],
          onShare: (item) async {
            shared = item;
          },
        ),
      ),
    );
    expect(find.text('Archive body'), findsOneWidget);

    await tester.tap(find.byKey(const Key('life_memos_tab')));
    await tester.pumpAndSettle();

    expect(find.text('Key Achievements'), findsOneWidget);
    expect(find.text('Emotional Health Summary'), findsOneWidget);
    expect(find.text('· View evidence', skipOffstage: false), findsOneWidget);

    final share = find.byKey(Key('life_memo_share_${memo.id}'));
    await tester.ensureVisible(share);
    await tester.tap(share);
    await tester.pump();
    expect(shared?.id, memo.id);
  });
}
