import 'package:archiveme_mobile/storage/sqlite/sqlite_migration.dart';
import 'package:sqflite/sqflite.dart';

/// Pending local audio files awaiting LLM / capture pipeline processing.
class Migration016AudioProcessingQueue implements SqliteMigration {
  @override
  int get version => 16;

  @override
  String get id => '016_audio_processing_queue';

  static const tableName = 'audio_processing_queue';

  static const statusPending = 'pending';
  static const statusProcessing = 'processing';
  static const statusCompleted = 'completed';
  static const statusError = 'error';

  @override
  Future<void> up(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableName (
        id TEXT PRIMARY KEY NOT NULL,
        file_path TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        duration_ms INTEGER NOT NULL,
        status TEXT NOT NULL DEFAULT '$statusPending'
          CHECK(status IN (
            '$statusPending',
            '$statusProcessing',
            '$statusCompleted',
            '$statusError'
          ))
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_audio_processing_queue_pending
      ON $tableName(timestamp ASC)
      WHERE status = '$statusPending'
    ''');
  }
}
