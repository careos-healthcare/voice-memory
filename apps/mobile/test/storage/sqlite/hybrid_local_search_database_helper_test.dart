import 'dart:math' as math;
import 'dart:typed_data';

import 'support/sqlite_test_database.dart';

import 'package:archiveme_mobile/features/insight_engine/hybrid_search_models.dart';
import 'package:archiveme_mobile/features/search/local_reflection_embedding_inference.dart';
import 'package:archiveme_mobile/features/search/reflection_embedding_inference.dart';
import 'package:archiveme_mobile/features/search/semantic_vector_fusion.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/storage/sqlite/app_sqlite_database.dart';
import 'package:archiveme_mobile/storage/sqlite/hybrid_local_search/database_helper.dart';
import 'package:archiveme_mobile/storage/sqlite/hybrid_local_search/hybrid_search_result_merger.dart';
import 'package:archiveme_mobile/storage/sqlite/journal_sqlite_repository.dart';
import 'package:archiveme_mobile/storage/sqlite/memory_transcript_search_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Stands in for an encoder that carries meaning, so the fusion path stays
/// covered while the shipped build has none.
final class _SemanticEncoderDouble implements ReflectionEmbeddingInference {
  final _delegate = LocalReflectionEmbeddingInference();

  @override
  bool get producesSemanticVectors => true;

  @override
  Future<List<double>> embed(Float32List inputTensor) =>
      _delegate.embed(inputTensor);
}

