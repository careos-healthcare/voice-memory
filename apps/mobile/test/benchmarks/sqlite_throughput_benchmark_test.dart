import 'dart:io';

import 'package:archiveme_mobile/core/constants/database_constants.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/storage/sqlite/journal_sqlite_bulk_sync.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_database_initializer.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_fts_query.dart';
import 'package:benchmark_test/benchmark_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:test/test.dart';

import '../storage/sqlite/support/configure_sqlite_test_ffi.dart';
import '../storage/sqlite/support/sqlite_test_database.dart';

/// Rows seeded before read and FTS benchmarks.
const _seedEntryCount = 5000;

/// Journal rows written per bulk-insert transaction sample.
const _bulkBatchSize = 100;

const _journalTable = DatabaseConstants.journalEntriesTable;
const _ftsTable = DatabaseConstants.ftsTable;

JournalEntry _entry({
  required String id,
  required String transcript,
  DateTime? createdAt,
}) {
  return JournalEntry(
    id: id,
    createdAt: createdAt ?? DateTime.utc(2026, 1, 1),
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
  );
}

List<JournalEntry> _seedEntries(int count) {
  return List.generate(
    count,
    (index) => _entry(
      id: 'entry-$index',
      createdAt: DateTime.utc(2026, 1, 1).add(Duration(minutes: index)),
      transcript: index == count - 1
          ? 'target capture context transcript'
          : 'filler transcript $index with searchable terms',
    ),
  );
}

List<JournalEntry> _benchmarkBatchEntries(int batchSequence) {
  return List.generate(
    _bulkBatchSize,
    (index) => _entry(
      id: 'bench-insert-$batchSequence-$index',
      createdAt: DateTime.utc(2026, 2, 1).add(Duration(minutes: index)),
      transcript: 'benchmark insert batch $batchSequence row $index',
    ),
  );
}

void main() {
  group('SQLite throughput', () {
    late Directory tempDir;
    late Database db;

    setUpAll(() async {
      configureSqliteTestFfi();

      tempDir = await Directory.systemTemp.createTemp(
        'sqlite-throughput-bench',
      );
      final dbPath = p.join(tempDir.path, 'encrypted.db');
      db = await SqliteDatabaseInitializer.open(
        filePath: dbPath,
        passwordOverride: testSqliteEncryptionPassword,
        runDeferredBackfill: false,
      );

      await JournalSqliteBulkSync.mirrorEntireRemoteState(
        db,
        _seedEntries(_seedEntryCount),
      );
    });

    tearDownAll(() async {
      await db.close();
      await tempDir.delete(recursive: true);
    });

    group('bulk insert transaction', () {
      var batchSequence = 0;

      tearDownEach(() async {
        await db.delete(
          _journalTable,
          where: 'id LIKE ?',
          whereArgs: ['bench-insert-%'],
        );
        batchSequence++;
      });

      benchmark(
        'upsert $_bulkBatchSize journal rows in one transaction',
        () async {
          await JournalSqliteBulkSync.upsertEntries(
            db,
            _benchmarkBatchEntries(batchSequence),
          );
        },
        minDuration: const Duration(seconds: 3),
        minSamples: 10,
      );
    });

    group('encrypted read query', () {
      benchmark(
        'paginated SELECT on $_seedEntryCount SQLCipher rows',
        () async {
          await db.rawQuery(
            '''
            SELECT
              id,
              created_at,
              updated_at,
              deleted_at,
              is_archived,
              transcript,
              has_verified_proof,
              payload_json
            FROM $_journalTable
            WHERE deleted_at IS NULL
            ORDER BY created_at DESC, id DESC
            LIMIT ?
            ''',
            [DatabaseConstants.defaultPageSize],
          );
        },
        minDuration: const Duration(seconds: 3),
        minSamples: 20,
      );

      benchmark(
        'point lookup by id on SQLCipher database',
        () async {
          await db.query(
            _journalTable,
            where: 'id = ?',
            whereArgs: ['entry-2500'],
          );
        },
        minDuration: const Duration(seconds: 2),
        minSamples: 30,
      );
    });

    group('FTS5 full-text search', () {
      benchmark(
        'BM25 transcript MATCH over $_seedEntryCount rows',
        () async {
          final ftsQuery = SqliteFtsQuery.toMatchQuery(
            'filler transcript searchable',
          );
          await db.rawQuery(
            '''
            SELECT entry_id
            FROM $_ftsTable
            WHERE $_ftsTable MATCH ?
            ORDER BY bm25($_ftsTable)
            LIMIT ?
            ''',
            [ftsQuery, 20],
          );
        },
        minDuration: const Duration(seconds: 3),
        minSamples: 20,
      );

      benchmark(
        'BM25 transcript MATCH rare term',
        () async {
          final ftsQuery = SqliteFtsQuery.toMatchQuery(
            'target capture context',
          );
          await db.rawQuery(
            '''
            SELECT entry_id
            FROM $_ftsTable
            WHERE $_ftsTable MATCH ?
            ORDER BY bm25($_ftsTable)
            LIMIT ?
            ''',
            [ftsQuery, 20],
          );
        },
        minDuration: const Duration(seconds: 2),
        minSamples: 20,
      );
    });
  });
}
