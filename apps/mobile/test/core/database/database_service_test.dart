import 'dart:io';

import 'package:archiveme_mobile/core/database/database_service.dart';
import 'package:archiveme_mobile/features/insight_engine/hybrid_search_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  List<double> axis(int index) {
    return List<double>.filled(localTranscriptEmbeddingDimensions, 0)
      ..[index] = 1;
  }

  EmotionalTerritoryRecord territory() {
    return const EmotionalTerritoryRecord(
      id: 'work',
      slug: 'around-work',
      label: 'Around work',
      defaultLabel: 'Around work',
      kind: 'work',
      entryIds: ['entry-1', 'entry-2'],
      mentionCount: 4,
      continuityLines: ['The deadline kept returning.'],
      firstAppearance: '2026-01-01',
      latestAppearance: '2026-03-01',
      firstAppearanceLabel: 'January',
      latestAppearanceLabel: 'March',
      whatChanged: 'The meeting got named.',
    );
  }

  MemoryReminderRecord reminder() {
    return const MemoryReminderRecord(
      id: 'loop-1',
      text: 'You came back to the same loop.',
      kind: 'resurfaced_loop',
      strength: 70,
      href: '/entry/entry-9',
      context: 'reminders',
      pastQuote: 'I keep circling the rent.',
      currentQuote: 'The rent is quieter now.',
      pastEntryId: 'entry-3',
      entryId: 'entry-9',
    );
  }

  test('semantic search ranks the closer territory and reminder', () async {
    final db = DatabaseService.openMemory();
    addTearDown(db.dispose);

    expect(db.vecReady, isFalse);
    db.upsertTerritory(territory(), axis(0));
    db.upsertReminder(reminder(), axis(40));

    final territoryHits = await db.search(
      queryEmbedding: axis(0),
      corpus: OfflineCorpus.emotionalTerritories,
    );
    expect(territoryHits, hasLength(1));
    expect(territoryHits.single.id, 'work');
    expect(territoryHits.single.title, 'Around work');
    expect(territoryHits.single.snippet, contains('deadline'));
    expect(territoryHits.single.score, greaterThan(0.99));

    final both = await db.search(queryEmbedding: axis(40), limit: 2);
    expect(both.first.corpus, OfflineCorpus.memoryReminders);
    expect(both.first.id, 'loop-1');
    expect(both.first.snippet, contains('same loop'));
    expect(both.last.id, 'work');
    expect(both.first.score, greaterThan(both.last.score));
  });

  test(
    'a replaced embedding changes rank and a delete drops the row',
    () async {
      final db = DatabaseService.openMemory();
      addTearDown(db.dispose);
      db.upsertTerritory(territory(), axis(3));
      db.upsertTerritory(territory(), axis(0));

      final hits = await db.search(
        queryEmbedding: axis(0),
        corpus: OfflineCorpus.emotionalTerritories,
      );
      expect(hits.single.score, greaterThan(0.99));

      db.deleteTerritory('work');
      final afterDelete = await db.search(
        queryEmbedding: axis(0),
        corpus: OfflineCorpus.emotionalTerritories,
      );
      expect(afterDelete, isEmpty);
    },
  );

  test('embeddings must use the shared 384-dimension width', () {
    final db = DatabaseService.openMemory();
    addTearDown(db.dispose);
    expect(
      () => db.upsertReminder(reminder(), const [1, 0, 0]),
      throwsArgumentError,
    );
  });

  test('a new file uses the vector read pragmas', () {
    final directory = Directory.systemTemp.createTempSync('vector-pragmas');
    addTearDown(() => directory.deleteSync(recursive: true));
    final db = DatabaseService.openFile('${directory.path}/archive.db');
    addTearDown(db.dispose);

    expect(db.pageSize, DatabaseTuning.pageSize);
    expect(db.mmapSize, DatabaseTuning.mmapSize);
    expect(db.cacheSize, DatabaseTuning.cacheSize);
    expect(db.synchronous, 1);
    expect(db.journalMode, 'wal');
  });

  test('kind and date filters drop rows before distance', () async {
    final db = DatabaseService.openMemory();
    addTearDown(db.dispose);
    db.upsertTerritory(territory(), axis(0));
    db.upsertTerritory(
      const EmotionalTerritoryRecord(
        id: 'home',
        slug: 'at-home',
        label: 'At home',
        defaultLabel: 'At home',
        kind: 'home',
        entryIds: ['entry-9'],
        mentionCount: 1,
        continuityLines: ['The kitchen was quiet.'],
        firstAppearance: '2026-06-01',
        latestAppearance: '2026-06-20',
        firstAppearanceLabel: 'June',
        latestAppearanceLabel: 'June',
      ),
      axis(1),
    );

    final hits = await db.search(
      queryEmbedding: axis(0),
      corpus: OfflineCorpus.emotionalTerritories,
      filter: const CorpusSearchFilter(
        kind: 'home',
        from: '2026-06-01',
        to: '2026-06-30',
      ),
    );

    expect(hits, hasLength(1));
    expect(hits.single.id, 'home');
  });
}
