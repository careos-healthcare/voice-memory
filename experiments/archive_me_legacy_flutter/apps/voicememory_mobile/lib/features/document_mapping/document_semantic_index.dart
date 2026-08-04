// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import '../../core/search/local_vector_search_engine.dart';
import '../../storage/encrypted_json_file_store.dart';
import '../document_ingestion/document_models.dart';
import 'document_concept_extractor.dart';

enum DocumentSemanticRecordKind { chunk, concept }

final class DocumentSemanticRecord {
  DocumentSemanticRecord({
    required this.id,
    required this.documentId,
    required this.kind,
    required this.text,
    required this.sourceIndex,
    required this.startChar,
    required this.endChar,
    required Float32List vector,
    required this.updatedAt,
  }) : vector = Float32List.fromList(vector);

  final String id;
  final String documentId;
  final DocumentSemanticRecordKind kind;
  final String text;
  final int sourceIndex;
  final int startChar;
  final int endChar;
  final Float32List vector;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'documentId': documentId,
    'kind': kind.name,
    'text': text,
    'sourceIndex': sourceIndex,
    'startChar': startChar,
    'endChar': endChar,
    'vector': vector.toList(growable: false),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  factory DocumentSemanticRecord.fromJson(
    Map<String, dynamic> json, {
    required int dimensions,
  }) {
    final rawVector = json['vector'];
    if (rawVector is! List) {
      throw const FormatException('Missing document semantic vector.');
    }
    final vector = Float32List.fromList(
      rawVector
          .map((value) {
            if (value is! num) {
              throw const FormatException('Invalid vector value.');
            }
            return value.toDouble();
          })
          .toList(growable: false),
    );
    _validateVector(vector, dimensions);
    final id = json['id'];
    final documentId = json['documentId'];
    final text = json['text'];
    final updatedAt = DateTime.tryParse(json['updatedAt'] as String? ?? '');
    if (id is! String ||
        id.isEmpty ||
        documentId is! String ||
        documentId.isEmpty ||
        text is! String ||
        updatedAt == null) {
      throw const FormatException('Invalid document semantic metadata.');
    }
    return DocumentSemanticRecord(
      id: id,
      documentId: documentId,
      kind: DocumentSemanticRecordKind.values.byName(
        json['kind'] as String? ?? '',
      ),
      text: text,
      sourceIndex: (json['sourceIndex'] as num?)?.toInt() ?? -1,
      startChar: (json['startChar'] as num?)?.toInt() ?? -1,
      endChar: (json['endChar'] as num?)?.toInt() ?? -1,
      vector: vector,
      updatedAt: updatedAt.toUtc(),
    );
  }
}

final class DocumentSemanticSnapshot {
  DocumentSemanticSnapshot({
    required Iterable<DocumentSemanticRecord> records,
    required this.revision,
  }) : records = List.unmodifiable(records);

  final List<DocumentSemanticRecord> records;
  final int revision;

  List<DocumentSemanticRecord> forDocument(String documentId) =>
      List.unmodifiable(
        records.where((record) => record.documentId == documentId),
      );
}

/// Authoritative encrypted metadata and vector index for imported documents.
final class DocumentSemanticIndex {
  DocumentSemanticIndex({
    required EncryptedJsonFileStore storage,
    LocalEmbeddingDriver embeddingDriver = const HashedLocalEmbeddingDriver(),
    this.driverId = 'hashed-local-document-v1',
    DateTime Function()? clock,
  }) : _storage = storage,
       _embeddingDriver = embeddingDriver,
       _clock = clock ?? DateTime.now;

  static const int schemaVersion = 1;

  final EncryptedJsonFileStore _storage;
  final LocalEmbeddingDriver _embeddingDriver;
  final String driverId;
  final DateTime Function() _clock;
  Future<void> _writeTail = Future<void>.value();

  int get dimensions => _embeddingDriver.dimensions;

  Future<DocumentSemanticSnapshot> load() async {
    await _writeTail.catchError((Object _) {});
    return _read();
  }

