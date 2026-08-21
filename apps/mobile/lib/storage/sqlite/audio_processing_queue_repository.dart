import 'package:archiveme_mobile/database/app_database.dart';
import 'package:archiveme_mobile/models/audio_processing_queue_item.dart';
import 'package:archiveme_mobile/storage/sqlite/app_sqlite_database.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_016_audio_processing_queue.dart';

class AudioProcessingQueueRepository {
  AudioProcessingQueueRepository(this._sqlite);

  static const table = Migration016AudioProcessingQueue.tableName;

  final AppSqliteDatabase _sqlite;
  AppDatabase? _drift;

  AppDatabase get _db => _drift ??= AppDatabase.fromSqflite(_sqlite.database);

  Future<void> insertPending({
    required String id,
    required String filePath,
    required DateTime timestamp,
    required int durationMs,
  }) =>
      _db.queueDao.insertAudioProcessingPending(
        id: id,
        filePath: filePath,
        timestamp: timestamp,
        durationMs: durationMs,
      );

  Future<AudioProcessingQueueItem?> findById(String id) =>
      _db.queueDao.findAudioProcessingById(id);

  Future<List<AudioProcessingQueueItem>> listPending({int limit = 50}) =>
      _db.queueDao.listAudioProcessingPending(limit: limit);

  Future<void> updateStatus({
    required String id,
    required AudioProcessingQueueStatus status,
  }) =>
      _db.queueDao.updateAudioProcessingStatus(id: id, status: status);
}
