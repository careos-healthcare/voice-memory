import 'dart:convert';
import 'dart:typed_data';

import 'package:archiveme_crypto/archiveme_crypto.dart';
import 'package:test/test.dart';

import 'support/from_stored_vectors.dart';
import 'support/recording_key_material_store.dart';

void main() {
  final v2Raw = Uint8List.fromList(List<int>.filled(32, v2RawFillByte));
  final v1Raw = Uint8List.fromList(utf8.encode(v1Passphrase));

  test('writing a generated key lands only in the v2 logical slot', () async {
    final backend = RecordingKeyMaterialStore();
    final store = SecureSqliteEncryptionKeyStore(store: backend);
    final generated = SqliteDatabaseEncryptionKey.generate();
    await store.writeEncryptionKey(generated);

    expect(backend.writes, [SecureSqliteEncryptionKeyStore.defaultStorageKeyV2]);
    expect(
      backend.snapshot[SecureSqliteEncryptionKeyStore.defaultStorageKeyV1],
      isNull,
    );
    final read = await store.readEncryptionKey();
    expect(read!.sqlcipherPassword, generated.sqlcipherPassword);
    expect(read.rawKeyBytes, generated.rawKeyBytes);
  });

  test('v1-only material is returned and ensureEncryptionKey does not mint v2', () async {
    final backend = RecordingKeyMaterialStore();
    // Host store holds raw utf8(passphrase). fromStored is given the
    // independently encoded v1Stored equivalent (base64 of those bytes).
    await backend.writeKey(
      SecureSqliteEncryptionKeyStore.defaultStorageKeyV1,
      v1Raw,
    );
    final store = SecureSqliteEncryptionKeyStore(store: backend);

    final ensured = await store.ensureEncryptionKey();
    expect(ensured.sqlcipherPassword, v1Passphrase);
    expect(ensured.rawKeyBytes, isNull);
    expect(
      SqliteDatabaseEncryptionKey.fromStored(v1Stored).sqlcipherPassword,
      ensured.sqlcipherPassword,
    );
    expect(
      backend.snapshot[SecureSqliteEncryptionKeyStore.defaultStorageKeyV2],
      isNull,
    );
    expect(
      backend.snapshot[SecureSqliteEncryptionKeyStore.defaultStorageKeyV1],
      v1Raw,
    );
    expect(
      backend.writes.where((k) => k.contains('sqlite_encryption_key_v2')),
      isEmpty,
      reason: 'ensure must not write a v2 key when v1 exists',
    );
  });

  test('read prefers v2 when both slots are populated', () async {
    final backend = RecordingKeyMaterialStore();
    await backend.writeKey(
      SecureSqliteEncryptionKeyStore.defaultStorageKeyV2,
      v2Raw,
    );
    await backend.writeKey(
      SecureSqliteEncryptionKeyStore.defaultStorageKeyV1,
      v1Raw,
    );
    final read = await SecureSqliteEncryptionKeyStore(
      store: backend,
    ).readEncryptionKey();
    expect(read!.sqlcipherPassword, v2Stored);
    expect(read.rawKeyBytes, v2Raw);
  });

  test('writePassphrase of a long secret stays in the v1 slot', () async {
    final backend = RecordingKeyMaterialStore();
    final store = SecureSqliteEncryptionKeyStore(store: backend);
    await store.writePassphrase(v1Passphrase);
    expect(backend.writes, [SecureSqliteEncryptionKeyStore.defaultStorageKeyV1]);
    expect(await store.readPassphrase(), v1Passphrase);
    expect(backend.snapshot[SecureSqliteEncryptionKeyStore.defaultStorageKeyV1], v1Raw);
    expect(
      backend.snapshot[SecureSqliteEncryptionKeyStore.defaultStorageKeyV2],
      isNull,
    );
  });

  test('writePassphrase of a 32-byte utf8 secret follows fromStored (lands as v2)', () async {
    final backend = RecordingKeyMaterialStore();
    final store = SecureSqliteEncryptionKeyStore(store: backend);
    await store.writePassphrase(v2LooksLikePassphrase);
    expect(backend.writes, [SecureSqliteEncryptionKeyStore.defaultStorageKeyV2]);
    final read = await store.readEncryptionKey();
    expect(read!.sqlcipherPassword, v2LooksLikePassphraseStored);
    expect(read.rawKeyBytes, utf8.encode(v2LooksLikePassphrase));
  });

  test('an alias is appended to both logical keys', () async {
    final backend = RecordingKeyMaterialStore();
    final store = SecureSqliteEncryptionKeyStore(
      store: backend,
      keyAlias: 'acct-b',
    );
    await store.writeEncryptionKey(SqliteDatabaseEncryptionKey.generate());
    expect(backend.writes, ['sqlite_encryption_key_v2__acct-b']);
  });

  test('deleteEncryptionKey removes v1 and v2', () async {
    final backend = RecordingKeyMaterialStore();
    await backend.writeKey(
      SecureSqliteEncryptionKeyStore.defaultStorageKeyV2,
      v2Raw,
    );
    await backend.writeKey(
      SecureSqliteEncryptionKeyStore.defaultStorageKeyV1,
      v1Raw,
    );
    await SecureSqliteEncryptionKeyStore(store: backend).deleteEncryptionKey();
    expect(await backend.readKey(SecureSqliteEncryptionKeyStore.defaultStorageKeyV2), isNull);
    expect(await backend.readKey(SecureSqliteEncryptionKeyStore.defaultStorageKeyV1), isNull);
    expect(backend.deletes, [
      SecureSqliteEncryptionKeyStore.defaultStorageKeyV2,
      SecureSqliteEncryptionKeyStore.defaultStorageKeyV1,
    ]);
  });

  test('ensureEncryptionKey on empty mints a v2 key', () async {
    final backend = RecordingKeyMaterialStore();
    final store = SecureSqliteEncryptionKeyStore(store: backend);
    final minted = await store.ensureEncryptionKey();
    expect(minted.rawKeyBytes, hasLength(32));
    expect(
      backend.snapshot[SecureSqliteEncryptionKeyStore.defaultStorageKeyV2],
      minted.rawKeyBytes,
    );
    expect(await store.ensureEncryptionKey(), predicate<SqliteDatabaseEncryptionKey>((k) {
      return k.sqlcipherPassword == minted.sqlcipherPassword;
    }));
  });

  test('InMemorySqliteEncryptionKeyStore is a single slot', () async {
    final store = InMemorySqliteEncryptionKeyStore();
    expect(await store.readEncryptionKey(), isNull);
    final minted = await store.ensureEncryptionKey();
    expect(await store.ensureEncryptionKey(), minted);
    await store.deleteEncryptionKey();
    expect(await store.readEncryptionKey(), isNull);
  });
}
