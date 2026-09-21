import 'dart:convert';
import 'dart:typed_data';

import 'package:archiveme_crypto/archiveme_crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// [KeyMaterialStore] that writes the logical key as the physical keychain
/// key — no `vm_flutter_` prefix.
///
/// Required for vault keys (`sqlite_vault_aes_key_v1__$namespace`). Those
/// entries were captured talking to [FlutterSecureStorage] directly; routing
/// them through [SecureStorageService] would prefix the physical key and
/// orphan existing installs.
///
/// iOS accessibility is `first_unlock_this_device` (this-device only, not
/// iCloud keychain), matching the pre-extract vault store. Do not unify
/// with [SecureStorageService]'s `first_unlock`.
class UnprefixedFlutterSecureStorageKeyMaterialStore
    implements KeyMaterialStore {
  UnprefixedFlutterSecureStorageKeyMaterialStore({
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? _defaultStorage;

  static const FlutterSecureStorage _defaultStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  final FlutterSecureStorage _storage;

  @override
  Future<Uint8List?> readKey(String logicalKey) async {
    final encoded = await _storage.read(key: logicalKey);
    if (encoded == null || encoded.isEmpty) return null;
    return Uint8List.fromList(base64Decode(encoded));
  }

  @override
  Future<void> writeKey(String logicalKey, Uint8List material) =>
      _storage.write(key: logicalKey, value: base64Encode(material));

  @override
  Future<void> deleteKey(String logicalKey) =>
      _storage.delete(key: logicalKey);
}
