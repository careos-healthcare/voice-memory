import 'dart:math' as math;

import 'package:archiveme_mobile/features/insight_engine/hybrid_search_engine.dart';
import 'package:archiveme_mobile/features/insight_engine/hybrid_search_models.dart';
import 'package:archiveme_mobile/features/insight_engine/reciprocal_rank_fusion.dart';
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

List<double> _blendVectors(List<double> a, List<double> b, {required double weightA}) {
  final blended = List<double>.filled(memoryTranscriptEmbeddingDimensions, 0);
  for (var i = 0; i < memoryTranscriptEmbeddingDimensions; i++) {
    blended[i] = (a[i] * weightA) + (b[i] * (1 - weightA));
  }
  final norm = math.sqrt(blended.fold<double>(0, (sum, value) => sum + value * value));
  if (norm == 0) return blended;
  return blended.map((value) => value / norm).toList(growable: false);
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(AppSqliteDatabase.resetForTest);

  group('ReciprocalRankFusion', () {
    test('promotes ids appearing in both ranked lists', () {
      const fusion = ReciprocalRankFusion(k: 60);
      final fused = fusion.fuse([
        ['shared', 'keyword-only'],
        ['vector-only', 'shared'],
      ]);

      expect(fused.first, 'shared');
    });
  });

  group('MemoryTranscriptSearchRepository', () {
    late AppSqliteDatabase db;
    late JournalSqliteRepository journalRepo;
    late MemoryTranscriptSearchRepository searchRepo;

    setUp(() async {
      db = await AppSqliteDatabase.open(filePath: ':memory:');
      journalRepo = JournalSqliteRepository(db);
      searchRepo = MemoryTranscriptSearchRepository(db);
    });

    test('FTS5 stays synchronized on journal insert/update/delete', () async {
      await journalRepo.mirrorEntireRemoteState([
        _entry(id: 'e1', transcript: 'quiet morning walk'),
        _entry(id: 'e2', transcript: 'busy meeting about budgets'),
      ]);

      var keywordHits = await searchRepo.keywordSearch(
        query: 'meeting budgets',
        limit: 5,
      );
      expect(keywordHits, ['e2']);

      await journalRepo.mirrorEntireRemoteState([
        _entry(id: 'e1', transcript: 'quiet morning walk'),
        _entry(id: 'e2', transcript: 'updated meeting notes about budgets'),
        _entry(id: 'e3', transcript: 'meeting prep for budgets'),
      ]);

      keywordHits = await searchRepo.keywordSearch(
        query: 'budgets meeting',
        limit: 5,
      );
      expect(keywordHits, containsAll(['e2', 'e3']));

      await journalRepo.mirrorEntireRemoteState([
        _entry(id: 'e1', transcript: 'quiet morning walk'),
      ]);

      final ftsRows = await db.database.query(Migration005HybridSearch.ftsTable);
      expect(ftsRows, hasLength(1));
      expect(ftsRows.single['entry_id'], 'e1');
    });

    test('vectorSearch ranks by cosine similarity', () async {
      await journalRepo.mirrorEntireRemoteState([
        _entry(id: 'near', transcript: 'near'),
        _entry(id: 'far', transcript: 'far'),
      ]);

      final query = _unitVector(0);
      final near = _blendVectors(query, _unitVector(1), weightA: 0.95);
      final far = _unitVector(99);

      await searchRepo.upsertEmbedding(entryId: 'near', embedding: near);
      await searchRepo.upsertEmbedding(entryId: 'far', embedding: far);

      final hits = await searchRepo.vectorSearch(
        queryEmbedding: query,
        limit: 2,
      );

      expect(hits, ['near', 'far']);
    });
  });

  group('HybridSearchEngine', () {
    late HybridSearchEngine engine;
    late JournalSqliteRepository journalRepo;
    late MemoryTranscriptSearchRepository searchRepo;

    setUp(() async {
      final db = await AppSqliteDatabase.open(filePath: ':memory:');
      journalRepo = JournalSqliteRepository(db);
      searchRepo = MemoryTranscriptSearchRepository(db);
      engine = HybridSearchEngine(repository: searchRepo);
    });

    test('keyword-only ranking prefers lexical matches', () async {
      await journalRepo.mirrorEntireRemoteState([
        _entry(id: 'budget', transcript: 'detailed budget planning session'),
        _entry(id: 'walk', transcript: 'morning walk in the park'),
      ]);

      final hits = await engine.search(
        keywordQuery: 'budget planning',
        limit: 5,
      );

      expect(hits.map((hit) => hit.entryId), ['budget']);
      expect(hits.first.keywordRank, 1);
      expect(hits.first.vectorRank, isNull);
    });

    test('vector-only ranking prefers nearest embedding', () async {
      await journalRepo.mirrorEntireRemoteState([
        _entry(id: 'target', transcript: 'target'),
        _entry(id: 'other', transcript: 'other'),
      ]);

      final query = _unitVector(4);
      await engine.upsertEmbedding(
        entryId: 'target',
        embedding: _blendVectors(query, _unitVector(5), weightA: 0.9),
      );
      await engine.upsertEmbedding(
        entryId: 'other',
        embedding: _unitVector(120),
      );

      final hits = await engine.search(
        queryEmbedding: query,
        limit: 5,
      );

      expect(hits.map((hit) => hit.entryId), ['target', 'other']);
      expect(hits.first.vectorRank, 1);
      expect(hits.first.keywordRank, isNull);
    });

    test('hybrid fusion boosts entries strong in both channels', () async {
      await journalRepo.mirrorEntireRemoteState([
        _entry(id: 'both', transcript: 'budget planning for the quarter'),
        _entry(id: 'keyword-only', transcript: 'budget spreadsheet review'),
        _entry(id: 'vector-only', transcript: 'unrelated transcript text'),
      ]);

      final queryEmbedding = _unitVector(2);
      await engine.upsertEmbedding(
        entryId: 'both',
        embedding: _blendVectors(queryEmbedding, _unitVector(3), weightA: 0.92),
      );
      await engine.upsertEmbedding(
        entryId: 'keyword-only',
        embedding: _unitVector(200),
      );
      await engine.upsertEmbedding(
        entryId: 'vector-only',
        embedding: queryEmbedding,
      );

      final hits = await engine.search(
        keywordQuery: 'budget planning',
        queryEmbedding: queryEmbedding,
        limit: 3,
      );

      expect(hits, isNotEmpty);
      expect(hits.first.entryId, 'both');
      expect(hits.first.keywordRank, isNotNull);
      expect(hits.first.vectorRank, isNotNull);
      expect(hits.first.score, greaterThan(hits[1].score));
    });
  });
}
