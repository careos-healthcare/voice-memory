import 'package:archiveme_mobile/features/insights/rag/local_routine_rag_engine.dart';
import 'package:archiveme_mobile/features/insights/rag/routine_rag_models.dart';
import 'package:archiveme_mobile/workers/embedding/embedding_index_worker_service.dart';
import 'package:archiveme_mobile/features/search/reflection_embedding_index_worker.dart';
import 'package:archiveme_mobile/features/search/reflection_embedding_repository.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';
import 'package:archiveme_mobile/storage/sqlite/app_sqlite_database.dart';
import 'package:archiveme_mobile/storage/sqlite/journal_sqlite_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../../storage/sqlite/support/sqlite_test_database.dart';

Reflection _reflection({
  String mood = 'anxious',
  List<String> themes = const ['work'],
  String tension = 'I want rest but keep accepting more',
}) {
  return Reflection(
    mood: mood,
    emotionalIntensity: 6,
    recurringThemes: themes,
    exactLanguagePattern: 'I keep saying yes',
    concreteObservation: 'Accepted another late meeting',
    repeatedSignal: 'overcommitment',
    tensionOrContradiction: tension,
    nextSmallAction: 'Block thirty minutes tomorrow morning',
  );
}

JournalEntry _entry({
  required String id,
  required Reflection reflection,
  DateTime? createdAt,
}) {
  return JournalEntry(
    id: id,
    createdAt: createdAt ?? DateTime.utc(2026, 8, 10),
    transcript: 'Work has been heavy and I feel stretched thin.',
    durationSeconds: 40,
    reflection: reflection,
  );
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(AppSqliteDatabase.resetForTest);

  group('LocalRoutineRagEngine', () {
    test('generates morning prompt from matching archive context offline', () async {
      final dir = await Directory.systemTemp.createTemp('rag_journal_');
      final dbPath = '${dir.path}/journal.sqlite';
      final sqlite = await AppSqliteDatabase.open(
        filePath: dbPath,
        password: testSqliteEncryptionPassword,
      );
      final journalRepo = JournalSqliteRepository(sqlite);
      final embeddingRepo = ReflectionEmbeddingRepository(sqlite);

      final entries = [
        _entry(
          id: 'older-work',
          reflection: _reflection(
            mood: 'tired',
            tension: 'I want rest but keep accepting more work',
          ),
          createdAt: DateTime.utc(2026, 8, 8),
        ),
        _entry(
          id: 'latest-work',
          reflection: _reflection(
            mood: 'anxious',
            tension: 'Still saying yes before checking my calendar',
          ),
          createdAt: DateTime.utc(2026, 8, 11),
        ),
      ];

      await journalRepo.upsertEntries(entries);

      final journalStore = await JournalStore.open('${dir.path}/journal.json');
      final worker = ReflectionEmbeddingIndexWorker(
        repository: embeddingRepo,
        journalStore: journalStore,
        sqliteFilePath: dbPath,
        sqliteEncryptionPassword: testSqliteEncryptionPassword,
        debounce: Duration.zero,
      );
      for (final entry in entries) {
        await worker.indexEntry(entry);
      }

      final engine = await LocalRoutineRagEngine.create(
        journalRepository: journalRepo,
        embeddingRepository: embeddingRepo,
      );

      final prompt = await engine.generateMorningPrompt(
        latestEntry: entries.last,
        archiveEntries: entries,
      );

      expect(prompt.routine, JournalRoutineKind.morning);
      expect(prompt.primaryPrompt, isNotEmpty);
      expect(prompt.contextChunks, isNotEmpty);
      expect(prompt.contextChunks.first.entryId, isNot(''));
      expect(prompt.supportingPrompts, isNotEmpty);
      expect(prompt.reflectionSeed, isNotNull);

      worker.dispose();
      await EmbeddingIndexWorkerService.instance.dispose();
      await sqlite.close();
      AppSqliteDatabase.resetForTest();
      await dir.delete(recursive: true);
    });

    test('generates evening prompt referencing tension context', () async {
      final dir = await Directory.systemTemp.createTemp('rag_evening_');
      final dbPath = '${dir.path}/journal.sqlite';
      final sqlite = await AppSqliteDatabase.open(
        filePath: dbPath,
        password: testSqliteEncryptionPassword,
      );
      final journalRepo = JournalSqliteRepository(sqlite);
      final embeddingRepo = ReflectionEmbeddingRepository(sqlite);

      final entry = _entry(
        id: 'evening-entry',
        reflection: _reflection(
          mood: 'restless',
          tension: 'I say I am fine but feel lonely after meetings',
        ),
      );
      await journalRepo.upsertEntries([entry]);

      final journalStore = await JournalStore.open('${dir.path}/journal.json');
      final worker = ReflectionEmbeddingIndexWorker(
        repository: embeddingRepo,
        journalStore: journalStore,
        sqliteFilePath: dbPath,
        sqliteEncryptionPassword: testSqliteEncryptionPassword,
        debounce: Duration.zero,
      );
      await worker.indexEntry(entry);

      final engine = await LocalRoutineRagEngine.create(
        journalRepository: journalRepo,
        embeddingRepository: embeddingRepo,
      );

      final prompt = await engine.generateEveningPrompt(
        latestEntry: entry,
        archiveEntries: [entry],
      );

      expect(prompt.routine, JournalRoutineKind.evening);
      expect(
        prompt.primaryPrompt.toLowerCase(),
        anyOf(contains('rest'), contains('unresolved'), contains('lonely')),
      );

      worker.dispose();
      await EmbeddingIndexWorkerService.instance.dispose();
      await sqlite.close();
      AppSqliteDatabase.resetForTest();
      await dir.delete(recursive: true);
    });
  });
}
