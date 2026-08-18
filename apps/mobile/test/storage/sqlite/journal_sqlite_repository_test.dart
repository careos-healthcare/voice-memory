import 'dart:convert';

import 'package:archiveme_mobile/features/moment_quality/post_save_moment_detail_model.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/storage/sqlite/app_sqlite_database.dart';
import 'package:archiveme_mobile/storage/sqlite/journal_sqlite_repository.dart';
import 'package:archiveme_mobile/storage/sqlite/memory_transcript_search_repository.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_005_hybrid_search.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

JournalEntry _entry({
  required String id,
  required String transcript,
  DateTime? createdAt,
  DateTime? deletedAt,
  bool isArchived = false,
  String? captureContextTag,
}) {
  return JournalEntry(
    id: id,
    createdAt: createdAt ?? DateTime(2026, 1, id.hashCode % 28 + 1),
    transcript: transcript,
    durationSeconds: 45,
    reflection: const Reflection(
      mood: 'calm',
      emotionalIntensity: 2,
      recurringThemes: ['focus'],
      exactLanguagePattern: 'pattern',
      concreteObservation: 'observation',
      repeatedSignal: 'signal',
    ),
    isArchived: isArchived,
    deletedAt: deletedAt,
    captureContextTag: captureContextTag,
  );
}

