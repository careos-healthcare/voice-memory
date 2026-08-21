import 'dart:io';

import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/storage/isolate/local_database_worker_service.dart';
import 'package:sqflite/sqflite.dart';

/// Runs file-backed SQLite bulk work on the persistent background worker so the
/// UI isolate stays responsive.
abstract final class SqliteHeavyOperationRunner {
  SqliteHeavyOperationRunner._();

  /// Entry batches at or above this size use the background worker when possible.
  static const entryBatchThreshold =
      LocalDatabaseWorkerService.entryBatchThreshold;

  static bool _isInMemoryPath(String filePath) =>
      filePath == ':memory:' || filePath == inMemoryDatabasePath;

  static Future<int> runGraphBackfill({
    required String filePath,
    String? encryptionPassword,
    String? keyAlias,
  }) {
    return _guardFilePath(
      filePath,
      () => LocalDatabaseWorkerService.instance.runGraphBackfill(
        filePath: filePath,
        encryptionPassword: encryptionPassword,
        keyAlias: keyAlias,
      ),
    );
  }

  static Future<void> runJournalUpsert({
    required String filePath,
    String? encryptionPassword,
    String? keyAlias,
    required List<JournalEntry> entries,
  }) {
    return _guardFilePath(
      filePath,
      () => LocalDatabaseWorkerService.instance.runJournalUpsert(
        filePath: filePath,
        encryptionPassword: encryptionPassword,
        keyAlias: keyAlias,
        entries: entries,
      ),
    );
  }

  static Future<void> runJournalMirror({
    required String filePath,
    String? encryptionPassword,
    String? keyAlias,
    required List<JournalEntry> entries,
  }) {
    return _guardFilePath(
      filePath,
      () => LocalDatabaseWorkerService.instance.runJournalMirror(
        filePath: filePath,
        encryptionPassword: encryptionPassword,
        keyAlias: keyAlias,
        entries: entries,
      ),
    );
  }

  static Future<T> _guardFilePath<T>(
    String filePath,
    Future<T> Function() action,
  ) {
    if (_isInMemoryPath(filePath)) {
      throw StateError(
        'In-memory SQLite paths must run heavy operations on the existing connection.',
      );
    }
    return action();
  }
}
