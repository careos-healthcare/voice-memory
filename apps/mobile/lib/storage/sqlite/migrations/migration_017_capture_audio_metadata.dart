import 'package:archiveme_mobile/storage/sqlite/sqlite_migration.dart';
import 'package:sqflite/sqflite.dart';

/// Fast local metadata rows for background/widget capture before LLM analysis.
class Migration017CaptureAudioMetadata implements SqliteMigration {
  @override
  int get version => 17;

  @override
  String get id => '017_capture_audio_metadata';

  static const tableName = 'capture_audio_metadata';

  static const statusPendingAnalysis = 'pending_analysis';

  @override
  Future<void> up(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableName (
        id TEXT PRIMARY KEY NOT NULL,
        file_path TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        status TEXT NOT NULL DEFAULT '$statusPendingAnalysis'
          CHECK(status IN ('$statusPendingAnalysis', 'processing', 'completed', 'error'))
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_capture_audio_metadata_pending
      ON $tableName(created_at ASC)
      WHERE status = '$statusPendingAnalysis'
    ''');
  }
}
