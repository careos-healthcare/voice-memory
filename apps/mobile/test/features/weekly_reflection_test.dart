import 'dart:io';

import 'package:archiveme_mobile/features/weekly_reflection/weekly_recap.dart';
import 'package:archiveme_mobile/features/weekly_reflection/weekly_recap_cache.dart';
import 'package:archiveme_mobile/features/weekly_reflection/weekly_recap_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

WeeklyRecap sampleRecap() {
  return const WeeklyRecap(
    weekKey: '2026-09-25',
    summary: 'Work kept coming back.',
    keyThemes: ['work'],
    emotionalArc: 'This week continues last week\'s thread.',
    verbatimCitations: [
      VerbatimCitation(
        text: 'the deadline moved again',
        entryId: 'entry-1',
        timestamp: '00:12',
      ),
    ],
  );
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('weekly recap card opens the detail', (tester) async {
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WeeklyRecapCard(
            recap: sampleRecap(),
            onOpen: () => opened = true,
          ),
        ),
      ),
    );
    expect(find.text('Work kept coming back.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('weekly_recap_card')));
    expect(opened, isTrue);
  });

  testWidgets('citation chip returns the recording timestamp', (tester) async {
    VerbatimCitation? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WeeklyRecapDetail(
            recap: sampleRecap(),
            onCitation: (citation) => opened = citation,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('weekly_citation_entry-1')));
    expect(opened?.timestamp, '00:12');
    expect(opened?.entryId, 'entry-1');
  });

  test('cached recap is readable without the network', () async {
    final dir = await Directory.systemTemp.createTemp('weekly_recap_');
    final cache = await WeeklyRecapCache.open('${dir.path}/recaps.db');
    await cache.save(sampleRecap());
    final loaded = await cache.read('2026-09-25');
    expect(loaded?.summary, 'Work kept coming back.');
    expect(loaded?.verbatimCitations.single.timestamp, '00:12');
    await cache.close();
  });
}
