import 'dart:async';
import 'dart:io';

import 'package:archiveme_mobile/security/sqlite/secure_sqlite_lock_service.dart';
import 'package:archiveme_mobile/security/sqlite/sqlite_encryption_key_store.dart';
import 'package:archiveme_mobile/storage/sqlite/profiling/sqlite_profiling_database.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_database_initializer.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

/// Account-scoped SQLite handle for relationship and journal mirror data.
class AppSqliteDatabase {
  AppSqliteDatabase._(
    this._db, {
    required this.filePath,
    required this.encryptionPassword,
    this.keyAlias,
  });

  final sqflite.Database _db;
  final String filePath;
  final String? encryptionPassword;
  final String? keyAlias;
  static sqflite.Database? _cached;
  static String? _cachedPath;
  static String? _cachedPassword;
  static String? _cachedKeyAlias;
  static Future<void> _openMutex = Future<void>.value();

  static bool get _isFlutterTest =>
      Platform.environment.containsKey('FLUTTER_TEST');

  static Future<AppSqliteDatabase> open({
    required String filePath,
    String? password,
    String? keyAlias,
    SqliteEncryptionKeyStore? keyStore,
  }) async {
    if (_cached != null && _cachedPath == filePath) {
      return AppSqliteDatabase._(
        _cached!,
        filePath: filePath,
        encryptionPassword: _cachedPassword,
        keyAlias: _cachedKeyAlias,
      );
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
        _cachedPassword = null;
        _cachedKeyAlias = null;
      }

      final resolvedPassword = password ??
          (_isFlutterTest
              ? SqliteDatabaseInitializer.testEncryptionPassword
              : (SqliteDatabaseInitializer.encryptionEnabled
                    ? SecureSqliteLockService.instance.session
                          .requirePassphrase()
                    : null));

      final db = SqliteProfilingDatabase.wrapIfEnabled(
        await SqliteDatabaseInitializer.open(
          filePath: filePath,
          keyStore: keyStore,
          passwordOverride: resolvedPassword,
          keyAlias: keyAlias,
        ),
      );

      _cached = db;
      _cachedPath = filePath;
      _cachedPassword = resolvedPassword;
      _cachedKeyAlias = keyAlias;
      return AppSqliteDatabase._(
        db,
        filePath: filePath,
        encryptionPassword: resolvedPassword,
        keyAlias: keyAlias,
      );
    } finally {
      completer.complete();
    }
  }

  sqflite.Database get database => _db;

  Future<void> close() async {
    if (_cached == _db) {
      await _db.close();
      _cached = null;
      _cachedPath = null;
      _cachedPassword = null;
      _cachedKeyAlias = null;
    }
  }

  /// Test-only: reset singleton between tests.
  static Future<void> resetForTest() async {
    if (_cached != null) {
      await _cached!.close();
      _cached = null;
      _cachedPath = null;
      _cachedPassword = null;
      _cachedKeyAlias = null;
    }
    _openMutex = Future<void>.value();
  }
}
