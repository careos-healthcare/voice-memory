import 'package:archiveme_mobile/features/insight_engine/hybrid_search_models.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_migration.dart';
import 'package:sqflite/sqflite.dart';

/// sqlite-vec [vec0] storage for transcript embedding chunks.
///
/// The virtual table is created at runtime after the sqlite-vec extension loads
/// ([SqliteVecSupport.initVecChunks]); this migration only reserves the schema
/// version and attempts best-effort creation for installs that already bundle
/// the extension at migration time.
class Migration015VecChunks implements SqliteMigration {
  @override
  int get version => 15;

  @override
  String get id => '015_vec_chunks';

  static const vecChunksTable = 'vec_chunks';

  @override
  Future<void> up(DatabaseExecutor db) async {
    await _tryCreateVecChunks(db);
  }

  Future<void> _tryCreateVecChunks(DatabaseExecutor db) async {
    try {
      await db.execute('''
        CREATE VIRTUAL TABLE IF NOT EXISTS $vecChunksTable USING vec0(
          entry_id TEXT PRIMARY KEY,
          embedding float[$localTranscriptEmbeddingDimensions]
        )
      ''');
    } on Object {
      // sqlite-vec is optional; [SqliteVecSupport] recreates after extension load.
    }
  }
}
