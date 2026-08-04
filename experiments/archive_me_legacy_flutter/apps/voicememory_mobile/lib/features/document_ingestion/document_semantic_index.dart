import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import '../../core/search/local_vector_search_engine.dart';
import '../../services/ai/sqlite_vec_vector_store.dart';
import '../../storage/encrypted_json_file_store.dart';
import 'document_models.dart';

final class DocumentVectorRecord {
  DocumentVectorRecord({
    required this.id,
    required this.documentId,
    required this.chunkIndex,
    required this.startChar,
    required this.endChar,
    required Float32List embedding,
    required DateTime updatedAt,
  }) : embedding = Float32List.fromList(embedding),
       updatedAt = updatedAt.toUtc();

  final String id;
  final String documentId;
  final int chunkIndex;
  final int startChar;
  final int endChar;
  final Float32List embedding;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'documentId': documentId,
    'chunkIndex': chunkIndex,
    'startChar': startChar,
    'endChar': endChar,
    'embedding': embedding.toList(growable: false),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory DocumentVectorRecord.fromJson(Map<String, dynamic> json) =>
      DocumentVectorRecord(
        id: json['id'] as String,
        documentId: json['documentId'] as String,
        chunkIndex: (json['chunkIndex'] as num).toInt(),
        startChar: (json['startChar'] as num).toInt(),
        endChar: (json['endChar'] as num).toInt(),
        embedding: Float32List.fromList(
          (json['embedding'] as List)
              .whereType<num>()
              .map((value) => value.toDouble())
              .toList(),
        ),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}

final class DocumentSemanticHit {
  const DocumentSemanticHit({required this.record, required this.similarity});

  final DocumentVectorRecord record;
  final double similarity;
}

/// Encrypted vectors are authoritative; sqlite-vec is a disposable KNN cache.
final class DocumentSemanticIndex {
  DocumentSemanticIndex({
    required this.storage,
    required this.vectorStore,
    LocalEmbeddingDriver? embeddingDriver,
    DateTime Function()? clock,
  }) : embeddingDriver = embeddingDriver ?? const HashedLocalEmbeddingDriver(),
       _clock = clock ?? DateTime.now;

  final EncryptedJsonFileStore storage;
  final SqliteVecVectorStore vectorStore;
  final LocalEmbeddingDriver embeddingDriver;
  final DateTime Function() _clock;
  Future<void> _tail = Future<void>.value();
  List<DocumentVectorRecord>? _records;
  List<DocumentVectorRecord>? _rollbackRecords;

  Future<List<DocumentVectorRecord>> records() =>
      _serialized(() async => List.unmodifiable(await _load()));

  Future<List<DocumentVectorRecord>> indexDocument(
    String documentId,
    Iterable<DocumentChunk> chunks,
  ) => _serialized(() async {
    final current = List<DocumentVectorRecord>.from(await _load());
    current.removeWhere((record) => record.documentId == documentId);
    final now = _clock().toUtc();
    final indexed = chunks
        .map(
          (chunk) => DocumentVectorRecord(
            id: _recordId(documentId, chunk.index),
            documentId: documentId,
            chunkIndex: chunk.index,
            startChar: chunk.startChar,
            endChar: chunk.endChar,
            embedding: embeddingDriver.embed(chunk.text),
            updatedAt: now,
          ),
        )
        .toList(growable: false);
    current.addAll(indexed);
    await _persistAndRebuild(current);
    return List.unmodifiable(indexed);
  });

  Future<void> removeDocument(String documentId) => _serialized(() async {
    final current = List<DocumentVectorRecord>.from(await _load());
    current.removeWhere((record) => record.documentId == documentId);
    await _persistAndRebuild(current);
  });

  Future<void> rebuild() => _serialized(() async {
    _rebuildVectorStore(await _load());
  });

  Future<bool> rollback() => _serialized(() async {
    final rollback = _rollbackRecords;
    if (rollback == null) return false;
    _rollbackRecords = null;
    await _persistAndRebuild(rollback, captureRollback: false);
    return true;
  });

  Future<List<DocumentSemanticHit>> searchText(
    String query, {
    int limit = 20,
    String? documentId,
  }) => searchVector(
    embeddingDriver.embed(query),
    limit: limit,
    documentId: documentId,
  );

