import 'dart:typed_data';

import 'package:archiveme_crypto/archiveme_crypto.dart';
import 'package:test/test.dart';

import 'support/recording_key_material_store.dart';

void main() {
  test('writes 32 raw bytes at sqlite_vault_aes_key_v1__<namespace>', () async {
    final backend = RecordingKeyMaterialStore();
    final store = SecureSqliteVaultKeyStore(
      store: backend,
      accountNamespace: 'ns-one',
    );
    final key = freshKeyBytes(fill: 0x81);
    await store.writeKey(key);

    expect(backend.writes, ['sqlite_vault_aes_key_v1__ns-one']);
    expect(backend.writes.single.startsWith(SecureSqliteVaultKeyStore.storageKeyPrefix), isTrue);
    expect(await store.readKey(), key);
  });

  test('namespaces are isolated', () async {
    final backend = RecordingKeyMaterialStore();
    final a = SecureSqliteVaultKeyStore(store: backend, accountNamespace: 'a');
    final b = SecureSqliteVaultKeyStore(store: backend, accountNamespace: 'b');
    await a.writeKey(freshKeyBytes(fill: 0x82));
    await b.writeKey(freshKeyBytes(fill: 0x83));
    expect(await a.readKey(), freshKeyBytes(fill: 0x82));
    expect(await b.readKey(), freshKeyBytes(fill: 0x83));
  });

  test('reject the wrong key length', () async {
    final store = SecureSqliteVaultKeyStore(
      store: RecordingKeyMaterialStore(),
      accountNamespace: 'ns',
    );
    expect(() => store.writeKey(Uint8List(8)), throwsArgumentError);
  });

  test('ensureKey does not replace an existing 32-byte key', () async {
    final backend = RecordingKeyMaterialStore();
    final store = SecureSqliteVaultKeyStore(
      store: backend,
      accountNamespace: 'ns',
    );
    final existing = freshKeyBytes(fill: 0x84);
    await store.writeKey(existing);
    expect(await store.ensureKey(), existing);
    expect(backend.writes, ['sqlite_vault_aes_key_v1__ns']);
  });

  test('ensureKey mints a 32-byte key when empty', () async {
    final store = SecureSqliteVaultKeyStore(
      store: RecordingKeyMaterialStore(),
      accountNamespace: 'ns',
    );
    final minted = await store.ensureKey();
    expect(minted, hasLength(SqliteVaultKeyStore.keyByteLength));
    expect(await store.readKey(), minted);
  });

  test('deleteKey removes only that namespace', () async {
    final backend = RecordingKeyMaterialStore();
    final a = SecureSqliteVaultKeyStore(store: backend, accountNamespace: 'a');
    final b = SecureSqliteVaultKeyStore(store: backend, accountNamespace: 'b');
    await a.writeKey(freshKeyBytes(fill: 0x85));
    await b.writeKey(freshKeyBytes(fill: 0x86));
    await a.deleteKey();
    expect(await a.readKey(), isNull);
    expect(await b.readKey(), freshKeyBytes(fill: 0x86));
  });

  test('InMemorySqliteVaultKeyStore.ensureKey is deterministic 0..31', () async {
    final store = InMemorySqliteVaultKeyStore();
    final first = await store.ensureKey();
    expect(first, Uint8List.fromList(List<int>.generate(32, (i) => i)));
    expect(await store.ensureKey(), first);
  });
}
