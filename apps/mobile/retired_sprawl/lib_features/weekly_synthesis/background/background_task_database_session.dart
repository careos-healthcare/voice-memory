import 'dart:io';

import 'package:archiveme_mobile/database/app_database.dart';
import 'package:archiveme_mobile/features/weekly_synthesis/background/background_task_account_registry.dart';
import 'package:archiveme_mobile/security/sqlite/sqlite_encryption_key_store.dart';
import 'package:archiveme_mobile/storage/account_namespace.dart';
import 'package:archiveme_mobile/storage/secure_storage.dart';
import 'package:archiveme_mobile/storage/sqlite/app_sqlite_database.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_database_initializer.dart';
import 'package:path_provider/path_provider.dart';

/// Opens the account-scoped SQLite database from a headless background isolate.
final class BackgroundTaskDatabaseSession {
  BackgroundTaskDatabaseSession._({
    required this.namespace,
    required this.filePath,
    required AppDatabase database,
    required AppSqliteDatabase sqlite,
  }) : _database = database,
       _sqlite = sqlite;

  final AccountNamespace namespace;
  final String filePath;
  final AppDatabase _database;
  final AppSqliteDatabase _sqlite;

  AppDatabase get database => _database;

  static Future<BackgroundTaskDatabaseSession?> open() async {
    if (!Platform.isIOS && !Platform.isAndroid) {
      return null;
    }

    final namespace = await BackgroundTaskAccountRegistry.readActiveNamespace();
    final docs = await getApplicationDocumentsDirectory();
    final filePath = '${docs.path}/accounts/${namespace.key}/archiveme.db';
    final dbFile = File(filePath);
    if (!await dbFile.exists()) {
      return null;
    }

    final keyStore = SecureSqliteEncryptionKeyStore(
      secure: SecureStorageService(),
      keyAlias: namespace.key,
    );

    String? passwordOverride;
    if (SqliteDatabaseInitializer.encryptionEnabled) {
      passwordOverride = await keyStore.ensurePassphrase();
    }

    final sqlite = await AppSqliteDatabase.open(
      filePath: filePath,
      password: passwordOverride,
      keyAlias: namespace.key,
      keyStore: keyStore,
    );

    final drift = AppDatabase.fromSqflite(sqlite.database);

    return BackgroundTaskDatabaseSession._(
      namespace: namespace,
      filePath: filePath,
      database: drift,
      sqlite: sqlite,
    );
  }

  Future<void> close() => _sqlite.close();
}
