import 'package:archiveme_mobile/features/insight_engine/hybrid_search_models.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_migration.dart';
import 'package:sqflite/sqflite.dart';

/// Local vector storage for journal photo attachment embeddings.
class Migration006ImageEmbeddings implements SqliteMigration {
  @override
  int get version => 6;

  @override
  String get id => '006_image_embeddings';

  static const embeddingsTable = 'journal_image_embeddings';
  static const vecTable = 'journal_image_vec';

  @override
  Future<void> up(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $embeddingsTable (
        evidence_id TEXT PRIMARY KEY NOT NULL,
        entry_id TEXT NOT NULL,
        embedding BLOB NOT NULL,
        dimensions INTEGER NOT NULL,
        FOREIGN KEY (entry_id) REFERENCES journal_entries(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_journal_image_embeddings_entry_id
      ON $embeddingsTable(entry_id)
    ''');

    await _tryCreateVec0Table(db);
  }

  Future<void> _tryCreateVec0Table(DatabaseExecutor db) async {
    try {
      await db.execute('''
        CREATE VIRTUAL TABLE IF NOT EXISTS $vecTable USING vec0(
          evidence_id TEXT PRIMARY KEY,
          entry_id TEXT,
          embedding float[$imageEmbeddingDimensions]
        )
      ''');
    } on Object {
      // sqlite-vec is optional; blob table + Dart cosine search is the fallback.
    }
  }
}
