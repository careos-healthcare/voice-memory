import 'dart:async';
import 'dart:io';

import 'package:archiveme_mobile/security/sqlite/secure_sqlite_lock_service.dart';
import 'package:archiveme_mobile/security/sqlite/sqlite_encryption_key_store.dart';
import 'package:archiveme_mobile/security/sqlite/sqlite_encryption_migrator.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_database_encryption_key.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_connection_pragmas.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_hybrid_search_initializer.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_migration_manager.dart';
import 'package:archiveme_mobile/storage/sqlite/reflection_graph_backfill.dart';
import 'package:archiveme_mobile/storage/sqlite/transcript_provenance_backfill.dart';
import 'package:archiveme_mobile/storage/isolate/local_database_worker_service.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_sqlcipher/sqflite.dart' as sqlcipher;

/// Opens the account-scoped SQLite database with SQLCipher and baseline PRAGMAs.
abstract final class SqliteDatabaseInitializer {
  SqliteDatabaseInitializer._();

  /// Stable SQLCipher password for local database tests (256-bit raw key, base64).
  static String get testEncryptionPassword =>
      SqliteDatabaseEncryptionKey.testInstance.sqlcipherPassword;

  @Deprecated('Use testEncryptionPassword')
  static String get testPlaintextPassword => testEncryptionPassword;

  static bool get encryptionEnabled =>
      SecureSqliteLockService.encryptionEnabled &&
      (Platform.isIOS || Platform.isAndroid);

  static bool get _isFlutterTest =>
      Platform.environment.containsKey('FLUTTER_TEST');

  static bool _usesEncryptedOpen({required String? passwordOverride}) =>
      passwordOverride != null || encryptionEnabled;

  static Future<void> configureConnection(sqflite.Database database) async {
    await SqliteConnectionPragmas.apply(database);
  }

  /// Resolves the encryption key, migrates legacy plaintext files when needed,
  /// and returns an opened sqflite handle.
  static Future<sqflite.Database> open({
    required String filePath,
    SqliteEncryptionKeyStore? keyStore,
    String? passwordOverride,
    String? keyAlias,
    bool singleInstance = true,
    bool runDeferredBackfill = true,
  }) async {
    await Directory(p.dirname(filePath)).create(recursive: true);

    final password = await _resolvePassword(
      keyStore: keyStore,
      passwordOverride: passwordOverride,
    );

    final sqflite.Database db;
    if (_usesEncryptedOpen(passwordOverride: passwordOverride)) {
      if (filePath != ':memory:') {
        await SqliteEncryptionMigrator.migratePlaintextIfNeeded(
          filePath: filePath,
          password: password,
          openEncrypted: _openEncryptedForMigration,
        );
      }
      db = await _openEncrypted(
        filePath: filePath,
        password: password,
        singleInstance: singleInstance,
      );
    } else {
      db = await _openPlaintext(
        filePath: filePath,
        singleInstance: singleInstance,
      );
    }

    if (runDeferredBackfill) {
      await _runDeferredGraphBackfillAfterOpen(
        db,
        filePath: filePath,
        encryptionPassword: passwordOverride ?? password,
        keyAlias: keyAlias,
      );
      await _runDeferredTranscriptProvenanceBackfill(db);
    }
    return db;
  }

  static Future<String> _resolvePassword({
    required SqliteEncryptionKeyStore? keyStore,
    required String? passwordOverride,
  }) async {
    if (passwordOverride != null) {
      return passwordOverride;
    }
    if (encryptionEnabled) {
      final store = keyStore;
      if (store != null) {
        final key = await store.ensureEncryptionKey();
        return key.sqlcipherPassword;
      }
      return SecureSqliteLockService.instance.session.requirePassphrase();
    }
    return testEncryptionPassword;
  }

