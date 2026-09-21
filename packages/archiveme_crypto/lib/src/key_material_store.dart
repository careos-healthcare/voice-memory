import 'dart:typed_data';

/// Persists key material under a logical key.
///
/// Callers pass **raw** material:
/// - v2 / journal / vault: 32 key bytes
/// - v1 passphrase: `utf8.encode(passphrase)`
///
/// Encoding and any keychain prefix are the host implementation's job.
/// Vault keys and journal/SQLCipher keys typically use different host
/// adapters (unprefixed vs prefixed) so they do not collide.
abstract class KeyMaterialStore {
  Future<Uint8List?> readKey(String logicalKey);

  Future<void> writeKey(String logicalKey, Uint8List material);

  Future<void> deleteKey(String logicalKey);
}
