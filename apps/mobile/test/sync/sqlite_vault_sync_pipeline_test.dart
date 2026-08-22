import 'dart:io';
import 'dart:typed_data';

import 'package:archiveme_mobile/storage/account_namespace.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_migration_manager.dart';
import 'package:archiveme_mobile/sync/sqlite_vault/encrypted_sqlite_vault_sync_pipeline.dart';
import 'package:archiveme_mobile/sync/sqlite_vault/sqlite_vault_cloud_transport.dart';
import 'package:archiveme_mobile/sync/sqlite_vault/sqlite_vault_config.dart';
import 'package:archiveme_mobile/sync/sqlite_vault/sqlite_vault_crypto.dart';
import 'package:archiveme_mobile/sync/sqlite_vault/sqlite_vault_key_store.dart';
import 'package:archiveme_mobile/sync/sqlite_vault/sqlite_vault_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('SqliteVaultCrypto', () {
    test('seals and opens database bytes with integrity check', () {
      final key = Uint8List.fromList(List.generate(32, (i) => i));
      final crypto = SqliteVaultCrypto.fromKey(key);
      final databaseBytes = Uint8List.fromList([1, 2, 3, 4, 5]);

      final sealed = crypto.sealDatabaseBytes(databaseBytes);
      expect(sealed.length, greaterThan(databaseBytes.length));

      final opened = crypto.openSealedDatabaseBytes(sealed);
      expect(opened, databaseBytes);
    });

    test('rejects tampered ciphertext', () {
      final key = Uint8List.fromList(List.generate(32, (i) => i));
      final crypto = SqliteVaultCrypto.fromKey(key);
      final sealed = crypto.sealDatabaseBytes(Uint8List.fromList([9, 8, 7]));
      sealed[sealed.length - 1] ^= 0xff;

      expect(
        () => crypto.openSealedDatabaseBytes(sealed),
        throwsA(isA<SqliteVaultCryptoException>()),
      );
    });
  });

  group('EncryptedSqliteVaultSyncPipeline', () {
    test('uploads sealed vault without exposing plaintext to transport', () async {
      final dir = await Directory.systemTemp.createTemp('sqlite_vault_');
      final dbPath = '${dir.path}/archiveme.db';
      final db = await databaseFactory.openDatabase(dbPath);
      await SqliteMigrationManager().run(db);
      await db.close();

      const namespace = AccountNamespace.guest;
      final keyStore = InMemorySqliteVaultKeyStore();
      final transport = InMemorySqliteVaultCloudTransport();

      final pipeline = EncryptedSqliteVaultSyncPipeline(
        sqliteFilePath: dbPath,
        accountNamespace: namespace,
        keyStore: keyStore,
        cloudTransport: transport,
      );

      final result = await pipeline.uploadVault();
      expect(result, isA<SqliteVaultUploadSuccess>());

      final cloudPath = SqliteVaultConfig.vaultRelativePath(namespace.key);
      expect(transport.hasObject(cloudPath), isTrue);

      await dir.delete(recursive: true);
    });

    test('round-trips upload and restore through in-memory iCloud transport', () async {
      final dir = await Directory.systemTemp.createTemp('sqlite_vault_rt_');
      final dbPath = '${dir.path}/archiveme.db';
      final db = await databaseFactory.openDatabase(dbPath);
      await SqliteMigrationManager().run(db);
      await db.rawInsert(
        'CREATE TABLE IF NOT EXISTS vault_marker (id INTEGER PRIMARY KEY, note TEXT)',
      );
      await db.insert('vault_marker', {'note': 'before-upload'});
      await db.close();

      const namespace = AccountNamespace.guest;
      final keyStore = InMemorySqliteVaultKeyStore();
      final transport = InMemorySqliteVaultCloudTransport();

      final pipeline = EncryptedSqliteVaultSyncPipeline(
        sqliteFilePath: dbPath,
        accountNamespace: namespace,
        keyStore: keyStore,
        cloudTransport: transport,
      );

      final upload = await pipeline.uploadVault();
      expect(upload, isA<SqliteVaultUploadSuccess>());

      await File(dbPath).delete();
      expect(await File(dbPath).exists(), isFalse);

      final restore = await pipeline.restoreVaultFromCloud();
      expect(restore, isA<SqliteVaultRestoreSuccess>());
      expect(await File(dbPath).exists(), isTrue);

      final restored = await databaseFactory.openDatabase(dbPath);
      final rows = await restored.query('vault_marker');
      expect(rows.single['note'], 'before-upload');
      await restored.close();

      await dir.delete(recursive: true);
    });
  });
}
