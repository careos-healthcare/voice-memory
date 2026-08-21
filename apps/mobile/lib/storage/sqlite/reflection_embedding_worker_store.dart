import 'dart:typed_data';

import 'package:archiveme_mobile/features/search/reflection_embedding_contract.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_009_reflection_embeddings.dart';
import 'package:sqflite/sqflite.dart';

/// Worker-isolate reflection embedding persistence (no [AppSqliteDatabase] singleton).
final class ReflectionEmbeddingWorkerStore {
  ReflectionEmbeddingWorkerStore(this._db);

  final Database _db;

  static const embeddingsTable = Migration009ReflectionEmbeddings.embeddingsTable;
  static const vecTable = Migration009ReflectionEmbeddings.vecTable;

  Future<String?> readContentHash(String entryId) async {
    if (entryId.isEmpty) return null;
    final rows = await _db.query(
      embeddingsTable,
      columns: ['content_hash'],
      where: 'entry_id = ?',
      whereArgs: [entryId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['content_hash'] as String?;
  }

  Future<void> upsertEmbedding({
    required String entryId,
    required List<double> embedding,
    required String contentHash,
  }) async {
    if (entryId.isEmpty) return;
    if (embedding.length != ReflectionEmbeddingContract.dimensions) {
      throw ArgumentError.value(
        embedding.length,
        'embedding.length',
        'expected ${ReflectionEmbeddingContract.dimensions}',
      );
    }

    final nowMillis = DateTime.now().toUtc().millisecondsSinceEpoch;
    final blob = _embeddingToBlob(embedding);
    await _db.insert(
      embeddingsTable,
      {
        'entry_id': entryId,
        'embedding': blob,
        'dimensions': embedding.length,
        'content_hash': contentHash,
        'updated_at': nowMillis,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    if (await _hasLegacyVec0Table()) {
      await _upsertLegacyVec0(entryId: entryId, embedding: embedding);
    }
  }

  Future<bool> _hasLegacyVec0Table() async {
    final rows = await _db.rawQuery(
      '''
      SELECT name
      FROM sqlite_master
      WHERE type = 'table' AND name = ?
      ''',
      [vecTable],
    );
    return rows.isNotEmpty;
  }

  Future<void> _upsertLegacyVec0({
    required String entryId,
    required List<double> embedding,
  }) async {
    await _db.delete(
      vecTable,
      where: 'entry_id = ?',
      whereArgs: [entryId],
    );
    await _db.insert(vecTable, {
      'entry_id': entryId,
      'embedding': _embeddingToBlob(embedding),
    });
  }

  static Uint8List _embeddingToBlob(List<double> embedding) {
    final bytes = Float32List.fromList(embedding);
    return bytes.buffer.asUint8List();
  }
}
