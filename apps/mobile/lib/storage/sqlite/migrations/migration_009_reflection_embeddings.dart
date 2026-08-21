import 'package:archiveme_mobile/features/search/reflection_embedding_contract.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_migration.dart';
import 'package:sqflite/sqflite.dart';

/// Local reflection embedding storage for offline semantic journal search.
class Migration009ReflectionEmbeddings implements SqliteMigration {
  @override
  int get version => 9;

  @override
  String get id => '009_reflection_embeddings';

  static const embeddingsTable = 'reflection_embeddings';
  static const vecTable = 'reflection_embeddings_vec';

  @override
  Future<void> up(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $embeddingsTable (
        entry_id TEXT PRIMARY KEY NOT NULL,
        embedding BLOB NOT NULL,
        dimensions INTEGER NOT NULL,
        content_hash TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_reflection_embeddings_updated
      ON $embeddingsTable(updated_at DESC)
    ''');

    await _tryCreateLegacyVec0Table(db);
  }

  Future<void> _tryCreateLegacyVec0Table(DatabaseExecutor db) async {
    try {
      await db.execute('''
        CREATE VIRTUAL TABLE IF NOT EXISTS $vecTable USING vec0(
          entry_id TEXT PRIMARY KEY,
          embedding float[${ReflectionEmbeddingContract.dimensions}]
        )
      ''');
    } on Object {
      // sqlite-vec optional — blob table + sqlite_vector / Dart fallback remain.
    }
  }
}
