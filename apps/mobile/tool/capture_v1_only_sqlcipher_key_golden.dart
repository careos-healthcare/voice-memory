import 'dart:convert';
import 'dart:io';

import 'package:archiveme_mobile/security/sqlite/sqlite_encryption_key_store.dart';
import 'package:archiveme_mobile/storage/in_memory_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// Capture the v1-only SQLCipher key path from CURRENT production code.
///
/// Phase 0's main capture wrote v2 and v1 as siblings on a fresh store. It
/// did not seed a v1-only keychain and then call [ensureEncryptionKey] —
/// the boot path that would mint a v2 key on a new install.
///
/// Production does **not** write-forward v1 → v2. [readEncryptionKey] falls
/// back to v1; [ensureEncryptionKey] returns that key and leaves v2 absent.
/// Writing a new v2 key here would change the SQLCipher password and lock
/// the user out of an existing journal. This fixture locks that behavior.
///
/// Run once from `apps/mobile`:
///   flutter test tool/capture_v1_only_sqlcipher_key_golden.dart
///
/// Does not touch AES-GCM blobs. Overwrite only with
/// `ALLOW_CRYPTO_GOLDEN_OVERWRITE=1`.
void main() {
  test('capture v1-only ensureEncryptionKey path', () async {
    final out = File(
      '${_goldensDir().path}/v1_only_ensure.json',
    );
    final allowOverwrite =
        Platform.environment['ALLOW_CRYPTO_GOLDEN_OVERWRITE'] == '1';
    if (out.existsSync() && !allowOverwrite) {
      fail(
        'v1-only golden already exists at ${out.path}. Re-running is only '
        'valid if production key-store behavior itself changed. Set '
        'ALLOW_CRYPTO_GOLDEN_OVERWRITE=1 to replace it.',
      );
    }

    const passphrase = 'legacy-passphrase-thirty-two-chars-min!!';
    final v1Stored = base64Encode(utf8.encode(passphrase));

    final secure = InMemorySecureStorageService();
    await secure.write('sqlite_encryption_passphrase_v1', v1Stored);
    expect(await secure.read('sqlite_encryption_key_v2'), isNull);

    final store = SecureSqliteEncryptionKeyStore(secure: secure);
    final ensured = await store.ensureEncryptionKey();
    final readBack = await store.readEncryptionKey();

    final fixture = <String, dynamic>{
      'doNotRegenerate': true,
      'phase': 0,
      'issue': 281,
      'capturedFrom':
          'current production SecureSqliteEncryptionKeyStore; v1-only '
          'keychain then ensureEncryptionKey (the first-boot path)',
      'productionBehavior':
          'ensureEncryptionKey on a v1-only install returns the v1 '
          'passphrase and does not write sqlite_encryption_key_v2. There '
          'is no write-forward migration; v1 remains the SQLCipher password.',
      'beforeEnsure': {
        'logicalKeysPresent': ['sqlite_encryption_passphrase_v1'],
        'sqlite_encryption_passphrase_v1': v1Stored,
        'sqlite_encryption_key_v2': null,
      },
      'afterEnsure': {
        'sqlcipherPassword': ensured.sqlcipherPassword,
        'rawKeyBytes': null,
        'sqlite_encryption_passphrase_v1': await secure.read(
          'sqlite_encryption_passphrase_v1',
        ),
        'sqlite_encryption_key_v2': await secure.read(
          'sqlite_encryption_key_v2',
        ),
        'readEncryptionKeyMatchesEnsure':
            readBack?.sqlcipherPassword == ensured.sqlcipherPassword,
      },
    };

    expect(ensured.sqlcipherPassword, passphrase);
    expect(ensured.rawKeyBytes, isNull);
    expect(await secure.read('sqlite_encryption_key_v2'), isNull);
    expect(await secure.read('sqlite_encryption_passphrase_v1'), v1Stored);
    expect(readBack?.sqlcipherPassword, passphrase);

    await out.parent.create(recursive: true);
    await out.writeAsString(
      const JsonEncoder.withIndent('  ').convert(fixture),
    );
    expect(out.existsSync(), isTrue);
  });
}

Directory _goldensDir() {
  final cwd = Directory.current;
  if (File('${cwd.path}/pubspec.yaml').existsSync() &&
      cwd.path.endsWith('apps/mobile')) {
    return Directory('${cwd.path}/test/fixtures/crypto_extract_goldens');
  }
  final nested = Directory('${cwd.path}/apps/mobile');
  if (File('${nested.path}/pubspec.yaml').existsSync()) {
    return Directory('${nested.path}/test/fixtures/crypto_extract_goldens');
  }
  throw StateError('Run from apps/mobile or the repo root, not ${cwd.path}');
}
