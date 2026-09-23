import 'dart:io';

import 'package:archiveme_mobile/features/analytics/contribution_calendar.dart';
import 'package:archiveme_mobile/features/analytics/timeline_day_stats.dart';
import 'package:archiveme_mobile/features/analytics/timeline_heatmap_screen.dart';
import 'package:archiveme_mobile/features/metadata/ambient_metadata.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  final today = DateTime(2026, 9, 23);

  TimelineMapEntry entry({
    required String id,
    required DateTime createdAt,
    required String transcript,
    double? latitude,
    double? longitude,
  }) {
    return TimelineMapEntry(
      id: id,
      createdAt: createdAt,
      transcript: transcript,
      sentiment: entrySentiment(transcript),
      latitude: latitude,
      longitude: longitude,
    );
  }

  test('cell color deepens with count and shifts with tone', () {
    expect(dayCellColor(count: 0, sentiment: 0), const Color(0xFFE5E5E5));
    final quiet = dayCellColor(count: 1, sentiment: 0.4);
    final busy = dayCellColor(count: 6, sentiment: 0.4);
    expect(busy, isNot(quiet));
    expect(
      dayCellColor(count: 3, sentiment: -0.4),
      const Color(0xFFC47A6A),
    );
  });

  test('nearby coordinates share a pin and a day keeps its own count', () {
    final index = TimelineHeatmapIndex.fromEntries([
      entry(
        id: 'a',
        createdAt: DateTime(2026, 9, 23, 9),
        transcript: 'A calm grateful walk',
        latitude: 51.322,
        longitude: -0.204,
      ),
      entry(
        id: 'b',
        createdAt: DateTime(2026, 9, 23, 18),
        transcript: 'An anxious evening',
        latitude: 51.324,
        longitude: -0.201,
      ),
      entry(
        id: 'c',
        createdAt: DateTime(2026, 9, 22, 8),
        transcript: 'Hopeful morning',
        latitude: 40.71,
        longitude: -74,
      ),
    ]);

    expect(index.clusters, hasLength(2));
    final shared = index.clusters.singleWhere(
      (cluster) => cluster.entryIds.length == 2,
    );
    expect(shared.entryIds, ['a', 'b']);
    expect(index.days[dayKey(today)]!.count, 2);
    expect(index.days[dayKey(today)]!.meanSentiment, isNot(0));

    final day = index.matching(TimelineSelection(day: today));
    expect(day.map((item) => item.id), ['a', 'b']);
    final solo = index.clusters.singleWhere(
      (cluster) => cluster.entryIds.length == 1,
    );
    final place = index.matching(TimelineSelection(clusterId: solo.id));
    expect(place.single.id, 'c');
  });

  testWidgets('a calendar square and a map pin filter the list', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TimelineHeatmapScreen(
          today: today,
          showMapTiles: false,
          entries: [
            entry(
              id: 'harbor',
              createdAt: DateTime(2026, 9, 23, 9),
              transcript: 'Met Ada at Harbor',
              latitude: 51.322,
              longitude: -0.204,
            ),
            entry(
              id: 'sam',
              createdAt: DateTime(2026, 9, 22, 8),
              transcript: 'With Sam in Harbor',
              latitude: 51.324,
              longitude: -0.201,
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('timeline_filtered_entry_harbor')), findsOneWidget);
    expect(find.byKey(const Key('timeline_filtered_entry_sam')), findsOneWidget);

    final calendar = tester.renderObject<RenderContributionCalendar>(
      find.byType(ContributionCalendar),
    );
    final origin = calendar.localToGlobal(Offset.zero);
    await tester.tapAt(
      origin + calendar.calendarLayout.rectFor(DateTime(2026, 9, 23)).center,
    );
    await tester.pump();

    expect(find.byKey(const Key('timeline_filtered_entry_harbor')), findsOneWidget);
    expect(find.byKey(const Key('timeline_filtered_entry_sam')), findsNothing);
    expect(find.text('1 moment on 23 Sep'), findsOneWidget);

    await tester.tap(find.text('Map'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.byKey(const Key('timeline_map_cluster_51.30_-0.20')));
    await tester.pump();

    expect(find.byKey(const Key('timeline_filtered_entry_harbor')), findsOneWidget);
    expect(find.byKey(const Key('timeline_filtered_entry_sam')), findsOneWidget);
    expect(find.text('2 moments near this place'), findsOneWidget);
  });

  test('stored coordinates are read from ambient metadata', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final path =
        '${Directory.systemTemp.path}/heatmap_${DateTime.now().microsecondsSinceEpoch}.db';
    final db = await databaseFactory.openDatabase(path);
    await db.execute('''
      CREATE TABLE journal_entries (
        id TEXT PRIMARY KEY,
        created_at INTEGER NOT NULL,
        deleted_at INTEGER,
        transcript TEXT NOT NULL,
        ambient_metadata TEXT
      )
    ''');
    const metadata = AmbientMetadata(
      latitude: 51.32,
      longitude: -0.2,
      locality: 'Banstead',
    );
    await db.insert('journal_entries', {
      'id': 'kept',
      'created_at': DateTime(2026, 9, 23).millisecondsSinceEpoch,
      'deleted_at': null,
      'transcript': 'A calm walk',
      'ambient_metadata': metadata.encode(),
    });
    await db.insert('journal_entries', {
      'id': 'gone',
      'created_at': DateTime(2026, 9, 23).millisecondsSinceEpoch,
      'deleted_at': 1,
      'transcript': 'Deleted',
      'ambient_metadata': metadata.encode(),
    });

    final loaded = await TimelineHeatmapStore.load(db);
    expect(loaded, hasLength(1));
    expect(loaded.single.id, 'kept');
    expect(loaded.single.latitude, 51.32);
    expect(loaded.single.sentiment, greaterThan(0));
    await db.close();
  });
}
