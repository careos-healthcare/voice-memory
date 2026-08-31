import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archiveme_crypto/archiveme_crypto.dart';
import 'package:archiveme_mobile/security/sqlite/sqlite_encryption_key_store.dart';
import 'package:archiveme_mobile/storage/encrypted_json_file_store.dart';
import 'package:archiveme_mobile/storage/in_memory_secure_storage.dart';
import 'package:archiveme_mobile/storage/private_data_encryption_key_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phase 0 of #281 — locked vectors captured from current production crypto.
///
/// These fixtures are **not** regenerated. AES-256-GCM uses a random IV/nonce;
/// the checked-in blobs are the installed-journal compatibility lock. Extraction
/// must still open them byte-for-byte as they stand.
///
/// Capture (once, never in CI):
///   flutter test tool/capture_crypto_extract_goldens.dart
void main() {
  late Map<String, dynamic> manifest;
  late List<int> keyBytes;

  setUpAll(() {
    final dir = _goldensDir();
    final manifestFile = File('${dir.path}/manifest.json');
    expect(
      manifestFile.existsSync(),
      isTrue,
      reason:
          'Missing ${manifestFile.path}. Capture once with '
          '`flutter test tool/capture_crypto_extract_goldens.dart` — do not '
          'invent replacement blobs.',
    );
    manifest =
        jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
    keyBytes = _unhex(manifest['fixedKeyHex'] as String);
    expect(keyBytes.length, 32);
  });

  test('checked-in vault blob opens with extracted SqliteVaultCrypto', () {
    final vault = manifest['sqliteVaultCrypto'] as Map<String, dynamic>;
    final sealedFile = File(
      '${_goldensDir().path}/${vault['sealedBlobFile']}',
    );
    final sealed = sealedFile.readAsBytesSync();
    expect(
      _hex(sealed),
      vault['sealedBlobHex'],
      reason:
          'sqlite_vault_sealed.bin must match the hex lock in manifest.json',
    );

    final plaintext = _unhex(vault['plaintextHex'] as String);
    final opened = SqliteVaultCrypto.fromKey(
      Uint8List.fromList(keyBytes),
    ).openSealedDatabaseBytes(Uint8List.fromList(sealed));
    expect(opened, plaintext);
  });

  test(
    'checked-in EncryptedJsonStorage envelope decrypts via extracted type',
    () async {
      final section = manifest['encryptedJsonStorage'] as Map<String, dynamic>;
      final envelope = File(
        '${_goldensDir().path}/${section['envelopeFile']}',
      ).readAsStringSync();
      expect(jsonDecode(envelope), section['envelope']);

      final decoded = await EncryptedJsonStorage(
        masterKeyBytes: keyBytes,
      ).decryptData(envelope);
      expect(decoded, section['plaintext']);
    },
  );

  test('checked-in EncryptedJsonFileStore envelope decrypts', () async {
    final section = manifest['encryptedJsonFileStore'] as Map<String, dynamic>;
    final envelope = File(
      '${_goldensDir().path}/${section['envelopeFile']}',
    ).readAsStringSync();
    expect(jsonDecode(envelope), section['envelope']);
    expect(
      (jsonDecode(envelope) as Map<String, dynamic>)['v'],
      EncryptedJsonFileStore.envelopeVersion,
    );

    final temp = await Directory.systemTemp.createTemp('crypto_golden_lock_');
    addTearDown(() {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });
    final file = File('${temp.path}/journal.enc');
    await file.writeAsString(envelope);
    final store = EncryptedJsonFileStore(
      file: file,
      keyStore: InMemoryPrivateDataEncryptionKeyStore(seedKey: keyBytes),
    );
    expect(await store.readJson(), section['plaintext']);
  });

  test(
    'key-store encodings match checked-in keychain values via extracted journal store',
    () async {
      final entries = manifest['keychainEntries'] as Map<String, dynamic>;
      final secure = InMemorySecureStorageService();

      final sqlcipher = SecureSqliteEncryptionKeyStore(secure: secure);
      await sqlcipher.writeEncryptionKey(
        SqliteDatabaseEncryptionKey.fromStored(base64Encode(keyBytes)),
      );
      expect(
        await secure.read('sqlite_encryption_key_v2'),
        (entries['sqlite_encryption_key_v2'] as Map)['storedValue'],
      );

      final aliased = SecureSqliteEncryptionKeyStore(
        secure: secure,
        keyAlias: 'guest',
      );
      await aliased.writeEncryptionKey(
        SqliteDatabaseEncryptionKey.fromStored(base64Encode(keyBytes)),
      );
      expect(
        await secure.read('sqlite_encryption_key_v2__guest'),
        (entries['sqlite_encryption_key_v2__guest'] as Map)['storedValue'],
      );

      final v1 = entries['sqlite_encryption_passphrase_v1'] as Map;
      await sqlcipher.writePassphrase(
        (manifest['sqlcipherFromStored'] as Map)['v1Legacy']['passphrase']
            as String,
      );
      expect(
        await secure.read('sqlite_encryption_passphrase_v1'),
        v1['storedValue'],
      );

      final journal = SecurePrivateDataEncryptionKeyStore(store: secure);
      await journal.writeKeyBytes(keyBytes);
      expect(
        await secure.read('private_journal_encryption_key_v1'),
        (entries['private_journal_encryption_key_v1'] as Map)['storedValue'],
      );

      final journalAliased = SecurePrivateDataEncryptionKeyStore(
        store: secure,
        keyAlias: 'guest',
      );
      await journalAliased.writeKeyBytes(keyBytes);
      expect(
        await secure.read('private_journal_encryption_key_v1__guest'),
        (entries['private_journal_encryption_key_v1__guest']
            as Map)['storedValue'],
      );
    },
  );

  test(
    'SQLCipher fromStored matches checked-in v2 / v1 / testInstance via extracted type',
    () {
      final section = manifest['sqlcipherFromStored'] as Map<String, dynamic>;

      final v2 = section['v2'] as Map<String, dynamic>;
      final v2Key = SqliteDatabaseEncryptionKey.fromStored(
        v2['stored'] as String,
      );
      expect(v2Key.sqlcipherPassword, v2['sqlcipherPassword']);
      expect(_hex(v2Key.rawKeyBytes!), v2['rawKeyBytesHex']);
      expect(v2Key.sqlcipherPassword, v2['stored']);

      final v1 = section['v1Legacy'] as Map<String, dynamic>;
      final v1Key = SqliteDatabaseEncryptionKey.fromStored(
        v1['stored'] as String,
      );
      expect(v1Key.sqlcipherPassword, v1['sqlcipherPassword']);
      expect(v1Key.sqlcipherPassword, v1['passphrase']);
      expect(v1Key.rawKeyBytes, isNull);

      final testInstance = SqliteDatabaseEncryptionKey.testInstance;
      final testSection = section['testInstance'] as Map<String, dynamic>;
      expect(testInstance.sqlcipherPassword, testSection['sqlcipherPassword']);
      expect(_hex(testInstance.rawKeyBytes!), testSection['rawKeyBytesHex']);
    },
  );

  test('wire-format schema constants still match the captured lock', () {
    final schema = manifest['schema'] as Map<String, dynamic>;
    final vault = schema['sqliteVaultCrypto'] as Map<String, dynamic>;
    expect(SqliteVaultCrypto.keyByteLength, vault['keyByteLength']);
    expect(SqliteVaultCrypto.ivByteLength, vault['ivByteLength']);
    expect(SqliteVaultCrypto.digestByteLength, vault['digestByteLength']);

    final fileStore = schema['encryptedJsonFileStore'] as Map<String, dynamic>;
    expect(
      EncryptedJsonFileStore.envelopeVersion,
      fileStore['envelopeVersion'],
    );

    expect(schema['secureStoragePhysicalPrefix'], 'vm_flutter_');
  });

  test(
    'v1-only install survives ensureEncryptionKey without a new v2 key',
    () async {
      final fixtureFile = File('${_goldensDir().path}/v1_only_ensure.json');
      expect(
        fixtureFile.existsSync(),
        isTrue,
        reason:
            'Missing ${fixtureFile.path}. Capture once with '
            '`flutter test tool/capture_v1_only_sqlcipher_key_golden.dart`.',
      );
      final fixture =
          jsonDecode(fixtureFile.readAsStringSync()) as Map<String, dynamic>;
      final before = fixture['beforeEnsure'] as Map<String, dynamic>;
      final after = fixture['afterEnsure'] as Map<String, dynamic>;

      final secure = InMemorySecureStorageService();
      await secure.write(
        'sqlite_encryption_passphrase_v1',
        before['sqlite_encryption_passphrase_v1'] as String,
      );
      expect(await secure.read('sqlite_encryption_key_v2'), isNull);

      final store = SecureSqliteEncryptionKeyStore(secure: secure);
      final ensured = await store.ensureEncryptionKey();

      expect(ensured.sqlcipherPassword, after['sqlcipherPassword']);
      expect(ensured.rawKeyBytes, isNull);
      expect(
        await secure.read('sqlite_encryption_passphrase_v1'),
        after['sqlite_encryption_passphrase_v1'],
      );
      expect(await secure.read('sqlite_encryption_key_v2'), isNull);
      expect(after['sqlite_encryption_key_v2'], isNull);
    },
  );

  test(
    'goldens are frozen — capture script must not overwrite without flag',
    () {
      expect(manifest['doNotRegenerate'], isTrue);
      final script = File(
        '${_mobileRoot().path}/tool/capture_crypto_extract_goldens.dart',
      ).readAsStringSync();
      expect(script, contains('ALLOW_CRYPTO_GOLDEN_OVERWRITE'));
      expect(script, contains('Do **not** re-run as part of CI'));
    },
  );
}

Directory _goldensDir() =>
    Directory('${_mobileRoot().path}/test/fixtures/crypto_extract_goldens');

Directory _mobileRoot() {
  final cwd = Directory.current;
  if (File('${cwd.path}/pubspec.yaml').existsSync() &&
      cwd.path.endsWith('apps/mobile')) {
    return cwd;
  }
  final nested = Directory('${cwd.path}/apps/mobile');
  if (File('${nested.path}/pubspec.yaml').existsSync()) {
    return nested;
  }
  throw StateError('Run from apps/mobile or the repo root, not ${cwd.path}');
}

List<int> _unhex(String hex) {
  final normalized = hex.replaceAll(RegExp(r'\s'), '');
  if (normalized.length.isOdd) {
    throw FormatException('hex string must have even length');
  }
  return [
    for (var i = 0; i < normalized.length; i += 2)
      int.parse(normalized.substring(i, i + 2), radix: 16),
  ];
}

String _hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