  static Future<sqflite.Database> _openEncrypted({
    required String filePath,
    required String password,
    required bool singleInstance,
  }) {
    if (_isFlutterTest) {
      return _openEncryptedViaFfi(
        filePath: filePath,
        password: password,
        singleInstance: singleInstance,
        onOpen: (db) => _onOpen(db),
      );
    }
    return sqlcipher.openDatabase(
      filePath,
      password: password,
      version: 1,
      singleInstance: singleInstance,
      onConfigure: configureConnection,
      onCreate: _onCreate,
      onOpen: _onOpen,
    );
  }

  /// Desktop `flutter test` uses [sqflite_common_ffi] with SQLCipher PRAGMAs.
  static Future<sqflite.Database> _openEncryptedViaFfi({
    required String filePath,
    required String password,
    required bool singleInstance,
    Future<void> Function(sqflite.Database db)? onOpen,
  }) {
    return sqflite.openDatabase(
      filePath,
      version: 1,
      singleInstance: singleInstance,
      onConfigure: (db) async {
        await db.execute("PRAGMA key = '${_escapeSqlStringLiteral(password)}'");
        await configureConnection(db);
      },
      onCreate: _onCreate,
      onOpen: onOpen,
    );
  }

  static String _escapeSqlStringLiteral(String value) =>
      value.replaceAll("'", "''");

  static Future<sqflite.Database> _openPlaintext({
    required String filePath,
    required bool singleInstance,
  }) {
    return sqflite.openDatabase(
      filePath,
      version: 1,
      singleInstance: singleInstance,
      onConfigure: configureConnection,
      onCreate: _onCreate,
      onOpen: _onOpen,
    );
  }

  static Future<void> _onCreate(sqflite.Database database, int version) async {
    await SqliteMigrationManager().run(database);
  }

  static Future<void> _onOpen(sqflite.Database database) async {
    await SqliteMigrationManager().run(database);
    await SqliteHybridSearchInitializer.initialize(database);
  }

  static bool _isInMemoryPath(String filePath) =>
      filePath == ':memory:' || filePath == sqflite.inMemoryDatabasePath;

  static Future<void> _runDeferredGraphBackfillAfterOpen(
    sqflite.Database database, {
    required String filePath,
    required String? encryptionPassword,
    String? keyAlias,
  }) async {
    if (!await ReflectionGraphBackfill.isPending(database)) {
      return;
    }

    if (_isInMemoryPath(filePath)) {
      await ReflectionGraphBackfill.fromJournalEntries(database);
    } else {
      await LocalDatabaseWorkerService.instance.runGraphBackfill(
        filePath: filePath,
        encryptionPassword: encryptionPassword,
        keyAlias: keyAlias,
      );
    }

    await ReflectionGraphBackfill.markComplete(database);
  }

  /// Stamps legacy journal payloads with an explicit `unknown_legacy`
  /// provenance, a bounded number of rows per launch.
  ///
  /// Failure here is deliberately not fatal and deliberately does not mark the
  /// backfill complete. An un-stamped payload still decodes to `unknownLegacy`
  /// and still yields no evidence source, so a database that never finishes
  /// this is honest about its own history; it just says so implicitly rather
  /// than in the stored row.
  static Future<void> _runDeferredTranscriptProvenanceBackfill(
    sqflite.Database database,
  ) async {
    try {
      if (!await TranscriptProvenanceBackfill.isPending(database)) return;
      await TranscriptProvenanceBackfill.run(database);
    } on Object {
      return;
    }
  }

  static Future<void> _openEncryptedForMigration(
    String targetPath,
    String password,
    Future<void> Function(dynamic db) body,
  ) async {
    final db = _isFlutterTest
        ? await _openEncryptedViaFfi(
            filePath: targetPath,
            password: password,
            singleInstance: true,
          )
        : await sqlcipher.openDatabase(
            targetPath,
            password: password,
            version: 1,
            onConfigure: configureConnection,
            onCreate: _onCreate,
          );
    try {
      await body(db);
    } finally {
      await db.close();
    }
  }
}