  Future<List<DocumentSemanticRecord>> indexDocument({
    required String documentId,
    required Iterable<DocumentChunk> chunks,
    Iterable<DocumentConcept> concepts = const [],
  }) => _serialized(() async {
    final snapshot = await _read();
    final records = {
      for (final record in snapshot.records)
        if (record.documentId != documentId) record.id: record,
    };
    final now = _clock().toUtc();
    for (final chunk in chunks) {
      final id = 'document:$documentId:chunk:${chunk.index}';
      records[id] = _record(
        id: id,
        documentId: documentId,
        kind: DocumentSemanticRecordKind.chunk,
        text: chunk.text,
        sourceIndex: chunk.index,
        startChar: chunk.startChar,
        endChar: chunk.endChar,
        updatedAt: now,
      );
    }
    for (final concept in concepts) {
      final id = 'document:$documentId:concept:${concept.index}';
      records[id] = _record(
        id: id,
        documentId: documentId,
        kind: DocumentSemanticRecordKind.concept,
        text: concept.text,
        sourceIndex: concept.index,
        startChar: concept.startChar,
        endChar: concept.endChar,
        updatedAt: now,
      );
    }
    final ordered = records.values.toList()..sort(_recordSort);
    await _write(ordered, snapshot.revision + 1);
    return List.unmodifiable(
      ordered.where((record) => record.documentId == documentId),
    );
  });

  Future<void> removeDocument(String documentId) => _serialized(() async {
    final snapshot = await _read();
    await _write(
      snapshot.records.where((record) => record.documentId != documentId),
      snapshot.revision + 1,
    );
  });

  Future<void> rollbackDocument(String documentId) =>
      removeDocument(documentId);

  DocumentSemanticRecord _record({
    required String id,
    required String documentId,
    required DocumentSemanticRecordKind kind,
    required String text,
    required int sourceIndex,
    required int startChar,
    required int endChar,
    required DateTime updatedAt,
  }) {
    final vector = _embeddingDriver.embed(text);
    _validateVector(vector, dimensions);
    return DocumentSemanticRecord(
      id: id,
      documentId: documentId,
      kind: kind,
      text: text,
      sourceIndex: sourceIndex,
      startChar: startChar,
      endChar: endChar,
      vector: vector,
      updatedAt: updatedAt,
    );
  }

  Future<DocumentSemanticSnapshot> _read() async {
    final raw = await _storage.readJson();
    if (raw == null) {
      return DocumentSemanticSnapshot(records: const [], revision: 0);
    }
    if (raw is! Map ||
        raw['schemaVersion'] != schemaVersion ||
        raw['driverId'] != driverId ||
        raw['dimensions'] != dimensions ||
        raw['records'] is! List) {
      throw const FormatException('Invalid document semantic index.');
    }
    final records = <DocumentSemanticRecord>[];
    final ids = <String>{};
    for (final row in (raw['records'] as List).whereType<Map>()) {
      final record = DocumentSemanticRecord.fromJson(
        Map<String, dynamic>.from(row),
        dimensions: dimensions,
      );
      if (!ids.add(record.id)) {
        throw const FormatException('Duplicate document semantic record.');
      }
      records.add(record);
    }
    records.sort(_recordSort);
    return DocumentSemanticSnapshot(
      records: records,
      revision: (raw['revision'] as num?)?.toInt() ?? 0,
    );
  }

  Future<void> _write(Iterable<DocumentSemanticRecord> records, int revision) {
    final ordered = records.toList()..sort(_recordSort);
    return _storage.writeJson({
      'schemaVersion': schemaVersion,
      'driverId': driverId,
      'dimensions': dimensions,
      'revision': revision,
      'records': ordered.map((record) => record.toJson()).toList(),
    });
  }

  Future<T> _serialized<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    _writeTail = _writeTail.catchError((Object _) {}).then((_) async {
      try {
        completer.complete(await operation());
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  static int _recordSort(
    DocumentSemanticRecord left,
    DocumentSemanticRecord right,
  ) => left.id.compareTo(right.id);
}

void _validateVector(Float32List vector, int dimensions) {
  if (vector.length != dimensions) {
    throw const FormatException('Document embedding dimension mismatch.');
  }
  var squaredNorm = 0.0;
  for (final value in vector) {
    if (!value.isFinite) {
      throw const FormatException('Non-finite document embedding.');
    }
    squaredNorm += value * value;
  }
  if (squaredNorm == 0 ||
      !squaredNorm.isFinite ||
      (math.sqrt(squaredNorm) - 1).abs() > 0.002) {
    throw const FormatException('Document embedding must be normalized.');
  }
}
