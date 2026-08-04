import 'dart:typed_data';

import '../../services/ai/sqlite_vec_vector_store.dart';
import 'document_semantic_index.dart';

/// Rebuildable, document-only sqlite-vec accelerator.
///
/// The encrypted [DocumentSemanticIndex] remains authoritative; this database
/// contains only precomputed vectors and can be deleted and rebuilt at any time.
final class DocumentVectorStore {
  DocumentVectorStore._(this._store);

  final SqliteVecVectorStore _store;

  bool get isAccelerated => _store.isAccelerated;
  String? get unavailableReason => _store.unavailableReason;
  int get count => _store.count;

  static Future<DocumentVectorStore> open({
    required String databasePath,
    required int dimensions,
  }) async => DocumentVectorStore._(
    await SqliteVecVectorStore.open(
      databasePath: databasePath,
      dimensions: dimensions,
    ),
  );

  void rebuild(DocumentSemanticSnapshot snapshot) {
    _store.replaceAll(snapshot.records.map(_sqliteRecord));
  }

  void removeDocument(
    String documentId,
    DocumentSemanticSnapshot remainingSnapshot,
  ) {
    if (remainingSnapshot.records.any(
      (record) => record.documentId == documentId,
    )) {
      throw StateError('Authoritative document records still exist.');
    }
    rebuild(remainingSnapshot);
  }

  void rollbackDocument(
    String documentId,
    DocumentSemanticSnapshot remainingSnapshot,
  ) => removeDocument(documentId, remainingSnapshot);

  List<SqliteVecHit> search(
    Float32List query, {
    int limit = 20,
    DocumentSemanticRecordKind? kind,
  }) => _store.search(query, limit: limit, clusterType: kind?.name);

  void clear() => _store.clear();
  void close() => _store.close();

  static SqliteVecRecord _sqliteRecord(DocumentSemanticRecord record) =>
      SqliteVecRecord(
        entryId: record.id,
        embedding: record.vector,
        clusterType: record.kind.name,
        updatedAt: record.updatedAt,
        confidence: 1,
        nodeIds: [record.documentId],
        tags: {'document', record.kind.name},
      );
}
