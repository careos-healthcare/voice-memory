import 'package:archiveme_mobile/core/constants/database_constants.dart';
import 'package:archiveme_mobile/features/reflections/data/offline_reflection_knowledge_graph.dart';
import 'package:archiveme_mobile/storage/sqlite/app_sqlite_database.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_011_reflection_graph_fts.dart';
import 'package:archiveme_mobile/storage/sqlite/reflection_knowledge_graph_repository.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_fts_query.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../storage/sqlite/support/sqlite_test_database.dart';

OfflineReflectionKnowledgeGraph _graph({
  required String entryId,
  String theme = 'focus',
  String tension = 'work-life balance',
}) {
  return OfflineReflectionKnowledgeGraph.fromReflectionFields(
    entryId: entryId,
    tensionOrContradiction: tension,
    nextSmallAction: 'take a walk',
    recurringThemes: [theme],
  );
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(AppSqliteDatabase.resetForTest);

  group('ReflectionKnowledgeGraphRepository', () {
    late AppSqliteDatabase db;
    late ReflectionKnowledgeGraphRepository repo;

    setUp(() async {
      db = await openTestAppSqliteDatabase();
      repo = ReflectionKnowledgeGraphRepository(db.database);
    });

    Future<void> seedJournalEntry(String entryId) async {
      await db.database.insert(DatabaseConstants.journalEntriesTable, {
        'id': entryId,
        'created_at': DateTime.utc(2026, 1, 1).millisecondsSinceEpoch,
        'updated_at': DateTime.utc(2026, 1, 1).millisecondsSinceEpoch,
        'deleted_at': null,
        'is_archived': 0,
        'transcript': 'seed transcript',
        'has_verified_proof': 0,
        'payload_json': null,
      });
    }

    test('replaceGraph persists nodes and FTS rows', () async {
      await seedJournalEntry('e1');
      await repo.replaceGraph(_graph(entryId: 'e1'));

      final nodes = await db.database.query(
        Migration011ReflectionGraphFts.nodesTable,
      );
      expect(nodes.length, greaterThan(1));

      final ftsRows = await db.database.query(
        Migration011ReflectionGraphFts.ftsTable,
      );
      expect(ftsRows.length, nodes.length);
    });

    test('searchNodes returns BM25-ranked hits via FTS5 MATCH', () async {
      await seedJournalEntry('e1');
      await seedJournalEntry('e2');
      await repo.replaceGraph(_graph(entryId: 'e1', theme: 'focus'));
      await repo.replaceGraph(_graph(entryId: 'e2', theme: 'sleep'));

      final hits = await repo.searchNodes(query: 'focus', limit: 10);
      expect(hits, isNotEmpty);
      expect(hits.any((hit) => hit.label == 'focus'), isTrue);
    });

    test('searchEntryIds groups hits by journal entry', () async {
      await seedJournalEntry('e1');
      await repo.replaceGraph(_graph(entryId: 'e1', tension: 'burnout signal'));

      final entryIds = await repo.searchEntryIds(query: 'burnout', limit: 5);
      expect(entryIds, ['e1']);
    });

    test('deleteForEntry removes persisted graph rows', () async {
      await seedJournalEntry('e1');
      await repo.replaceGraph(_graph(entryId: 'e1'));
      await repo.deleteForEntry('e1');

      final nodes = await db.database.query(
        Migration011ReflectionGraphFts.nodesTable,
      );
      expect(nodes, isEmpty);
    });
  });

  group('SqliteFtsQuery', () {
    test('toMatchQuery tokenizes and prefix-matches terms', () {
      expect(
        SqliteFtsQuery.toMatchQuery('Hello World'),
        '"hello"* OR "world"*',
      );
      expect(SqliteFtsQuery.hasMatchTerms('   '), isFalse);
    });
  });
}
