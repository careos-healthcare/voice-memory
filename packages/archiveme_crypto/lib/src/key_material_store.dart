import 'dart:typed_data';

/// Persists key material under a logical key.
///
/// Callers pass **raw** material:
/// - v2 / journal / vault: 32 key bytes
/// - v1 passphrase: `utf8.encode(passphrase)`
///
/// Encoding and any keychain prefix are the implementation's job.
/// The app's `SecureStorageService` writes `base64Encode(material)` at
/// `vm_flutter_` + [logicalKey] (see #282 goldens).
/// Vault keys use a separate unprefixed implementation — they must
/// not go through `SecureStorageService`.
abstract class KeyMaterialStore {
  Future<Uint8List?> readKey(String logicalKey);

  Future<void> writeKey(String logicalKey, Uint8List material);

  Future<void> deleteKey(String logicalKey);
}
