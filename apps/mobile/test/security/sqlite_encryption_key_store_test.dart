import 'dart:convert';
import 'dart:io';

import 'package:archiveme_mobile/security/sqlite/sqlite_encryption_key_store.dart';
import 'package:archiveme_mobile/storage/in_memory_secure_storage.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_database_encryption_key.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_database_initializer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('SecureSqliteEncryptionKeyStore', () {
    late InMemorySecureStorageService secure;
    late SecureSqliteEncryptionKeyStore store;

    setUp(() {
      secure = InMemorySecureStorageService();
      store = SecureSqliteEncryptionKeyStore(store: secure);
    });

    test('ensureEncryptionKey generates a 256-bit key on first boot', () async {
      final first = await store.ensureEncryptionKey();
      final second = await store.ensureEncryptionKey();

      expect(first.rawKeyBytes, isNotNull);
      expect(first.rawKeyBytes!.length, SqliteDatabaseEncryptionKey.keyByteLength);
      expect(second.rawKeyBytes, first.rawKeyBytes);
    });

    test('persists generated key in flutter_secure_storage', () async {
      await store.ensureEncryptionKey();

      final stored = await secure.read('sqlite_encryption_key_v2');
      expect(stored, isNotNull);
      final decoded = base64Decode(stored!);
      expect(decoded.length, SqliteDatabaseEncryptionKey.keyByteLength);
    });

    test('reads legacy v1 passphrase storage', () async {
      const legacy = 'legacy-passphrase-thirty-two-chars-min!!';
      await secure.write(
        'sqlite_encryption_passphrase_v1',
        base64Encode(utf8.encode(legacy)),
      );

      final key = await store.readEncryptionKey();
      expect(key?.sqlcipherPassword, legacy);
      expect(key?.rawKeyBytes, isNull);
    });
  });

  group('SqliteDatabaseInitializer', () {
    test('opens encrypted database under flutter test password', () async {
      final dir = Directory.systemTemp.createTempSync('vm_sqlite_init_');
      final path = '${dir.path}/journal.db';

      final db = await SqliteDatabaseInitializer.open(
        filePath: path,
        passwordOverride: SqliteDatabaseInitializer.testEncryptionPassword,
      );
      try {
        await db.rawQuery('SELECT 1');
        final journalMode = await db.rawQuery('PRAGMA journal_mode');
        expect(journalMode.first.values.first.toString().toLowerCase(), 'wal');
      } finally {
        await db.close();
      }
    });
  });
}