JournalEntry _entry({
  required String id,
  required String transcript,
}) {
  return JournalEntry(
    id: id,
    createdAt: DateTime(2026, 1, id.hashCode % 28 + 1),
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
}

List<double> _unitVector(int index) {
  final vector = List<double>.filled(memoryTranscriptEmbeddingDimensions, 0);
  vector[index % memoryTranscriptEmbeddingDimensions] = 1;
  return vector;
}

List<double> _blendVectors(
  List<double> a,
  List<double> b, {
  required double weightA,
}) {
  final blended = List<double>.filled(memoryTranscriptEmbeddingDimensions, 0);
  for (var i = 0; i < memoryTranscriptEmbeddingDimensions; i++) {
    blended[i] = (a[i] * weightA) + (b[i] * (1 - weightA));
  }
  final norm = math.sqrt(
    blended.fold<double>(0, (sum, value) => sum + value * value),
  );
  if (norm == 0) return blended;
  return blended.map((value) => value / norm).toList(growable: false);
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(AppSqliteDatabase.resetForTest);

  group('HybridSearchResultMerger', () {
    test('mergeAndRank promotes ids appearing in both channels', () {
      const merger = HybridSearchResultMerger();
      final hits = merger.mergeAndRank(
        keywordHits: const [
          KeywordSearchHit(entryId: 'shared', rank: 1),
          KeywordSearchHit(entryId: 'keyword-only', rank: 2),
        ],
        semanticHits: const [
          SemanticSearchHit(
            entryId: 'vector-only',
            rank: 1,
            cosineSimilarity: 0.9,
          ),
          SemanticSearchHit(
            entryId: 'shared',
            rank: 2,
            cosineSimilarity: 0.8,
          ),
        ],
      );

      expect(hits.first.entryId, 'shared');
      expect(hits.first.keywordRank, 1);
      expect(hits.first.vectorRank, 2);
    });
  });

  group('DatabaseHelper', () {
    late DatabaseHelper helper;
    late JournalSqliteRepository journalRepo;
    late MemoryTranscriptSearchRepository searchRepo;

    setUp(() async {
      final db = await openTestAppSqliteDatabase();
      journalRepo = JournalSqliteRepository(db);
      searchRepo = MemoryTranscriptSearchRepository(db);
      helper = DatabaseHelper(
        searchRepository: searchRepo,
        embeddingInference: LocalReflectionEmbeddingInference(),
      );
    });

    test('embedQuery returns normalized 384-d vector', () async {
      final embedding = await helper.embedQuery('budget planning notes');

      expect(embedding, hasLength(memoryTranscriptEmbeddingDimensions));
      final norm = math.sqrt(
        embedding.fold<double>(0, (sum, value) => sum + value * value),
      );
      expect(norm, closeTo(1, 0.0001));
    });

    test('searchKeywords returns BM25-ranked FTS5 hits', () async {
      await journalRepo.mirrorEntireRemoteState([
        _entry(id: 'budget', transcript: 'detailed budget planning session'),
        _entry(id: 'walk', transcript: 'morning walk in the park'),
      ]);

      final hits = await helper.searchKeywords('budget planning', limit: 5);

      expect(hits.map((hit) => hit.entryId), ['budget']);
      expect(hits.first.rank, 1);
    });

    test('searchSemantic ranks by cosine similarity', () async {
      await journalRepo.mirrorEntireRemoteState([
        _entry(id: 'near', transcript: 'near'),
        _entry(id: 'far', transcript: 'far'),
      ]);

      final query = _unitVector(0);
      final near = _blendVectors(query, _unitVector(1), weightA: 0.95);
      final far = _unitVector(99);

      await searchRepo.upsertEmbedding(entryId: 'near', embedding: near);
      await searchRepo.upsertEmbedding(entryId: 'far', embedding: far);

      final hits = await helper.searchSemantic(query, limit: 2);

      expect(hits.map((hit) => hit.entryId), ['near', 'far']);
      expect(hits.first.rank, 1);
      expect(hits.first.cosineSimilarity, greaterThan(hits.last.cosineSimilarity));
    });

    test('search fuses keyword and semantic channels for hybrid query', () async {
      await journalRepo.mirrorEntireRemoteState([
        _entry(id: 'both', transcript: 'budget planning for the quarter'),
        _entry(id: 'keyword-only', transcript: 'budget spreadsheet review'),
        _entry(id: 'vector-only', transcript: 'unrelated transcript text'),
      ]);

      final queryEmbedding = _unitVector(2);
      await searchRepo.upsertEmbedding(
        entryId: 'both',
        embedding: _blendVectors(queryEmbedding, _unitVector(3), weightA: 0.92),
      );
      await searchRepo.upsertEmbedding(
        entryId: 'keyword-only',
        embedding: _unitVector(200),
      );
      await searchRepo.upsertEmbedding(
        entryId: 'vector-only',
        embedding: queryEmbedding,
      );

      // The helper only opens the semantic channel for an encoder that claims
      // to carry meaning — see [SemanticVectorFusion]. The stand-in used
      // elsewhere in this file does not, so the fusion path needs a stand-in
      // that does.
      final fusing = DatabaseHelper(
        searchRepository: searchRepo,
        embeddingInference: _SemanticEncoderDouble(),
      );
      SemanticVectorFusion.debugEnabled = true;
      addTearDown(() => SemanticVectorFusion.debugEnabled = null);

      final hits = await fusing.search(
        'budget planning',
        limit: 3,
      );

      expect(hits, isNotEmpty);
      expect(hits.first.entryId, 'both');
      expect(hits.first.keywordRank, isNotNull);
      expect(hits.first.vectorRank, isNotNull);
      expect(hits.first.score, greaterThan(hits[1].score));
    });

    test('search returns BM25 ranking alone for the stand-in encoder', () async {
      await journalRepo.mirrorEntireRemoteState([
        _entry(id: 'both', transcript: 'budget planning for the quarter'),
        _entry(id: 'keyword-only', transcript: 'budget spreadsheet review'),
        _entry(id: 'vector-only', transcript: 'unrelated transcript text'),
      ]);
      await searchRepo.upsertEmbedding(
        entryId: 'vector-only',
        embedding: _unitVector(2),
      );

      final hits = await helper.search('budget planning', limit: 3);

      expect(hits.map((hit) => hit.entryId), isNot(contains('vector-only')));
      expect(hits.map((hit) => hit.vectorRank), everyElement(isNull));
    });

    test('mergeAndRank preserves keyword-only ordering', () {
      final hits = helper.mergeAndRank(
        keywordHits: const [
          KeywordSearchHit(entryId: 'alpha', rank: 1),
          KeywordSearchHit(entryId: 'beta', rank: 2),
        ],
        semanticHits: const [],
        limit: 2,
      );

      expect(hits.map((hit) => hit.entryId), ['alpha', 'beta']);
      expect(hits.every((hit) => hit.keywordRank != null), isTrue);
      expect(hits.every((hit) => hit.vectorRank == null), isTrue);
    });
  });
}
