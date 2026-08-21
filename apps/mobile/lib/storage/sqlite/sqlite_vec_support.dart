import 'dart:io';

import 'package:archiveme_mobile/features/insight_engine/hybrid_search_models.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_005_hybrid_search.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_015_vec_chunks.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_vector_support.dart';
import 'package:sqflite/sqflite.dart';

/// Loads sqlite-vec ([vec0]) and initializes the [Migration015VecChunks.vecChunksTable]
/// virtual table for cosine similarity search.
abstract final class SqliteVecSupport {
  SqliteVecSupport._();

  static bool _initAttempted = false;
  static bool _vec0Available = false;

  /// True when [vecChunksTable] was successfully created on this isolate.
  static bool get isVec0Available => _vec0Available;

  /// Loads bundled vector extensions (sqlite-vector + sqlite-vec vec0 when supported).
  static bool ensureLoaded() {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return false;
    }

    // sqlite-vector underpins vector_full_scan; vec0 shares the same process load.
    SqliteVectorSupport.ensureLoaded();
    return _vec0Available;
  }

  /// Creates [Migration015VecChunks.vecChunksTable] and backfills from transcript embeddings.
  static Future<void> initVecChunks(Database db) async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return;
    }
    if (_initAttempted) {
      if (_vec0Available) {
        await _backfillVecChunks(db);
      }
      return;
    }
    _initAttempted = true;

    ensureLoaded();

    try {
      await db.execute('''
        CREATE VIRTUAL TABLE IF NOT EXISTS ${Migration015VecChunks.vecChunksTable} USING vec0(
          entry_id TEXT PRIMARY KEY,
          embedding float[$localTranscriptEmbeddingDimensions]
        )
      ''');
      _vec0Available = true;
      await _backfillVecChunks(db);
    } on Object {
      _vec0Available = false;
    }
  }

  /// True when [Migration015VecChunks.vecChunksTable] exists in [db].
  static Future<bool> hasVecChunksTable(Database db) async {
    final rows = await db.rawQuery(
      '''
      SELECT name
      FROM sqlite_master
      WHERE type = 'table' AND name = ?
      ''',
      [Migration015VecChunks.vecChunksTable],
    );
    return rows.isNotEmpty;
  }

  static Future<void> _backfillVecChunks(Database db) async {
    if (!_vec0Available) return;

    final rows = await db.query(
      Migration005HybridSearch.embeddingsTable,
      columns: ['entry_id', 'embedding'],
    );
    if (rows.isEmpty) return;

    for (final row in rows) {
      final entryId = row['entry_id'] as String? ?? '';
      final embedding = row['embedding'];
      if (entryId.isEmpty || embedding == null) continue;

      await db.delete(
        Migration015VecChunks.vecChunksTable,
        where: 'entry_id = ?',
        whereArgs: [entryId],
      );
      await db.insert(Migration015VecChunks.vecChunksTable, {
        'entry_id': entryId,
        'embedding': embedding,
      });
    }
  }
}
