import 'package:archiveme_mobile/features/insight_engine/hybrid_search_engine.dart';
import 'package:archiveme_mobile/features/search/local_reflection_embedding_inference.dart';
import 'package:archiveme_mobile/features/search/reflection_text_processor.dart';
import 'package:archiveme_mobile/features/search/semantic_vector_fusion.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/storage/sqlite/app_sqlite_database.dart';
import 'package:archiveme_mobile/storage/sqlite/journal_sqlite_repository.dart';
import 'package:archiveme_mobile/storage/sqlite/memory_transcript_search_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../storage/sqlite/support/sqlite_test_database.dart';

/// A corpus where BM25 and the stand-in encoder disagree, and the encoder is
/// wrong.
///
/// `ReflectionTextProcessor` hashes the i-th word to slot i of a 128-wide
/// tensor and `LocalReflectionEmbeddingInference` projects that through fixed
/// random weights, so cosine similarity measures where words sit, not what
/// they mean. Against the query "budget planning" this corpus scores:
///
/// * `anxious-money` 0.740 — shares no word with the query;
/// * `budget-cycle`  0.669;
/// * `budget-deck`   0.294 — the entry BM25 ranks first.
///
/// The encoder therefore puts an entry about money worries above both entries
/// that are literally about budget planning.
const _query = 'budget planning';

const _corpus = <String, String>{
  'budget-deck': 'we reviewed the quarterly budget planning deck',
  'budget-cycle': 'the annual budget planning cycle starts again next month',
  'anxious-money': 'i felt anxious about money again this evening',
};

JournalEntry _entry(String id, String transcript) => JournalEntry(
  id: id,
  createdAt: DateTime(2026, 1, 2),
  transcript: transcript,
  durationSeconds: 30,
  reflection: const Reflection(
    mood: 'calm',
    emotionalIntensity: 1,
    recurringThemes: [],
    exactLanguagePattern: '',
    concreteObservation: '',
    repeatedSignal: '',
  ),
);

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() {
    SemanticVectorFusion.debugEnabled = null;
    AppSqliteDatabase.resetForTest();
  });

  group('SemanticVectorFusion', () {
    test('is off in the shipped build', () {
      expect(SemanticVectorFusion.enabledByBuild, isFalse);
      expect(SemanticVectorFusion.enabled, isFalse);
    });

    test('stays off for the stand-in encoder even when the flag is on', () {
      SemanticVectorFusion.debugEnabled = true;
      expect(SemanticVectorFusion.enabled, isTrue);
      expect(
        SemanticVectorFusion.isEnabledFor(LocalReflectionEmbeddingInference()),
        isFalse,
        reason: 'the flag alone must not put the noise leg back',
      );
    });

    test('the stand-in encoder reports that it carries no meaning', () {
      expect(
        LocalReflectionEmbeddingInference().producesSemanticVectors,
        isFalse,
      );
    });
  });

  group('HybridSearchEngine BM25 ranking', () {
    late MemoryTranscriptSearchRepository searchRepo;
    late List<double> queryEmbedding;

    Future<List<double>> embed(String text) => LocalReflectionEmbeddingInference()
        .embed(ReflectionTextProcessor.buildInputTensor(text));

    HybridSearchEngine engineWithFusion({required bool enabled}) =>
        HybridSearchEngine(
          repository: searchRepo,
          vectorFusionEnabled: enabled,
        );

    setUp(() async {
      final db = await openTestAppSqliteDatabase();
      final journalRepo = JournalSqliteRepository(db);
      searchRepo = MemoryTranscriptSearchRepository(db);

      await journalRepo.mirrorEntireRemoteState([
        for (final entry in _corpus.entries) _entry(entry.key, entry.value),
      ]);
      for (final entry in _corpus.entries) {
        await searchRepo.upsertEmbedding(
          entryId: entry.key,
          embedding: await embed(entry.value),
        );
      }
      queryEmbedding = await embed(_query);
    });

    test('BM25 alone answers the query correctly', () async {
      expect(
        await searchRepo.keywordSearch(query: _query),
        ['budget-deck', 'budget-cycle'],
      );
    });

    test('the stand-in encoder ranks an unrelated entry first', () async {
      final hits = await searchRepo.vectorSearchWithScores(
        queryEmbedding: queryEmbedding,
      );

      expect(hits.first.entryId, 'anxious-money');
      expect(hits.last.entryId, 'budget-deck');
    });

    test('before: fusion admits an entry sharing no word with the query',
        () async {
      final hits = await engineWithFusion(enabled: true).search(
        keywordQuery: _query,
        queryEmbedding: queryEmbedding,
        limit: 10,
      );

      expect(
        hits.map((hit) => hit.entryId),
        contains('anxious-money'),
        reason: 'the vector leg contributed a result BM25 never matched',
      );
    });

    test('before: fusion drops the BM25 top hit below both other entries',
        () async {
      // A candidate limit smaller than the corpus is what production sees at
      // scale: the vector leg fills its slots before the keyword winner gets
      // one, so the winner earns a single reciprocal-rank vote and anything
      // appearing in both lists overtakes it.
      final hits = await engineWithFusion(enabled: true).search(
        keywordQuery: _query,
        queryEmbedding: queryEmbedding,
        limit: 10,
        candidateLimit: 2,
      );

      final ids = hits.map((hit) => hit.entryId).toList(growable: false);
      expect(ids.first, 'budget-cycle', reason: 'BM25 ranked this second');
      expect(
        ids.indexOf('budget-deck'),
        greaterThan(ids.indexOf('anxious-money')),
        reason:
            'the BM25 top hit now sits below an entry with no query term in it',
      );
    });

    test('after: the shipped engine returns BM25 ranking untouched', () async {
      final hits = await engineWithFusion(enabled: false).search(
        keywordQuery: _query,
        queryEmbedding: queryEmbedding,
        limit: 10,
        candidateLimit: 2,
      );

      expect(hits.map((hit) => hit.entryId), ['budget-deck', 'budget-cycle']);
      expect(hits.map((hit) => hit.keywordRank), [1, 2]);
      expect(
        hits.map((hit) => hit.vectorRank),
        everyElement(isNull),
        reason: 'no vector leg contributed to this ranking',
      );
    });

    test('after: the default engine matches the explicit off switch', () async {
      final defaults = await HybridSearchEngine(repository: searchRepo).search(
        keywordQuery: _query,
        queryEmbedding: queryEmbedding,
        limit: 10,
      );

      expect(defaults.map((hit) => hit.entryId), ['budget-deck', 'budget-cycle']);
    });

    test('exact-duplicate detection still works through vector search',
        () async {
      final hits = await searchRepo.vectorSearchWithScores(
        queryEmbedding: await embed(_corpus['budget-deck']!),
        limit: 5,
      );

      expect(hits.first.entryId, 'budget-deck');
      expect(hits.first.cosineSimilarity, closeTo(1, 1e-6));
    });
  });
}
