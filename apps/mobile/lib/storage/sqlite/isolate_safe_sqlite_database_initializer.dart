import 'dart:io';

import 'package:archiveme_mobile/security/sqlite/sqlite_encryption_key_store.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_database_initializer.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_hybrid_search_initializer.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_migration_manager.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' as sqlcipher;

/// Opens SQLCipher connections from background worker isolates without touching
/// [AppSqliteDatabase] singleton mutexes or [SecureSqliteLockService] session
/// state on the UI isolate.
abstract final class IsolateSafeSqliteDatabaseInitializer {
  IsolateSafeSqliteDatabaseInitializer._();

  static bool get _isFlutterTest =>
      Platform.environment.containsKey('FLUTTER_TEST');

  /// Prepares sqflite and platform channels inside a worker isolate.
  static void ensureWorkerRuntime({
    required bool initializeTestFfi,
    RootIsolateToken? rootIsolateToken,
  }) {
    if (initializeTestFfi) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      return;
    }
    if (rootIsolateToken != null) {
      BackgroundIsolateBinaryMessenger.ensureInitialized(rootIsolateToken);
    }
  }

  /// Resolves the SQLCipher password in the current isolate.
  ///
  /// Reads from secure storage via [keyStore] or [SecureSqliteEncryptionKeyStore]
  /// when [keyAlias] is provided. Never consults [SecureSqliteLockService].
  static Future<String> resolvePassword({
    String? passwordOverride,
    String? keyAlias,
    SqliteEncryptionKeyStore? keyStore,
  }) async {
    if (passwordOverride != null) {
      return passwordOverride;
    }

    final shouldReadFromStore =
        keyStore != null ||
        (keyAlias != null && keyAlias.isNotEmpty) ||
        SqliteDatabaseInitializer.encryptionEnabled;

    if (shouldReadFromStore) {
      final store =
          keyStore ??
          SecureSqliteEncryptionKeyStore(keyAlias: keyAlias ?? '');
      final key = await store.readEncryptionKey();
      if (key == null) {
        throw StateError(
          'SQLCipher encryption key not found for alias "${keyAlias ?? ''}".',
        );
      }
      return key.sqlcipherPassword;
    }

    return SqliteDatabaseInitializer.testEncryptionPassword;
  }

  /// Opens a worker-owned SQLite connection with [singleInstance: false].
  static Future<sqflite.Database> openWorkerConnection({
    required String filePath,
    String? passwordOverride,
    String? keyAlias,
    SqliteEncryptionKeyStore? keyStore,
    bool runMigrations = true,
  }) async {
    if (filePath.isEmpty) {
      throw ArgumentError.value(filePath, 'filePath', 'must not be empty');
    }

    if (!_isInMemoryPath(filePath)) {
      await Directory(p.dirname(filePath)).create(recursive: true);
    }

    final password = await resolvePassword(
      passwordOverride: passwordOverride,
      keyAlias: keyAlias,
      keyStore: keyStore,
    );

    if (_usesEncryptedOpen(
      passwordOverride: passwordOverride,
      keyAlias: keyAlias,
      keyStore: keyStore,
    )) {
      return _openEncrypted(
        filePath: filePath,
        password: password,
        runMigrations: runMigrations,
      );
    }

    return _openPlaintext(
      filePath: filePath,
      runMigrations: runMigrations,
    );
  }

  static bool _usesEncryptedOpen({
    required String? passwordOverride,
    String? keyAlias,
    SqliteEncryptionKeyStore? keyStore,
  }) =>
      passwordOverride != null ||
      keyStore != null ||
      (keyAlias != null && keyAlias.isNotEmpty) ||
      SqliteDatabaseInitializer.encryptionEnabled;

  static bool _isInMemoryPath(String filePath) =>
      filePath == ':memory:' || filePath == sqflite.inMemoryDatabasePath;

  static Future<sqflite.Database> _openEncrypted({
    required String filePath,
    required String password,
    required bool runMigrations,
  }) {
    if (_isFlutterTest) {
      return _openEncryptedViaFfi(
        filePath: filePath,
        password: password,
        runMigrations: runMigrations,
      );
    }
    return sqlcipher.openDatabase(
      filePath,
      password: password,
      version: 1,
      singleInstance: false,
      onConfigure: SqliteDatabaseInitializer.configureConnection,
      onCreate: (db, version) =>
          _onCreate(db, version, runMigrations: runMigrations),
      onOpen: (db) => _onOpen(db, runMigrations: runMigrations),
    );
  }

  static Future<sqflite.Database> _openEncryptedViaFfi({
    required String filePath,
    required String password,
    required bool runMigrations,
  }) {
    return sqflite.openDatabase(
      filePath,
      version: 1,
      singleInstance: false,
      onConfigure: (db) async {
        await db.execute("PRAGMA key = '${_escapeSqlStringLiteral(password)}'");
        await SqliteDatabaseInitializer.configureConnection(db);
      },
      onCreate: (db, version) =>
          _onCreate(db, version, runMigrations: runMigrations),
      onOpen: (db) => _onOpen(db, runMigrations: runMigrations),
    );
  }

  static Future<sqflite.Database> _openPlaintext({
    required String filePath,
    required bool runMigrations,
  }) {
    return sqflite.openDatabase(
      filePath,
      version: 1,
      singleInstance: false,
      onConfigure: SqliteDatabaseInitializer.configureConnection,
      onCreate: (db, version) =>
          _onCreate(db, version, runMigrations: runMigrations),
      onOpen: (db) => _onOpen(db, runMigrations: runMigrations),
    );
  }

  static Future<void> _onCreate(
    sqflite.Database database,
    int version, {
    required bool runMigrations,
  }) async {
    if (runMigrations) {
      await SqliteMigrationManager().run(database);
    }
  }

  static Future<void> _onOpen(
    sqflite.Database database, {
    required bool runMigrations,
  }) async {
    if (runMigrations) {
      await SqliteMigrationManager().run(database);
    }
    await SqliteHybridSearchInitializer.initialize(database);
  }

  static String _escapeSqlStringLiteral(String value) =>
      value.replaceAll("'", "''");
}
