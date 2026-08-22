import 'dart:convert';
import '../../storage/sqlite/support/sqlite_test_database.dart';

import 'package:archiveme_mobile/core/constants/database_constants.dart';
import 'package:archiveme_mobile/storage/sqlite/app_sqlite_database.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_011_reflection_graph_fts.dart';
import 'package:archiveme_mobile/storage/sqlite/reflection_graph_backfill.dart';
import 'package:archiveme_mobile/storage/sqlite/reflection_knowledge_graph_repository.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_migration_manager.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_migration_registry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Map<String, dynamic> _slimReflectionPayload({
  List<String> recurringThemes = const ['focus'],
  String? tensionOrContradiction,
  String? nextSmallAction,
}) {
  return {
    'durationSeconds': 45,
    'reflection': {
      'mood': 'calm',
      'emotionalIntensity': 2,
      'recurringThemes': recurringThemes,
      'exactLanguagePattern': 'pattern',
      'concreteObservation': 'observation',
      'repeatedSignal': 'signal',
      if (tensionOrContradiction != null)
        'tensionOrContradiction': tensionOrContradiction,
      if (nextSmallAction != null) 'nextSmallAction': nextSmallAction,
    },
  };
}

Future<void> _insertJournalEntry(
  Database db, {
  required String id,
  required String transcript,
  String? payloadJson,
  int? deletedAt,
}) async {
  final now = DateTime.utc(2026, 1, 1).millisecondsSinceEpoch;
  await db.insert(DatabaseConstants.journalEntriesTable, {
    'id': id,
    'created_at': now,
    'updated_at': now,
    'deleted_at': deletedAt,
    'is_archived': 0,
    'transcript': transcript,
    'has_verified_proof': 0,
    'payload_json': payloadJson,
  });
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(AppSqliteDatabase.resetForTest);

  group('ReflectionGraphBackfill', () {
    test('fromJournalEntries indexes slim and legacy reflection payloads', () async {
      final db = await openTestAppSqliteDatabase();
      final database = db.database;

      await _insertJournalEntry(
        database,
        id: 'slim',
        transcript: 'slim payload',
        payloadJson: jsonEncode(
          _slimReflectionPayload(tensionOrContradiction: 'work stress'),
        ),
      );
      await _insertJournalEntry(
        database,
        id: 'legacy',
        transcript: 'legacy payload',
        payloadJson: jsonEncode({
          'id': 'legacy',
          'createdAt': '2026-01-01T00:00:00.000Z',
          'updatedAt': '2026-01-01T00:00:00.000Z',
          'transcript': 'legacy payload',
          'durationSeconds': 45,
          'reflection': _slimReflectionPayload(
            recurringThemes: ['sleep'],
            nextSmallAction: 'wind down earlier',
          )['reflection'],
        }),
      );
      await _insertJournalEntry(
        database,
        id: 'deleted',
        transcript: 'skip me',
        deletedAt: DateTime.utc(2026, 1, 2).millisecondsSinceEpoch,
        payloadJson: jsonEncode(_slimReflectionPayload()),
      );
      await _insertJournalEntry(
        database,
        id: 'empty',
        transcript: 'no reflection payload',
        payloadJson: null,
      );

      final graphRepo = ReflectionKnowledgeGraphRepository(database);
      final backfilled = await ReflectionGraphBackfill.fromJournalEntries(
        database,
      );

      expect(backfilled, 2);

      final slimHits = await graphRepo.searchNodes(query: 'stress', limit: 5);
      expect(slimHits.any((hit) => hit.entryId == 'slim'), isTrue);

      final legacyHits = await graphRepo.searchNodes(query: 'wind', limit: 5);
      expect(legacyHits.any((hit) => hit.entryId == 'legacy'), isTrue);

      final deletedRows = await database.query(
        Migration011ReflectionGraphFts.nodesTable,
        where: 'entry_id = ?',
        whereArgs: ['deleted'],
      );
      expect(deletedRows, isEmpty);
    });
  });

  group('Migration011ReflectionGraphFts', () {
    test('backfills graph FTS when upgrading from version 10', () async {
      final database = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onConfigure: (db) async {
            await db.execute('PRAGMA foreign_keys = ON');
          },
        ),
      );
      addTearDown(database.close);

      await SqliteMigrationManager(
        migrations: SqliteMigrationRegistry.defaultMigrations
            .where((migration) => migration.version <= 10)
            .toList(),
      ).run(database);

      await _insertJournalEntry(
        database,
        id: 'pre-upgrade',
        transcript: 'existing entry before migration 11',
        payloadJson: jsonEncode(
          _slimReflectionPayload(recurringThemes: ['mindfulness']),
        ),
      );

      await Migration011ReflectionGraphFts().up(database);
      await ReflectionGraphBackfill.fromJournalEntries(database);
      await ReflectionGraphBackfill.markComplete(database);

      final ftsRows = await database.query(
        Migration011ReflectionGraphFts.ftsTable,
      );
      expect(ftsRows, isNotEmpty);
      expect(
        ftsRows.any(
          (row) =>
              row['entry_id'] == 'pre-upgrade' && row['label'] == 'mindfulness',
        ),
        isTrue,
      );
    });
  });
}
