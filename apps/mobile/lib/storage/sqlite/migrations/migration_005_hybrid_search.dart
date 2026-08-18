import 'package:archiveme_mobile/features/insight_engine/hybrid_search_models.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_migration.dart';
import 'package:sqflite/sqflite.dart';

/// FTS5 keyword index and embedding storage for on-device hybrid retrieval.
class Migration005HybridSearch implements SqliteMigration {
  @override
  int get version => 5;

  @override
  String get id => '005_hybrid_search';

  static const ftsTable = 'memory_transcript_fts';
  static const embeddingsTable = 'memory_transcript_embeddings';

  /// Legacy sqlite-vec virtual table — kept for installs that already created it.
  static const vecTable = 'memory_transcript_vec';

  @override
  Future<void> up(DatabaseExecutor db) async {
    await db.execute('''
      CREATE VIRTUAL TABLE IF NOT EXISTS $ftsTable USING fts5(
        entry_id UNINDEXED,
        transcript,
        tokenize = 'porter unicode61'
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $embeddingsTable (
        entry_id TEXT PRIMARY KEY NOT NULL,
        embedding BLOB NOT NULL,
        dimensions INTEGER NOT NULL,
        FOREIGN KEY (entry_id) REFERENCES journal_entries(id) ON DELETE CASCADE
      )
    ''');

    await _tryCreateLegacyVec0Table(db);
  }

  Future<void> _tryCreateLegacyVec0Table(DatabaseExecutor db) async {
    try {
      await db.execute('''
        CREATE VIRTUAL TABLE IF NOT EXISTS $vecTable USING vec0(
          entry_id TEXT PRIMARY KEY,
          embedding float[$localTranscriptEmbeddingDimensions]
        )
      ''');
    } on Object {
      // sqlite-vec is optional; blob table + sqlite_vector / Dart fallback remain.
    }
  }
}
