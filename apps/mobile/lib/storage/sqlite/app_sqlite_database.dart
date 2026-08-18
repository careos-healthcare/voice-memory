import 'dart:async';
import 'dart:io';

import 'package:archiveme_mobile/storage/sqlite/sqlite_migration_runner.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_vector_support.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Account-scoped SQLite handle for relationship and consent data.
class AppSqliteDatabase {
  AppSqliteDatabase._(this._db);

  final Database _db;
  static Database? _cached;
  static String? _cachedPath;
  static Future<void> _openMutex = Future<void>.value();

  static Future<AppSqliteDatabase> open({required String filePath}) async {
    if (_cached != null && _cachedPath == filePath) {
      return AppSqliteDatabase._(_cached!);
    }

    final previous = _openMutex;
    final completer = Completer<void>();
    _openMutex = completer.future;
    await previous;

    try {
      if (_cached != null) {
        await _cached!.close();
        _cached = null;
        _cachedPath = null;
      }

      await Directory(p.dirname(filePath)).create(recursive: true);

      SqliteVectorSupport.ensureLoaded();

      final db = await openDatabase(
        filePath,
        version: 1,
        onConfigure: (database) async {
          await database.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (database, version) async {
          await SqliteMigrationRunner().run(database);
        },
        onOpen: (database) async {
          await SqliteMigrationRunner().run(database);
          await SqliteVectorSupport.initTranscriptEmbeddingIndex(database);
        },
      );

      _cached = db;
      _cachedPath = filePath;
      return AppSqliteDatabase._(db);
    } finally {
      completer.complete();
    }
  }

  Database get database => _db;

  Future<void> close() async {
    if (_cached == _db) {
      await _db.close();
      _cached = null;
      _cachedPath = null;
    }
  }

  /// Test-only: reset singleton between tests.
  static Future<void> resetForTest() async {
    if (_cached != null) {
      await _cached!.close();
      _cached = null;
      _cachedPath = null;
    }
    _openMutex = Future<void>.value();
  }
}