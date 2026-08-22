import 'package:archiveme_mobile/features/search/local_reflection_embedding_inference.dart';
import 'package:archiveme_mobile/features/search/offline_reflection_vector_search_service.dart';
import 'package:archiveme_mobile/features/search/reflection_embedding_repository.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/services/automated_graph/automated_graph_index_worker.dart';
import 'package:archiveme_mobile/services/automated_graph/automated_graph_service.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';
import 'package:archiveme_mobile/storage/sqlite/app_sqlite_database.dart';
import 'package:archiveme_mobile/storage/sqlite/entry_edges_repository.dart';
import 'package:archiveme_mobile/workers/embedding/embedding_index_worker_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';

import '../../storage/sqlite/support/sqlite_test_database.dart';

Reflection _reflection({required String tension}) {
  return Reflection(
    mood: 'calm',
    emotionalIntensity: 3,
    recurringThemes: const ['work'],
    exactLanguagePattern: 'I keep saying tomorrow',
    concreteObservation: 'Skipped lunch again',
    repeatedSignal: 'avoidance',
    tensionOrContradiction: tension,
  );
}

JournalEntry _entry({
  required String id,
  required String transcript,
  Reflection? reflection,
}) {
  return JournalEntry(
    id: id,
    createdAt: DateTime.utc(2026, 8, 19),
    transcript: transcript,
    durationSeconds: 30,
    reflection: reflection ?? _reflection(tension: 'fallback reflection for $id'),
  );
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(AppSqliteDatabase.resetForTest);

  group('AutomatedGraphService', () {
    late Directory dir;
    late String dbPath;
    late AppSqliteDatabase sqlite;
    late ReflectionEmbeddingRepository embeddingRepository;
    late EntryEdgesRepository edgesRepository;
    late OfflineReflectionVectorSearchService search;
    late AutomatedGraphService graphService;
    late AutomatedGraphIndexWorker graphWorker;
    late JournalStore journal;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('automated_graph_');
      dbPath = '${dir.path}/graph.sqlite';
      journal = await JournalStore.open('${dir.path}/journal.json');
      sqlite = await AppSqliteDatabase.open(
        filePath: dbPath,
        password: testSqliteEncryptionPassword,
      );
      embeddingRepository = ReflectionEmbeddingRepository(sqlite);
      edgesRepository = EntryEdgesRepository(sqlite);
      search = OfflineReflectionVectorSearchService(
        repository: embeddingRepository,
        inference: LocalReflectionEmbeddingInference(),
      );
      graphService = AutomatedGraphService(
        sqliteFilePath: dbPath,
        sqliteEncryptionPassword: testSqliteEncryptionPassword,
      );
      graphWorker = AutomatedGraphIndexWorker(
        graphService: graphService,
        journalStore: journal,
        debounce: Duration.zero,
      );
    });

    tearDown(() async {
      graphWorker.dispose();
      await EmbeddingIndexWorkerService.instance.dispose();
      await sqlite.close();
      await dir.delete(recursive: true);
    });

    test('stores embedding and top 3 semantic edges after journal save', () async {
      final workStress = _entry(
        id: 'entry-work-stress',
        transcript:
            'Work has been overwhelming and I keep accepting more tasks even when I need rest.',
        reflection: _reflection(
          tension: 'I want rest but keep accepting more work',
        ),
      );
      final weekendWalk = _entry(
        id: 'entry-weekend-walk',
        transcript:
            'I walked outside this morning and felt calm watching the trees.',
        reflection: _reflection(tension: 'Walked outside and felt calm'),
      );
      final newWorkEntry = _entry(
        id: 'entry-new-work',
        transcript:
            'Another late night at work because I said yes again despite feeling exhausted.',
        reflection: _reflection(
          tension: 'Said yes again even though I was already tired from work',
        ),
      );

      await journal.save(workStress);
      await journal.save(weekendWalk);

      final workEmbedding = await search.embedReflection(workStress.reflection);
      final walkEmbedding = await search.embedReflection(weekendWalk.reflection);
      await embeddingRepository.upsertEmbedding(
        entryId: workStress.id,
        contentHash: 'work',
        embedding: workEmbedding,
      );
      await embeddingRepository.upsertEmbedding(
        entryId: weekendWalk.id,
        contentHash: 'walk',
        embedding: walkEmbedding,
      );

      await journal.save(newWorkEntry);
      graphWorker.enqueue(newWorkEntry);
      final built = await graphWorker.flush();

      expect(built, 1);

      final storedHash = await embeddingRepository.readContentHash(newWorkEntry.id);
      expect(storedHash, isNotNull);

      final edges = await edgesRepository.readOutgoingEdges(newWorkEntry.id);
      expect(edges.length, lessThanOrEqualTo(3));
      expect(edges, isNotEmpty);
      expect(edges.first.sourceEntryId, newWorkEntry.id);
      expect(edges.first.relation, 'semantic_similarity');
      expect(edges.first.weight, greaterThan(0));
      expect(
        edges.map((edge) => edge.targetEntryId),
        isNot(contains(newWorkEntry.id)),
      );
      expect(
        edges.map((edge) => edge.targetEntryId),
        contains('entry-work-stress'),
      );
    });
  });
}
