import 'dart:io';
import 'dart:math' as math;

import '../../storage/sqlite/support/sqlite_test_database.dart';

import 'package:archiveme_mobile/features/insight_engine/hybrid_search_models.dart';
import 'package:archiveme_mobile/features/search/data/hybrid_search_objectbox_store.dart';
import 'package:archiveme_mobile/features/search/data/hybrid_search_repository.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/storage/sqlite/app_sqlite_database.dart';
import 'package:archiveme_mobile/storage/sqlite/journal_sqlite_repository.dart';
import 'package:archiveme_mobile/storage/sqlite/memory_transcript_search_repository.dart';
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

  group('HybridSearchRepository', () {
    late Directory objectBoxDir;
    late HybridSearchObjectBoxStore objectBoxStore;
    late AppSqliteDatabase sqlite;
    late JournalSqliteRepository journalRepo;
    late MemoryTranscriptSearchRepository lexicalSearch;
    late HybridSearchRepository repository;

    setUp(() async {
      objectBoxDir = await Directory.systemTemp.createTemp('hybrid_search_obx_');
      objectBoxStore = HybridSearchObjectBoxStore.openSync(
        directory: objectBoxDir.path,
      );
      sqlite = await openTestAppSqliteDatabase();
      journalRepo = JournalSqliteRepository(sqlite);
      lexicalSearch = MemoryTranscriptSearchRepository(sqlite);
      repository = HybridSearchRepository(
        lexicalSearch: lexicalSearch,
        embeddedNodeBox: objectBoxStore.embeddedNodeBox,
      );
    });

    tearDown(() {
      objectBoxStore.close();
      if (objectBoxDir.existsSync()) {
        objectBoxDir.deleteSync(recursive: true);
      }
    });

    test('HNSW semantic search ranks nearest embeddings', () async {
      final query = _unitVector(0);
      final near = _blendVectors(query, _unitVector(1), weightA: 0.95);
      final far = _unitVector(99);

      await repository.upsertEmbedding(entryId: 'near', embedding: near);
      await repository.upsertEmbedding(entryId: 'far', embedding: far);

      final hits = await repository.search(
        queryEmbedding: query,
        limit: 2,
      );

      expect(hits.map((hit) => hit.entryId), ['near', 'far']);
      expect(hits.first.vectorRank, 1);
    });

    test('parallel FTS + HNSW search fuses with RRF', () async {
      await journalRepo.mirrorEntireRemoteState([
        _entry(id: 'both', transcript: 'budget planning for the quarter'),
        _entry(id: 'keyword-only', transcript: 'budget spreadsheet review'),
        _entry(id: 'vector-only', transcript: 'unrelated transcript text'),
      ]);

      final queryEmbedding = _unitVector(2);
      await repository.upsertEmbedding(
        entryId: 'both',
        embedding: _blendVectors(queryEmbedding, _unitVector(3), weightA: 0.92),
      );
      await repository.upsertEmbedding(
        entryId: 'keyword-only',
        embedding: _unitVector(200),
      );
      await repository.upsertEmbedding(
        entryId: 'vector-only',
        embedding: queryEmbedding,
      );

      final hits = await repository.search(
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

    test('deleteEmbedding removes node from HNSW index', () async {
      final vector = _unitVector(4);
      await repository.upsertEmbedding(entryId: 'gone', embedding: vector);
      await repository.deleteEmbedding('gone');

      final hits = await repository.search(
        queryEmbedding: vector,
        limit: 5,
      );

      expect(hits, isEmpty);
    });
  });
}