  Future<List<DocumentSemanticHit>> searchVector(
    Float32List query, {
    int limit = 20,
    String? documentId,
  }) => _serialized(() async {
    final records = await _load();
    final byId = {for (final record in records) record.id: record};
    List<DocumentSemanticHit> hits;
    if (vectorStore.isAccelerated) {
      hits = vectorStore
          .search(query, limit: math.max(limit, 1).clamp(1, 500))
          .map(
            (hit) => DocumentSemanticHit(
              record: byId[hit.entryId]!,
              similarity: hit.cosineSimilarity,
            ),
          )
          .where(
            (hit) => documentId == null || hit.record.documentId == documentId,
          )
          .toList();
    } else {
      hits = records
          .where(
            (record) => documentId == null || record.documentId == documentId,
          )
          .map(
            (record) => DocumentSemanticHit(
              record: record,
              similarity: _cosine(query, record.embedding),
            ),
          )
          .toList();
    }
    hits.sort((left, right) {
      final score = right.similarity.compareTo(left.similarity);
      return score != 0 ? score : left.record.id.compareTo(right.record.id);
    });
    return List.unmodifiable(hits.take(limit.clamp(1, 500)));
  });

  Future<void> clear() => _serialized(() async {
    _records = <DocumentVectorRecord>[];
    await storage.writeJson(const {'schemaVersion': 1, 'records': []});
    if (vectorStore.isAccelerated) vectorStore.clear();
  });

  Future<List<DocumentVectorRecord>> _load() async {
    if (_records != null) return _records!;
    try {
      final raw = await storage.readJson();
      if (raw is! Map) return _records = <DocumentVectorRecord>[];
      final records = (raw['records'] as List? ?? const <Object>[])
          .whereType<Map>()
          .map(
            (row) =>
                DocumentVectorRecord.fromJson(Map<String, dynamic>.from(row)),
          )
          .where(
            (record) => record.embedding.length == embeddingDriver.dimensions,
          )
          .toList();
      _records = records;
      _rebuildVectorStore(records);
      return records;
    } on Object {
      return _records = <DocumentVectorRecord>[];
    }
  }

  Future<void> _persistAndRebuild(
    List<DocumentVectorRecord> records, {
    bool captureRollback = true,
  }) async {
    if (captureRollback && _records != null) {
      _rollbackRecords = List<DocumentVectorRecord>.from(_records!);
    }
    records.sort((left, right) => left.id.compareTo(right.id));
    await storage.writeJson({
      'schemaVersion': 1,
      'records': records.map((record) => record.toJson()).toList(),
    });
    _records = records;
    _rebuildVectorStore(records);
  }

  void _rebuildVectorStore(Iterable<DocumentVectorRecord> records) {
    if (!vectorStore.isAccelerated) return;
    vectorStore.replaceAll(
      records.map(
        (record) => SqliteVecRecord(
          entryId: record.id,
          embedding: record.embedding,
          clusterType: 'document',
          updatedAt: record.updatedAt,
          confidence: 1,
          nodeIds: const [],
          tags: [record.documentId],
        ),
      ),
    );
  }

  Future<T> _serialized<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    _tail = _tail.catchError((Object _) {}).then((_) async {
      try {
        completer.complete(await operation());
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<void> dispose() async {
    await _tail.catchError((Object _) {});
    vectorStore.close();
  }

  static String _recordId(String documentId, int chunkIndex) =>
      'docvec_${_hash('$documentId:$chunkIndex')}';
}

double _cosine(Float32List left, Float32List right) {
  if (left.length != right.length) return -1;
  var dot = 0.0;
  var leftNorm = 0.0;
  var rightNorm = 0.0;
  for (var index = 0; index < left.length; index++) {
    dot += left[index] * right[index];
    leftNorm += left[index] * left[index];
    rightNorm += right[index] * right[index];
  }
  if (leftNorm == 0 || rightNorm == 0) return 0;
  return dot / math.sqrt(leftNorm * rightNorm);
}

String _hash(String value) {
  var hash = 0x811c9dc5;
  for (final unit in value.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}
