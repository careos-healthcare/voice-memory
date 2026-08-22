import 'dart:io';

import 'package:archiveme_mobile/storage/account_namespace.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_migration_manager.dart';
import 'package:archiveme_mobile/sync/cloud_backup_models.dart';
import 'package:archiveme_mobile/sync/cloud_backup_packager.dart';
import 'package:archiveme_mobile/sync/cloud_backup_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('seals and restores drift database with passphrase', () async {
    final dir = await Directory.systemTemp.createTemp('cloud_backup_');
    final dbPath = '${dir.path}/archiveme.db';
    final db = await databaseFactory.openDatabase(dbPath);
    await SqliteMigrationManager().run(db);
    await db.close();

    const namespace = AccountNamespace.guest;
    const passphrase = 'user-cloud-backup-passphrase';

    final exported = await EncryptedCloudBackupService(
      sqliteFilePath: dbPath,
      accountNamespace: namespace,
    ).exportBackup(
      passphrase: passphrase,
      outputDirectory: dir.path,
    );

    expect(exported.succeeded, isTrue);
    expect(exported.outputPath, isNotNull);

    final raw = await File(exported.outputPath!).readAsString();
    final envelope = CloudBackupPackager.decodeEnvelope(raw);
    expect(envelope.accountNamespace, namespace.key);
    expect(envelope.kdf, CloudBackupFormat.kdfAlgorithm);

    await File(dbPath).delete();
    expect(await File(dbPath).exists(), isFalse);

    final imported = await EncryptedCloudBackupService(
      sqliteFilePath: dbPath,
      accountNamespace: namespace,
    ).importBackup(rawEnvelope: raw, passphrase: passphrase);

    expect(imported.succeeded, isTrue);
    expect(await File(dbPath).exists(), isTrue);

    final restored = await databaseFactory.openDatabase(dbPath);
    final versionRows = await restored.rawQuery('PRAGMA user_version');
    expect(versionRows.single['user_version'], greaterThan(0));
    await restored.close();

    await dir.delete(recursive: true);
  });

  test('rejects wrong passphrase', () async {
    final dir = await Directory.systemTemp.createTemp('cloud_backup_wrong_');
    final dbPath = '${dir.path}/archiveme.db';
    final db = await databaseFactory.openDatabase(dbPath);
    await SqliteMigrationManager().run(db);
    await db.close();

    const passphrase = 'correct-passphrase-value';
    const wrong = 'incorrect-passphrase-value';

    final exported = await EncryptedCloudBackupService(
      sqliteFilePath: dbPath,
      accountNamespace: AccountNamespace.guest,
    ).exportBackup(passphrase: passphrase, outputDirectory: dir.path);

    final raw = await File(exported.outputPath!).readAsString();
    final imported = await EncryptedCloudBackupService(
      sqliteFilePath: dbPath,
      accountNamespace: AccountNamespace.guest,
    ).importBackup(rawEnvelope: raw, passphrase: wrong);

    expect(imported.failure, CloudBackupImportFailure.wrongPassphrase);

    await dir.delete(recursive: true);
  });

  test('detects namespace mismatch on import', () async {
    final dir = await Directory.systemTemp.createTemp('cloud_backup_ns_');
    final dbPath = '${dir.path}/archiveme.db';
    final db = await databaseFactory.openDatabase(dbPath);
    await SqliteMigrationManager().run(db);
    await db.close();

    const passphrase = 'namespace-test-passphrase';

    final exported = await EncryptedCloudBackupService(
      sqliteFilePath: dbPath,
      accountNamespace: AccountNamespace.guest,
    ).exportBackup(passphrase: passphrase, outputDirectory: dir.path);

    final raw = await File(exported.outputPath!).readAsString();
    final imported = await EncryptedCloudBackupService(
      sqliteFilePath: dbPath,
      accountNamespace: AccountNamespace.forUserId('other-user'),
    ).importBackup(rawEnvelope: raw, passphrase: passphrase);

    expect(imported.failure, CloudBackupImportFailure.namespaceMismatch);

    await dir.delete(recursive: true);
  });
}
