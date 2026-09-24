import 'dart:io';

import 'package:archiveme_mobile/features/weekly_synthesis/background/background_task_account_registry.dart';
import 'package:archiveme_mobile/security/sqlite/sqlite_encryption_key_store.dart';
import 'package:archiveme_mobile/storage/recent_entry_snippet_cache.dart';
import 'package:archiveme_mobile/storage/secure_storage.dart';
import 'package:archiveme_mobile/storage/sqlite/app_sqlite_database.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_database_initializer.dart';
import 'package:path_provider/path_provider.dart';

/// Opens only the account SQLite file for a headless quick-capture write.
final class QuickCaptureHeadlessDatabase {
  QuickCaptureHeadlessDatabase._({
    required this.sqlite,
    required this.snippetFile,
  });

  final AppSqliteDatabase sqlite;
  final File snippetFile;

  static Future<QuickCaptureHeadlessDatabase?> open() async {
    final namespace = await BackgroundTaskAccountRegistry.readActiveNamespace();
    final docs = await getApplicationDocumentsDirectory();
    final directory = Directory(
      '${docs.path}/accounts/${namespace.key}',
    );
    final filePath = '${directory.path}/archiveme.db';
    if (!await File(filePath).exists()) return null;

    final keyStore = SecureSqliteEncryptionKeyStore(
      store: SecureStorageService(),
      keyAlias: namespace.key,
    );
    String? password;
    if (SqliteDatabaseInitializer.encryptionEnabled) {
      password = await keyStore.ensurePassphrase();
    }

    final sqlite = await AppSqliteDatabase.open(
      filePath: filePath,
      password: password,
      keyAlias: namespace.key,
      keyStore: keyStore,
      runDeferredBackfill: false,
      scheduleVectorExtensions: false,
    );
    return QuickCaptureHeadlessDatabase._(
      sqlite: sqlite,
      snippetFile: File(
        '${directory.path}/${RecentEntrySnippetCache.fileName}',
      ),
    );
  }

  Future<void> close() => sqlite.close();
}
