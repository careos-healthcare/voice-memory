import 'package:archiveme_mobile/storage/sqlite/sqlite_migration.dart';
import 'package:sqflite/sqflite.dart';

/// Deferred ONNX embedding tasks waiting for external power or higher battery.
class Migration014EmbeddingDeferredQueue implements SqliteMigration {
  @override
  int get version => 14;

  @override
  String get id => '014_embedding_deferred_queue';

  static const queueTable = 'embedding_deferred_queue';
  static const operationIndexReflection = 'indexReflection';
  static const operationIndexTranscript = 'indexTranscript';

  @override
  Future<void> up(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $queueTable (
        queue_id TEXT PRIMARY KEY NOT NULL,
        operation TEXT NOT NULL,
        entry_id TEXT NOT NULL,
        text TEXT NOT NULL,
        content_hash TEXT,
        sqlite_file_path TEXT NOT NULL,
        key_alias TEXT,
        encryption_password TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_embedding_deferred_queue_created
      ON $queueTable(created_at ASC)
    ''');

    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_embedding_deferred_reflection_dedupe
      ON $queueTable(entry_id, content_hash)
      WHERE operation = '$operationIndexReflection'
    ''');

    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_embedding_deferred_transcript_dedupe
      ON $queueTable(entry_id)
      WHERE operation = '$operationIndexTranscript'
    ''');
  }
}
