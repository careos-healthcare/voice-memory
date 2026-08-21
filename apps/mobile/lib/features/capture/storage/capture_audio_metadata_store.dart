import 'dart:io';

import 'package:archiveme_mobile/database/app_database.dart';
import 'package:archiveme_mobile/features/capture/models/capture_audio_metadata.dart';
import 'package:archiveme_mobile/storage/sqlite/isolate_safe_sqlite_database_initializer.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_017_capture_audio_metadata.dart';
import 'package:sqflite/sqflite.dart';

/// Optimistic Drift writes for capture audio metadata.
class CaptureAudioMetadataStore {
  CaptureAudioMetadataStore({
    required String sqliteFilePath,
    String? encryptionPassword,
    String? keyAlias,
    Future<Database> Function()? openDatabaseOverride,
  }) : _sqliteFilePath = sqliteFilePath,
       _encryptionPassword = encryptionPassword,
       _keyAlias = keyAlias,
       _openDatabaseOverride = openDatabaseOverride;

  static const table = Migration017CaptureAudioMetadata.tableName;
  static const statusPendingAnalysis =
      Migration017CaptureAudioMetadata.statusPendingAnalysis;

  final String _sqliteFilePath;
  final String? _encryptionPassword;
  final String? _keyAlias;
  final Future<Database> Function()? _openDatabaseOverride;

  Future<AppDatabase> _openDrift() async {
    final db = await _openDatabase();
    return AppDatabase.fromSqflite(db);
  }

  Future<Database> _openDatabase() {
    final override = _openDatabaseOverride;
    if (override != null) return override();
    return IsolateSafeSqliteDatabaseInitializer.openWorkerConnection(
      filePath: _sqliteFilePath,
      passwordOverride: _encryptionPassword,
      keyAlias: _keyAlias,
    );
  }

  /// Inserts a pending row; throws if the write exceeds [captureMetadataInsertBudgetMs].
  Future<CaptureAudioMetadata> insertPendingOptimistic({
    required String id,
    required String filePath,
    DateTime? createdAt,
  }) async {
    final started = DateTime.now();
    final drift = await _openDrift();
    final row = await drift.queueDao.insertCaptureMetadataPending(
      id: id,
      filePath: filePath,
      createdAt: createdAt,
    );
    final elapsedMs = DateTime.now().difference(started).inMilliseconds;
    if (elapsedMs > captureMetadataInsertBudgetMs) {
      throw StateError(
        'Capture metadata insert exceeded ${captureMetadataInsertBudgetMs}ms ($elapsedMs ms)',
      );
    }
    return row;
  }

  Future<void> updateStatus({
    required String id,
    required String status,
  }) async {
    final drift = await _openDrift();
    await drift.queueDao.updateCaptureMetadataStatus(id: id, status: status);
  }

  Future<List<CaptureAudioMetadata>> listByStatus(String status) async {
    final drift = await _openDrift();
    return drift.queueDao.listCaptureMetadataByStatus(status);
  }

  Future<List<CaptureAudioMetadata>> listPendingAnalysis() {
    return listByStatus(statusPendingAnalysis);
  }

  Future<CaptureAudioMetadata?> findById(String id) async {
    final drift = await _openDrift();
    return drift.queueDao.findCaptureMetadataById(id);
  }

  Future<void> completeProcessing(String id) async {
    final row = await findById(id);
    if (row == null) return;
    final file = File(row.filePath);
    if (file.existsSync()) {
      await file.delete();
    }
    await updateStatus(id: id, status: 'completed');
  }
}