List<JournalEntry> _syntheticEntries(int count) {
  return List.generate(
    count,
    (index) => _entry(
      id: 'entry-$index',
      createdAt: DateTime.utc(2026, 1, 1).add(Duration(minutes: index)),
      transcript: index == 4999
          ? 'target capture context transcript'
          : 'filler transcript $index',
      captureContextTag: index == 4999
          ? PostSaveMomentDetailType.linkedCaptureContextTag(
              type: PostSaveMomentDetailType.situation,
              parentEntryId: 'parent-4999',
            )
          : null,
    ),
  );
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(AppSqliteDatabase.resetForTest);

  group('JournalSqliteRepository sync optimizations', () {
    late AppSqliteDatabase db;
    late JournalSqliteRepository repo;
    late MemoryTranscriptSearchRepository searchRepo;

    setUp(() async {
      db = await AppSqliteDatabase.open(filePath: ':memory:');
      repo = JournalSqliteRepository(db);
      searchRepo = MemoryTranscriptSearchRepository(db);
    });

    test('stores slim payload without duplicated top-level fields', () async {
      await repo.mirrorEntireRemoteState([
        _entry(id: 'e1', transcript: 'morning reflection'),
      ]);

      final row = (await db.database.query(
        JournalSqliteRepository.table,
        where: 'id = ?',
        whereArgs: ['e1'],
      )).single;

      expect(row['transcript'], 'morning reflection');
      final payload = row['payload_json'] as String?;
      expect(payload, isNotNull);
      expect(payload, isNot(contains('"id"')));
      expect(payload, isNot(contains('"createdAt"')));
      expect(payload, isNot(contains('"transcript"')));
      expect(payload, contains('"durationSeconds"'));

      final loaded = (await repo.fetchPage(offset: 0, limit: 1)).single;
      expect(loaded.id, 'e1');
      expect(loaded.transcript, 'morning reflection');
      expect(loaded.durationSeconds, 45);
      expect(loaded.reflection.mood, 'calm');
    });

    test('reads legacy full payload rows', () async {
      final legacyEntry = _entry(id: 'legacy', transcript: 'legacy transcript');
      await db.database.insert(JournalSqliteRepository.table, {
        'id': legacyEntry.id,
        'created_at': legacyEntry.createdAt.toUtc().millisecondsSinceEpoch,
        'updated_at': legacyEntry.updatedAt.toUtc().millisecondsSinceEpoch,
        'deleted_at': null,
        'is_archived': 0,
        'transcript': legacyEntry.transcript,
        'has_verified_proof': 0,
        'payload_json': '''
{"id":"legacy","createdAt":"2026-01-02T00:00:00.000Z","updatedAt":"2026-01-02T00:00:00.000Z","transcript":"legacy transcript","durationSeconds":45,"reflection":{"mood":"calm","emotionalIntensity":2,"recurringThemes":["focus"],"exactLanguagePattern":"pattern","concreteObservation":"observation","repeatedSignal":"signal"},"_syncStatus":"localOnly","revision":1,"changeId":"change","schemaVersion":3}
''',
      });

      final loaded = (await repo.fetchPage(offset: 0, limit: 1)).single;
      expect(loaded.id, 'legacy');
      expect(loaded.transcript, 'legacy transcript');
      expect(loaded.durationSeconds, 45);
    });

    test('skips FTS refresh when transcript is unchanged', () async {
      await repo.mirrorEntireRemoteState([
        _entry(id: 'e1', transcript: 'stable transcript'),
      ]);

      final contentAfterFirst = await db.database.query(
        Migration005HybridSearch.ftsTable,
      );
      expect(contentAfterFirst, hasLength(1));

      await repo.mirrorEntireRemoteState([
        _entry(id: 'e1', transcript: 'stable transcript', isArchived: true),
      ]);

      final row = (await db.database.query(
        JournalSqliteRepository.table,
        where: 'id = ?',
        whereArgs: ['e1'],
      )).single;
      expect(row['is_archived'], 1);

      final contentAfterSecond = await db.database.query(
        Migration005HybridSearch.ftsTable,
      );
      expect(contentAfterSecond, hasLength(1));
      expect(contentAfterSecond.single['transcript'], 'stable transcript');

      final hits = await searchRepo.keywordSearch(query: 'stable', limit: 5);
      expect(hits, ['e1']);
    });

    test('updates FTS only when transcript changes', () async {
      await repo.mirrorEntireRemoteState([
        _entry(id: 'e1', transcript: 'alpha transcript'),
        _entry(id: 'e2', transcript: 'beta transcript'),
      ]);

      await repo.mirrorEntireRemoteState([
        _entry(id: 'e1', transcript: 'alpha transcript'),
        _entry(id: 'e2', transcript: 'beta transcript updated'),
      ]);

      final hits = await searchRepo.keywordSearch(query: 'updated', limit: 5);
      expect(hits, ['e2']);

      final ftsRows = await db.database.query(Migration005HybridSearch.ftsTable);
      expect(ftsRows, hasLength(2));
    });

    test('removes deleted entries from FTS incrementally', () async {
      await repo.mirrorEntireRemoteState([
        _entry(id: 'e1', transcript: 'keep me'),
        _entry(id: 'e2', transcript: 'remove me'),
      ]);

      await repo.mirrorEntireRemoteState([
        _entry(id: 'e1', transcript: 'keep me'),
      ]);

      final ftsRows = await db.database.query(Migration005HybridSearch.ftsTable);
      expect(ftsRows, hasLength(1));
      expect(ftsRows.single['entry_id'], 'e1');
    });

    test('journal upsert uses ON CONFLICT without duplicate rows', () async {
      await repo.mirrorEntireRemoteState([
        _entry(id: 'e1', transcript: 'first'),
      ]);
      await repo.mirrorEntireRemoteState([
        _entry(id: 'e1', transcript: 'second'),
      ]);

      final rows = await db.database.query(JournalSqliteRepository.table);
      expect(rows, hasLength(1));
      expect(rows.single['transcript'], 'second');
    });
  });

  group('JournalSqliteRepository upsertEntries / mirrorEntireRemoteState', () {
    late AppSqliteDatabase db;
    late JournalSqliteRepository repo;

    setUp(() async {
      db = await AppSqliteDatabase.open(filePath: ':memory:');
      repo = JournalSqliteRepository(db);
    });

    test('partial upsert does not delete absent rows', () async {
      await repo.mirrorEntireRemoteState([
        _entry(id: 'keep', transcript: 'keep me'),
        _entry(id: 'also-keep', transcript: 'also keep'),
      ]);

      await repo.upsertEntries([
        _entry(id: 'keep', transcript: 'keep me updated'),
      ]);

      final rows = await db.database.query(JournalSqliteRepository.table);
      expect(rows, hasLength(2));
      expect(
        rows.singleWhere((row) => row['id'] == 'keep')['transcript'],
        'keep me updated',
      );
    });

    test('mirrorEntireRemoteState removes absent rows', () async {
      await repo.mirrorEntireRemoteState([
        _entry(id: 'keep', transcript: 'keep me'),
        _entry(id: 'drop', transcript: 'drop me'),
      ]);

      await repo.mirrorEntireRemoteState([
        _entry(id: 'keep', transcript: 'keep me'),
      ]);

      final rows = await db.database.query(JournalSqliteRepository.table);
      expect(rows, hasLength(1));
      expect(rows.single['id'], 'keep');
    });

    test('mirrorEntireRemoteState deletes 2000+ absent rows without SQL variable overflow',
        () async {
      final initial = List.generate(
        2100,
        (index) => _entry(id: 'entry-$index', transcript: 'seed $index'),
      );
      await repo.mirrorEntireRemoteState(initial);

      await repo.mirrorEntireRemoteState([
        _entry(id: 'entry-0', transcript: 'only survivor'),
      ]);

      final rows = await db.database.query(JournalSqliteRepository.table);
      expect(rows, hasLength(1));
      expect(rows.single['id'], 'entry-0');
    });
  });

  group('JournalSqliteRepository findByCaptureContextTag', () {
    late JournalSqliteRepository repo;

    setUp(() async {
      final db = await AppSqliteDatabase.open(filePath: ':memory:');
      repo = JournalSqliteRepository(db);
    });

    test('findByCaptureContextTag stays fast at 5000 entries', () async {
      final entries = _syntheticEntries(5000);
      await repo.mirrorEntireRemoteState(entries);

      final tag = PostSaveMomentDetailType.linkedCaptureContextTag(
        type: PostSaveMomentDetailType.situation,
        parentEntryId: 'parent-4999',
      );

      Future<int> linearScanCount() async {
        final rows = await repo.fetchPage(offset: 0, limit: 5000);
        var count = 0;
        for (final entry in rows) {
          if (entry.captureContextTag == tag) {
            count++;
          }
        }
        return count;
      }

      final linearStopwatch = Stopwatch()..start();
      expect(await linearScanCount(), 1);
      linearStopwatch.stop();

      final indexedStopwatch = Stopwatch()..start();
      final found = await repo.findByCaptureContextTag(tag);
      indexedStopwatch.stop();

      expect(found, isNotNull);
      expect(found!.id, 'entry-4999');
      expect(
        indexedStopwatch.elapsedMicroseconds,
        lessThan(linearStopwatch.elapsedMicroseconds ~/ 2),
      );
    });
  });

  group('JournalSqliteRepository search and pagination', () {
    late AppSqliteDatabase db;
    late JournalSqliteRepository repo;

    setUp(() async {
      db = await AppSqliteDatabase.open(filePath: ':memory:');
      repo = JournalSqliteRepository(db);
    });

    test('fetchPage uses FTS for non-empty searchQuery', () async {
      await repo.mirrorEntireRemoteState([
        _entry(id: 'alpha', transcript: 'alpha keyword match'),
        _entry(id: 'beta', transcript: 'beta unrelated'),
      ]);

      final hits = await repo.fetchPage(
        offset: 0,
        limit: 10,
        searchQuery: 'keyword',
      );
      expect(hits, hasLength(1));
      expect(hits.single.id, 'alpha');
    });

    test('fetchPage FTS search stays faster than LIKE at 5000 rows', () async {
      final entries = List.generate(
        5000,
        (index) => _entry(
          id: 'entry-$index',
          createdAt: DateTime.utc(2026, 1, 1).add(Duration(minutes: index)),
          transcript: index == 2500
              ? 'needle keyword in haystack'
              : 'filler transcript $index',
        ),
      );
      await repo.mirrorEntireRemoteState(entries);

      final ftsStopwatch = Stopwatch()..start();
      final ftsHits = await repo.fetchPage(
        offset: 0,
        limit: 20,
        searchQuery: 'needle',
      );
      ftsStopwatch.stop();

      final likeStopwatch = Stopwatch()..start();
      final likeRows = await db.database.rawQuery(
        '''
        SELECT id
        FROM ${JournalSqliteRepository.table}
        WHERE deleted_at IS NULL
          AND LOWER(transcript) LIKE ? ESCAPE '\\'
        LIMIT 20
        ''',
        ['%needle%'],
      );
      likeStopwatch.stop();

      expect(ftsHits, hasLength(1));
      expect(ftsHits.single.id, 'entry-2500');
      expect(likeRows, hasLength(1));
      expect(
        ftsStopwatch.elapsedMicroseconds,
        lessThan(likeStopwatch.elapsedMicroseconds),
      );
    });

    test('fetchPageAfter deep page stays faster than fetchPage offset', () async {
      final entries = List.generate(
        5000,
        (index) => _entry(
          id: 'entry-${index.toString().padLeft(4, '0')}',
          createdAt: DateTime.utc(2026, 1, 1).add(Duration(minutes: index)),
          transcript: 'entry $index',
        ),
      );
      await repo.mirrorEntireRemoteState(entries);

      const pageSize = JournalSqliteRepository.defaultPageSize;
      const deepPageIndex = 200;
      final deepOffset = pageSize * deepPageIndex;

      var cursorCreatedAt = null as DateTime?;
      var cursorId = null as String?;
      for (var page = 0; page < deepPageIndex; page++) {
        final nextPage = await repo.fetchPageAfter(
          limit: pageSize,
          afterCreatedAt: cursorCreatedAt,
          afterId: cursorId,
        );
        expect(nextPage, isNotEmpty);
        cursorCreatedAt = nextPage.last.createdAt;
        cursorId = nextPage.last.id;
      }

      final keysetStopwatch = Stopwatch()..start();
      final keysetPage = await repo.fetchPageAfter(
        limit: pageSize,
        afterCreatedAt: cursorCreatedAt,
        afterId: cursorId,
      );
      keysetStopwatch.stop();

      final offsetStopwatch = Stopwatch()..start();
      final offsetPage = await repo.fetchPage(
        offset: deepOffset,
        limit: pageSize,
      );
      offsetStopwatch.stop();

      expect(keysetPage, hasLength(pageSize));
      expect(offsetPage, hasLength(pageSize));
      expect(keysetPage.first.id, offsetPage.first.id);
      expect(
        keysetStopwatch.elapsedMicroseconds,
        lessThan(offsetStopwatch.elapsedMicroseconds),
      );
    });
  });

  group('JournalSqliteRepository defensive decoding', () {
    late AppSqliteDatabase db;
    late JournalSqliteRepository repo;

    setUp(() async {
      db = await AppSqliteDatabase.open(filePath: ':memory:');
      repo = JournalSqliteRepository(db);
    });

    test('malformed payload_json is skipped while valid rows decode', () async {
      await repo.mirrorEntireRemoteState([
        _entry(id: 'good', transcript: 'good transcript'),
      ]);

      await db.database.insert(JournalSqliteRepository.table, {
        'id': 'bad',
        'created_at': DateTime.utc(2026, 2, 1).millisecondsSinceEpoch,
        'updated_at': DateTime.utc(2026, 2, 1).millisecondsSinceEpoch,
        'deleted_at': null,
        'is_archived': 0,
        'transcript': 'bad transcript',
        'has_verified_proof': 0,
        'payload_json': '{not-json',
      });

      final page = await repo.fetchPage(offset: 0, limit: 10);
      expect(page, hasLength(1));
      expect(page.single.id, 'good');
    });

    test('findByCaptureContextTag returns null for corrupted payload_json', () async {
      final tag = 'corrupt-tag';
      await db.database.insert(JournalSqliteRepository.table, {
        'id': 'corrupt',
        'created_at': DateTime.utc(2026, 2, 1).millisecondsSinceEpoch,
        'updated_at': DateTime.utc(2026, 2, 1).millisecondsSinceEpoch,
        'deleted_at': null,
        'is_archived': 0,
        'transcript': 'ignored transcript',
        'has_verified_proof': 0,
        'payload_json': '{not-json',
      });

      expect(await repo.findByCaptureContextTag(tag), isNull);
    });

    test('toResidualJson matches legacy strip-based payload encoding', () async {
      final entry = _entry(
        id: 'residual',
        transcript: 'residual transcript',
        captureContextTag: 'ctx-tag',
      );

      final legacyPayload = Map<String, dynamic>.from(entry.toJson())
        ..remove('id')
        ..remove('createdAt')
        ..remove('updatedAt')
        ..remove('deletedAt')
        ..remove('transcript')
        ..remove('isArchived');

      expect(entry.toResidualJson(), legacyPayload);
      expect(jsonEncode(entry.toResidualJson()), isNot(contains('"id"')));
    });
  });
}
