import 'dart:typed_data';

import 'package:archiveme_mobile/core/constants/database_constants.dart';
import 'package:archiveme_mobile/database/app_database.dart';
import 'package:drift/drift.dart';

part 'transcript_embeddings_dao.g.dart';

@DriftAccessor(tables: [MemoryTranscriptEmbeddings, JournalImageEmbeddings])
class TranscriptEmbeddingsDao extends DatabaseAccessor<AppDatabase>
    with _$TranscriptEmbeddingsDaoMixin {
  TranscriptEmbeddingsDao(super.db);

  Future<void> upsertTranscriptEmbedding({
    required String entryId,
    required Uint8List embeddingBlob,
    required int dimensions,
  }) async {
    if (entryId.isEmpty) return;
    await into(memoryTranscriptEmbeddings).insertOnConflictUpdate(
      MemoryTranscriptEmbeddingsCompanion.insert(
        entryId: entryId,
        embedding: embeddingBlob,
        dimensions: dimensions,
      ),
    );
  }

  Future<void> deleteTranscriptEmbedding(String entryId) async {
    if (entryId.isEmpty) return;
    await (delete(memoryTranscriptEmbeddings)
          ..where((t) => t.entryId.equals(entryId)))
        .go();
  }

  Future<List<({String entryId, Uint8List embedding})>> loadAllTranscriptEmbeddings({
    int? limit,
  }) async {
    final query = select(memoryTranscriptEmbeddings);
    if (limit != null) {
      query.limit(limit);
    }
    final rows = await query.get();
    return rows
        .map((row) => (entryId: row.entryId, embedding: row.embedding))
        .toList(growable: false);
  }

  Future<void> upsertImageEmbedding({
    required String evidenceId,
    required String entryId,
    required Uint8List embeddingBlob,
    required int dimensions,
  }) async {
    if (evidenceId.isEmpty || entryId.isEmpty) return;
    await into(journalImageEmbeddings).insertOnConflictUpdate(
      JournalImageEmbeddingsCompanion.insert(
        evidenceId: evidenceId,
        entryId: entryId,
        embedding: embeddingBlob,
        dimensions: dimensions,
      ),
    );
  }

  Future<void> deleteImageEmbeddingsForEntry(String entryId) async {
    if (entryId.isEmpty) return;
    await (delete(journalImageEmbeddings)
          ..where((t) => t.entryId.equals(entryId)))
        .go();
  }

  Future<List<({String evidenceId, String entryId, Uint8List embedding})>>
  loadImageEmbeddingsForEntry(String entryId) async {
    final rows = await (select(journalImageEmbeddings)
          ..where((t) => t.entryId.equals(entryId)))
        .get();
    return rows
        .map(
          (row) => (
            evidenceId: row.evidenceId,
            entryId: row.entryId,
            embedding: row.embedding,
          ),
        )
        .toList(growable: false);
  }

  /// Deletes rows whose [idColumn] value is not in [keepIds].
  Future<void> deleteIdsNotIn({
    required String table,
    required Set<String> keepIds,
    String idColumn = 'id',
  }) async {
    if (keepIds.isEmpty) {
      await customStatement('DELETE FROM $table');
      return;
    }

    final existingRows = await customSelect(
      'SELECT DISTINCT $idColumn AS row_id FROM $table',
    ).get();

    final toDelete = <String>[];
    for (final row in existingRows) {
      final rowId = row.read<String>('row_id');
      if (rowId.isEmpty || keepIds.contains(rowId)) continue;
      toDelete.add(rowId);
    }

    if (toDelete.isEmpty) return;

    for (
      var offset = 0;
      offset < toDelete.length;
      offset += DatabaseConstants.deleteNotInChunkSize
    ) {
      final end = offset + DatabaseConstants.deleteNotInChunkSize > toDelete.length
          ? toDelete.length
          : offset + DatabaseConstants.deleteNotInChunkSize;
      final chunk = toDelete.sublist(offset, end);
      final placeholders = List.filled(chunk.length, '?').join(', ');
      await customStatement(
        'DELETE FROM $table WHERE $idColumn IN ($placeholders)',
        chunk,
      );
    }
  }
}
