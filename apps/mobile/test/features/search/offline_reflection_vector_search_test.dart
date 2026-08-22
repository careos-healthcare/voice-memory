import 'package:archiveme_mobile/api/models/capture_dto.dart';
import 'package:archiveme_mobile/features/search/local_reflection_embedding_inference.dart';
import 'package:archiveme_mobile/features/search/offline_reflection_vector_search_service.dart';
import 'package:archiveme_mobile/features/search/reflection_embedding_index_worker.dart';
import 'package:archiveme_mobile/workers/embedding/embedding_index_worker_service.dart';
import 'package:archiveme_mobile/features/search/reflection_embedding_repository.dart';
import 'package:archiveme_mobile/features/search/reflection_embedding_text.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';
import 'package:archiveme_mobile/storage/sqlite/app_sqlite_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../storage/sqlite/support/sqlite_test_database.dart';

Reflection _reflection({String mood = 'calm', String tension = ''}) {
  return Reflection(
    mood: mood,
    emotionalIntensity: 3,
    recurringThemes: const ['work'],
    exactLanguagePattern: 'I keep saying tomorrow',
    concreteObservation: 'Skipped lunch again',
    repeatedSignal: 'avoidance',
    tensionOrContradiction: tension.isEmpty ? null : tension,
  );
}

JournalEntry _entry({
  required String id,
  required Reflection reflection,
}) {
  return JournalEntry(
    id: id,
    createdAt: DateTime.utc(2026, 8, 11),
    transcript: 'fallback transcript for $id',
    durationSeconds: 30,
    reflection: reflection,
  );
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(AppSqliteDatabase.resetForTest);

  group('OfflineReflectionVectorSearchService', () {
    late AppSqliteDatabase sqlite;
    late ReflectionEmbeddingRepository repository;
    late OfflineReflectionVectorSearchService search;

    setUp(() async {
      sqlite = await openTestAppSqliteDatabase();
      repository = ReflectionEmbeddingRepository(sqlite);
      search = OfflineReflectionVectorSearchService(
        repository: repository,
        inference: LocalReflectionEmbeddingInference(),
      );
    });

    test('indexes and retrieves semantically similar reflections offline', () async {
      await repository.upsertEmbedding(
        entryId: 'entry-work-stress',
        contentHash: 'a',
        embedding: await search.embedReflection(
          _reflection(
            mood: 'overwhelmed',
            tension: 'I want rest but keep accepting more work',
          ),
        ),
      );
      await repository.upsertEmbedding(
        entryId: 'entry-weekend-walk',
        contentHash: 'b',
        embedding: await search.embedReflection(
          _reflection(mood: 'content', tension: 'Walked outside and felt calm'),
        ),
      );

      final hits = await search.searchSimilarText(
        query: 'work stress rest boundaries overwhelmed',
        limit: 5,
      );

      expect(hits, isNotEmpty);
      expect(hits.first.entryId, 'entry-work-stress');
      expect(hits.first.cosineSimilarity, greaterThan(0));
    });

    test('embedReflectionDto produces stable vectors', () async {
      const dto = ReflectionDto(
        mood: 'hopeful',
        emotionalIntensity: 5,
        recurringThemes: ['health'],
        nextSmallAction: 'Walk before breakfast',
      );
      final first = await search.embedReflectionDto(dto);
      final second = await search.embedReflectionDto(dto);
      expect(first.length, 384);
      expect(second, first);
    });
  });

  group('ReflectionEmbeddingIndexWorker', () {
    test('indexes saved journal entries in the background', () async {
      final dir = await Directory.systemTemp.createTemp('reflection_index_');
      final dbPath = '${dir.path}/embeddings.sqlite';
      final journal = await JournalStore.open('${dir.path}/journal.json');
      final sqlite = await AppSqliteDatabase.open(
        filePath: dbPath,
        password: testSqliteEncryptionPassword,
      );
      final repository = ReflectionEmbeddingRepository(sqlite);
      final worker = ReflectionEmbeddingIndexWorker(
        repository: repository,
        journalStore: journal,
        sqliteFilePath: dbPath,
        sqliteEncryptionPassword: testSqliteEncryptionPassword,
        debounce: Duration.zero,
      );

      final entry = _entry(
        id: 'entry-1',
        reflection: _reflection(
          tension: 'I want rest but keep working late',
        ),
      );
      await journal.save(entry);
      worker.enqueue(entry);
      final indexed = await worker.flush();

      expect(indexed, 1);
      final hash = await repository.readContentHash('entry-1');
      expect(hash, isNotNull);

      final search = OfflineReflectionVectorSearchService(
        repository: repository,
        inference: LocalReflectionEmbeddingInference(),
      );
      final hits = await search.searchSimilarReflection(
        reflection: entry.reflection,
      );
      expect(hits.map((hit) => hit.entryId), contains('entry-1'));

      worker.dispose();
      await EmbeddingIndexWorkerService.instance.dispose();
      await sqlite.close();
      AppSqliteDatabase.resetForTest();
      await dir.delete(recursive: true);
    });

    test('ReflectionEmbeddingText prioritizes reflection fields', () {
      final text = ReflectionEmbeddingText.fromReflection(
        _reflection(tension: 'pull between rest and work'),
      );
      expect(text, contains('pull between rest and work'));
      expect(text, contains('work'));
    });
  });
}
