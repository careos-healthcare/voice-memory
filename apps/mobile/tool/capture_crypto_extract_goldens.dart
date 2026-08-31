import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archiveme_mobile/security/sqlite/sqlite_encryption_key_store.dart';
import 'package:archiveme_mobile/storage/encrypted_json_file_outcome.dart';
import 'package:archiveme_mobile/storage/encrypted_json_file_store.dart';
import 'package:archiveme_mobile/storage/encrypted_json_storage.dart';
import 'package:archiveme_mobile/storage/private_data_encryption_key_store.dart';
import 'package:archiveme_mobile/storage/secure_storage.dart';
import 'package:archiveme_mobile/storage/unprefixed_flutter_secure_storage_key_material_store.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_database_encryption_key.dart';
import 'package:archiveme_mobile/sync/sqlite_vault/sqlite_vault_crypto.dart';
import 'package:archiveme_mobile/sync/sqlite_vault/sqlite_vault_key_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phase 0 of #281 — capture golden vectors from CURRENT production crypto.
///
/// Run once from `apps/mobile`:
///   flutter test tool/capture_crypto_extract_goldens.dart
///
/// Must run under `flutter test`, not `dart run`: the production types
/// transitively import `package:flutter`.
///
/// Do **not** re-run as part of CI. AES-256-GCM uses a random IV/nonce, so a
/// second capture produces different ciphertext and would replace the
/// installed-journal lock. Overwrite only with
/// `ALLOW_CRYPTO_GOLDEN_OVERWRITE=1` if the production wire format itself
/// changed (that is a compatibility break, not a refresh).
///
/// Does not import or modify the nine #281 source files beyond calling them.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('capture crypto extract goldens from current production code', () async {
    final outDir = _goldensDir();
    final manifestFile = File('${outDir.path}/manifest.json');
    final allowOverwrite =
        Platform.environment['ALLOW_CRYPTO_GOLDEN_OVERWRITE'] == '1';
    if (manifestFile.existsSync() && !allowOverwrite) {
      fail(
        'Goldens already exist at ${outDir.path}. Re-running would replace '
        'the installed-journal lock with new random AES-GCM nonces. '
        'Set ALLOW_CRYPTO_GOLDEN_OVERWRITE=1 only if the production wire '
        'format itself changed.',
      );
    }

    final keychain = <String, String>{};
    _installSecureStorageMock(keychain);

    final keyBytes = Uint8List.fromList(List<int>.generate(32, (i) => i));
    final vaultPlaintext = Uint8List.fromList([
      ...utf8.encode('SQLite format 3'),
      0,
      1,
      2,
      3,
      4,
      5,
    ]);
    const jsonPayload = <String, dynamic>{
      'schema': 'crypto_extract_golden_v1',
      'entryId': 'golden-entry-001',
      'transcript': 'fixed words for wire-format lock',
    };
    const fileStorePayload = <Map<String, String>>[
      {
        'id': 'golden-entry-001',
        'transcript': 'fixed words for wire-format lock',
      },
    ];
    const legacyPassphrase = 'legacy-passphrase-thirty-two-chars-min!!';

    final vaultCrypto = SqliteVaultCrypto.fromKey(keyBytes);
    final sealed = vaultCrypto.sealDatabaseBytes(vaultPlaintext);
    expect(
      vaultCrypto.openSealedDatabaseBytes(sealed),
      vaultPlaintext,
      reason: 'captured vault blob must open with the production opener',
    );

    final jsonStorage = EncryptedJsonStorage(masterKeyBytes: keyBytes);
    final jsonEnvelope = await jsonStorage.encryptData(jsonPayload);
    expect(await jsonStorage.decryptData(jsonEnvelope), jsonPayload);

    final tempDir = await Directory.systemTemp.createTemp(
      'crypto_extract_golden_',
    );
    addTearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });
    final journalFile = File('${tempDir.path}/journal.enc');
    final fileStore = EncryptedJsonFileStore(
      file: journalFile,
      keyStore: InMemoryPrivateDataEncryptionKeyStore(seedKey: keyBytes),
    );
    expect(
      await fileStore.writeJsonOutcome(fileStorePayload),
      isA<EncryptedJsonWriteSuccess>(),
    );
    final fileEnvelope = await journalFile.readAsString();
    expect(await fileStore.readJson(), fileStorePayload);

    final secure = SecureStorageService();
    final sqlcipherStore = SecureSqliteEncryptionKeyStore(secure: secure);
    await sqlcipherStore.writeEncryptionKey(
      SqliteDatabaseEncryptionKey.fromStored(base64Encode(keyBytes)),
    );
    await sqlcipherStore.writePassphrase(legacyPassphrase);

    final sqlcipherAliased = SecureSqliteEncryptionKeyStore(
      secure: secure,
      keyAlias: 'guest',
    );
    await sqlcipherAliased.writeEncryptionKey(
      SqliteDatabaseEncryptionKey.fromStored(base64Encode(keyBytes)),
    );

    final journalKeys = SecurePrivateDataEncryptionKeyStore(store: secure);
    await journalKeys.writeKeyBytes(keyBytes);
    final journalKeysAliased = SecurePrivateDataEncryptionKeyStore(
      store: secure,
      keyAlias: 'guest',
    );
    await journalKeysAliased.writeKeyBytes(keyBytes);

    final vaultKeys = SecureSqliteVaultKeyStore(
      store: UnprefixedFlutterSecureStorageKeyMaterialStore(),
      accountNamespace: 'guest',
    );
    await vaultKeys.writeKey(keyBytes);

    final v2Stored = base64Encode(keyBytes);
    final v2Key = SqliteDatabaseEncryptionKey.fromStored(v2Stored);
    final v1Stored = base64Encode(utf8.encode(legacyPassphrase));
    final v1Key = SqliteDatabaseEncryptionKey.fromStored(v1Stored);
    final testInstance = SqliteDatabaseEncryptionKey.testInstance;

    final jsonEnvelopeMap = jsonDecode(jsonEnvelope) as Map<String, dynamic>;
    final fileEnvelopeMap = jsonDecode(fileEnvelope) as Map<String, dynamic>;

    await outDir.create(recursive: true);
    await File('${outDir.path}/sqlite_vault_sealed.bin').writeAsBytes(sealed);
    await File(
      '${outDir.path}/encrypted_json_storage_envelope.json',
    ).writeAsString(jsonEnvelope);
    await File(
      '${outDir.path}/encrypted_json_file_store_envelope.json',
    ).writeAsString(fileEnvelope);

    final manifest = <String, dynamic>{
      'doNotRegenerate': true,
      'phase': 0,
      'issue': 281,
      'capturedFrom':
          'current production code on archive-me/extract-archiveme-ui; '
          'AES blobs include a random IV/nonce and must stay frozen',
      'fixedKeyHex': _hex(keyBytes),
      'schema': {
        'sqliteVaultCrypto': {
          'keyByteLength': SqliteVaultCrypto.keyByteLength,
          'ivByteLength': SqliteVaultCrypto.ivByteLength,
          'digestByteLength': SqliteVaultCrypto.digestByteLength,
          'plaintextLayout': '[database bytes][32-byte SHA-256]',
          'wireLayout': '[12-byte IV][ciphertext+GCM tag]',
        },
        'encryptedJsonStorage': {
          'envelopeKeys': ['cipher', 'nonce', 'mac'],
          'nonceByteLength': base64
              .decode(
                jsonEnvelopeMap['nonce'] as String,
              )
              .length,
          'macByteLength': base64
              .decode(
                jsonEnvelopeMap['mac'] as String,
              )
              .length,
        },
        'encryptedJsonFileStore': {
          'envelopeVersion': EncryptedJsonFileStore.envelopeVersion,
          'envelopeKeys': ['v', 'n', 'c', 'm'],
          'nonceByteLength': base64
              .decode(
                fileEnvelopeMap['n'] as String,
              )
              .length,
          'macByteLength': base64
              .decode(
                fileEnvelopeMap['m'] as String,
              )
              .length,
        },
        'noWireFormat': [
          'encrypted_json_file_hooks.dart',
          'encrypted_json_file_outcome.dart',
        ],
        'sqlcipherDerivation':
            'not PBKDF2; v2 password is the base64 of 32 raw bytes; '
            'v1 password is utf8(base64_decode(stored))',
        'secureStoragePhysicalPrefix': 'vm_flutter_',
        'vaultKeyStoreUsesFlutterSecureStorageDirectly': true,
      },
      'sqliteVaultCrypto': {
        'plaintextHex': _hex(vaultPlaintext),
        'sealedBlobHex': _hex(sealed),
        'sealedBlobFile': 'sqlite_vault_sealed.bin',
      },
      'encryptedJsonStorage': {
        'plaintext': jsonPayload,
        'envelopeFile': 'encrypted_json_storage_envelope.json',
        'envelope': jsonEnvelopeMap,
      },
      'encryptedJsonFileStore': {
        'plaintext': fileStorePayload,
        'envelopeFile': 'encrypted_json_file_store_envelope.json',
        'envelope': fileEnvelopeMap,
      },
      'keychainEntries': {
        'sqlite_encryption_key_v2': {
          'logicalKey': 'sqlite_encryption_key_v2',
          'physicalKey': 'vm_flutter_sqlite_encryption_key_v2',
          'storedValue': v2Stored,
        },
        'sqlite_encryption_key_v2__guest': {
          'logicalKey': 'sqlite_encryption_key_v2__guest',
          'physicalKey': 'vm_flutter_sqlite_encryption_key_v2__guest',
          'storedValue': v2Stored,
        },
        'sqlite_encryption_passphrase_v1': {
          'logicalKey': 'sqlite_encryption_passphrase_v1',
          'physicalKey': 'vm_flutter_sqlite_encryption_passphrase_v1',
          'storedValue': v1Stored,
        },
        'private_journal_encryption_key_v1': {
          'logicalKey': 'private_journal_encryption_key_v1',
          'physicalKey': 'vm_flutter_private_journal_encryption_key_v1',
          'storedValue': v2Stored,
        },
        'private_journal_encryption_key_v1__guest': {
          'logicalKey': 'private_journal_encryption_key_v1__guest',
          'physicalKey': 'vm_flutter_private_journal_encryption_key_v1__guest',
          'storedValue': v2Stored,
        },
        'sqlite_vault_aes_key_v1__guest': {
          'logicalKey': 'sqlite_vault_aes_key_v1__guest',
          'physicalKey': 'sqlite_vault_aes_key_v1__guest',
          'storedValue': v2Stored,
          'note':
              'Vault key store talks to FlutterSecureStorage directly — '
              'no vm_flutter_ prefix.',
        },
      },
      'observedKeychainKeys': keychain.keys.toList()..sort(),
      'sqlcipherFromStored': {
        'v2': {
          'stored': v2Stored,
          'sqlcipherPassword': v2Key.sqlcipherPassword,
          'rawKeyBytesHex': _hex(v2Key.rawKeyBytes!),
        },
        'v1Legacy': {
          'stored': v1Stored,
          'sqlcipherPassword': v1Key.sqlcipherPassword,
          'rawKeyBytes': null,
          'passphrase': legacyPassphrase,
        },
        'testInstance': {
          'sqlcipherPassword': testInstance.sqlcipherPassword,
          'rawKeyBytesHex': _hex(testInstance.rawKeyBytes!),
        },
      },
    };

    expect(
      keychain['vm_flutter_sqlite_encryption_key_v2'],
      v2Stored,
      reason: 'v2 SQLCipher key must land at the prefixed physical key',
    );
    expect(
      keychain['vm_flutter_sqlite_encryption_key_v2__guest'],
      v2Stored,
    );
    expect(
      keychain['vm_flutter_sqlite_encryption_passphrase_v1'],
      v1Stored,
    );
    expect(
      keychain['vm_flutter_private_journal_encryption_key_v1'],
      v2Stored,
    );
    expect(
      keychain['vm_flutter_private_journal_encryption_key_v1__guest'],
      v2Stored,
    );
    expect(keychain['sqlite_vault_aes_key_v1__guest'], v2Stored);
    expect(v2Key.sqlcipherPassword, v2Stored);
    expect(v1Key.sqlcipherPassword, legacyPassphrase);
    expect(v1Key.rawKeyBytes, isNull);

    await manifestFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(manifest),
    );
    expect(manifestFile.existsSync(), isTrue);
  });
}

Directory _goldensDir() {
  final root = _mobileRoot();
  return Directory('${root.path}/test/fixtures/crypto_extract_goldens');
}

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
  throw StateError(
    'Run from apps/mobile or the repo root, not ${cwd.path}',
  );
}

void _installSecureStorageMock(Map<String, String> store) {
  const channel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
        final args =
            (call.arguments as Map?)?.cast<String, dynamic>() ?? const {};
        switch (call.method) {
          case 'read':
            return store[args['key'] as String?];
          case 'write':
            store[args['key'] as String] = args['value'] as String;
            return null;
          case 'delete':
            store.remove(args['key'] as String);
            return null;
          case 'deleteAll':
            store.clear();
            return null;
          case 'readAll':
            return Map<String, String>.from(store);
          case 'containsKey':
            return store.containsKey(args['key'] as String);
          default:
            return null;
        }
      });
}

String _hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
