import 'dart:io';

import 'package:archiveme_mobile/features/analytics/capture_consistency.dart';
import 'package:archiveme_mobile/features/analytics/capture_consistency_heatmap.dart';
import 'package:archiveme_mobile/features/analytics/contribution_calendar.dart';
import 'package:archiveme_mobile/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  final today = DateTime(2026, 9, 23);

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('daily counts ignore deleted rows and deepen by volume', () async {
    final path =
        '${Directory.systemTemp.path}/consistency_${DateTime.now().microsecondsSinceEpoch}.db';
    final db = await databaseFactory.openDatabase(path);
    addTearDown(() async {
      await db.close();
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
    });
    await db.execute('''
      CREATE TABLE journal_entries (
        id TEXT PRIMARY KEY,
        created_at INTEGER NOT NULL,
        deleted_at INTEGER,
        transcript TEXT NOT NULL
      )
    ''');
    Future<void> insert(String id, DateTime at, {int? deletedAt}) {
      return db.insert('journal_entries', {
        'id': id,
        'created_at': at.millisecondsSinceEpoch,
        'deleted_at': deletedAt,
        'transcript': 'note',
      });
    }

    await insert('a', DateTime(2026, 9, 23, 9));
    await insert('b', DateTime(2026, 9, 23, 18));
    await insert('c', DateTime(2026, 9, 22, 8));
    await insert('gone', DateTime(2026, 9, 23, 12), deletedAt: 1);

    final counts = await CaptureConsistencyStore.dailyCounts(db);
    expect(counts['2026-09-23'], 2);
    expect(counts['2026-09-22'], 1);
    expect(counts.containsKey('gone'), isFalse);
    expect(captureStreak(counts, today), 2);
    expect(captureVolumeColor(0), AppTokens.neutral200);
    expect(captureVolumeColor(1), AppTokens.primary200);
    expect(captureVolumeColor(6), AppTokens.primary800);
    expect(captureVolumeColor(6), isNot(captureVolumeColor(1)));
  });

  test('an empty today still continues yesterday\'s streak', () {
    expect(
      captureStreak({'2026-09-22': 1, '2026-09-21': 3}, today),
      2,
    );
    expect(captureStreak(const {}, today), 0);
  });

  testWidgets('the grid shows the streak without blocking the frame', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CaptureConsistencyHeatmap(
            today: today,
            loadCounts: () async => {'2026-09-23': 2, '2026-09-22': 1},
          ),
        ),
      ),
    );
    expect(find.text('2 days in a row'), findsNothing);
    await tester.pump();

    expect(find.text('2 days in a row'), findsOneWidget);
    expect(find.byType(ContributionCalendar), findsOneWidget);

    final calendar = tester.renderObject<RenderContributionCalendar>(
      find.byType(ContributionCalendar),
    );
    final origin = calendar.localToGlobal(Offset.zero);
    await tester.tapAt(
      origin + calendar.calendarLayout.rectFor(today).center,
    );
    await tester.pump();
    expect(find.text('2 moments on 23 Sep'), findsOneWidget);
  });
}
