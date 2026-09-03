import 'package:archiveme_crypto/archiveme_crypto.dart';
import 'package:test/test.dart';

import 'support/recording_key_material_store.dart';

void main() {
  test('writes 32 raw bytes at the default logical key', () async {
    final backend = RecordingKeyMaterialStore();
    final store = SecurePrivateDataEncryptionKeyStore(store: backend);
    final key = freshKeyBytes(fill: 0x71);
    await store.writeKeyBytes(key);

    expect(backend.writes, [SecurePrivateDataEncryptionKeyStore.storageKey]);
    expect(await store.readKeyBytes(), key);
    expect(
      backend.snapshot[SecurePrivateDataEncryptionKeyStore.storageKey],
      key,
    );
  });

  test('a non-empty alias is appended to the logical key', () async {
    final backend = RecordingKeyMaterialStore();
    final store = SecurePrivateDataEncryptionKeyStore(
      store: backend,
      keyAlias: 'acct-a',
    );
    await store.writeKeyBytes(freshKeyBytes(fill: 0x72));
    expect(backend.writes, ['private_journal_encryption_key_v1__acct-a']);
    expect(
      await SecurePrivateDataEncryptionKeyStore(store: backend).readKeyBytes(),
      isNull,
      reason: 'the un-aliased store must not see another alias',
    );
  });

  test('reject the wrong key length', () async {
    final store = SecurePrivateDataEncryptionKeyStore(
      store: RecordingKeyMaterialStore(),
    );
    expect(() => store.writeKeyBytes([1, 2, 3]), throwsArgumentError);
  });

  test('ensureKey does not replace an existing 32-byte key', () async {
    final backend = RecordingKeyMaterialStore();
    final store = SecurePrivateDataEncryptionKeyStore(store: backend);
    final existing = freshKeyBytes(fill: 0x73);
    await store.writeKeyBytes(existing);
    expect(await store.ensureKey(), existing);
    expect(backend.writes, [SecurePrivateDataEncryptionKeyStore.storageKey]);
  });

  test('ensureKey mints a 32-byte key when empty', () async {
    final store = SecurePrivateDataEncryptionKeyStore(
      store: RecordingKeyMaterialStore(),
    );
    final minted = await store.ensureKey();
    expect(minted, hasLength(SecurePrivateDataEncryptionKeyStore.keyByteLength));
    expect(await store.readKeyBytes(), minted);
  });

  test('deleteKey removes the material', () async {
    final store = SecurePrivateDataEncryptionKeyStore(
      store: RecordingKeyMaterialStore(),
    );
    await store.writeKeyBytes(freshKeyBytes(fill: 0x74));
    await store.deleteKey();
    expect(await store.readKeyBytes(), isNull);
  });

  test('InMemoryPrivateDataEncryptionKeyStore seed and ensureKey', () async {
    final seeded = InMemoryPrivateDataEncryptionKeyStore(
      seedKey: freshKeyBytes(fill: 0x75),
    );
    expect(await seeded.readKeyBytes(), freshKeyBytes(fill: 0x75));
    expect(await seeded.ensureKey(), freshKeyBytes(fill: 0x75));

    final empty = InMemoryPrivateDataEncryptionKeyStore();
    final minted = await empty.ensureKey();
    expect(minted, hasLength(32));
    expect(await empty.ensureKey(), minted);
  });
}
