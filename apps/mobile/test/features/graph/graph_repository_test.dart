import 'package:archiveme_mobile/core/constants/database_constants.dart';
import 'package:archiveme_mobile/features/graph/data/graph_repository.dart';
import 'package:archiveme_mobile/features/reflections/data/offline_reflection_knowledge_graph.dart';
import 'package:archiveme_mobile/storage/sqlite/app_sqlite_database.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_013_entry_edges.dart';
import 'package:archiveme_mobile/storage/sqlite/reflection_knowledge_graph_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../storage/sqlite/support/sqlite_test_database.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(AppSqliteDatabase.resetForTest);

  group('GraphRepository', () {
    late AppSqliteDatabase db;
    late ReflectionKnowledgeGraphRepository graphRepo;
    late GraphRepository repository;

    setUp(() async {
      db = await openTestAppSqliteDatabase();
      graphRepo = ReflectionKnowledgeGraphRepository(db.database);
      repository = GraphRepository(db);
    });

    Future<void> seedEntry(String id) async {
      await db.database.insert(DatabaseConstants.journalEntriesTable, {
        'id': id,
        'created_at': DateTime.utc(2026, 1, 1).millisecondsSinceEpoch,
        'updated_at': DateTime.utc(2026, 1, 1).millisecondsSinceEpoch,
        'deleted_at': null,
        'is_archived': 0,
        'transcript': 'full transcript payload that should never be selected',
        'has_verified_proof': 0,
        'payload_json': '{"secret":"payload"}',
      });
    }

    Future<void> seedGraph(String entryId) async {
      await graphRepo.replaceGraph(
        OfflineReflectionKnowledgeGraph.fromReflectionFields(
          entryId: entryId,
          tensionOrContradiction: 'tension for $entryId',
          nextSmallAction: 'action for $entryId',
          recurringThemes: ['theme-$entryId'],
        ),
      );
    }

    Future<void> seedEdge({
      required String source,
      required String target,
      double weight = 0.9,
    }) async {
      await db.database.insert(Migration013EntryEdges.edgesTable, {
        'source_entry_id': source,
        'target_entry_id': target,
        'relation': Migration013EntryEdges.relationSemanticSimilarity,
        'weight': weight,
        'created_at': DateTime.utc(2026, 1, 2).millisecondsSinceEpoch,
      });
    }

    test('recursive CTE expands neighborhood without payload columns', () async {
      await seedEntry('e1');
      await seedEntry('e2');
      await seedEntry('e3');
      await seedGraph('e1');
      await seedGraph('e2');
      await seedGraph('e3');
      await seedEdge(source: 'e1', target: 'e2');
      await seedEdge(source: 'e2', target: 'e3');

      final topology = await repository.loadNeighborhood(
        seedEntryId: 'e1',
        maxDepth: 2,
      );

      expect(topology.nodes.map((node) => node.entryId).toSet(), {'e1', 'e2', 'e3'});
      expect(topology.links, isNotEmpty);

      final rows = await db.database.rawQuery(
        '''
        SELECT id, entry_id, kind, label
        FROM ${GraphRepository.nodesTable}
        WHERE entry_id = ?
        LIMIT 1
        ''',
        ['e1'],
      );
      expect(rows.single.keys.toSet(), {'id', 'entry_id', 'kind', 'label'});
    });

    test('depth limit keeps expansion local', () async {
      await seedEntry('e1');
      await seedEntry('e2');
      await seedEntry('e3');
      await seedGraph('e1');
      await seedGraph('e2');
      await seedGraph('e3');
      await seedEdge(source: 'e1', target: 'e2');
      await seedEdge(source: 'e2', target: 'e3');

      final topology = await repository.loadNeighborhood(
        seedEntryId: 'e1',
        maxDepth: 1,
      );

      expect(topology.nodes.map((node) => node.entryId).toSet(), {'e1', 'e2'});
    });
  });
}
