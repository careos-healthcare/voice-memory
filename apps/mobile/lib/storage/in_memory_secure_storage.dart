import 'dart:convert';
import 'dart:typed_data';

import 'package:archiveme_crypto/archiveme_crypto.dart';
import 'package:archiveme_mobile/storage/secure_storage.dart';

/// In-memory [SecureStorageService] for widget/unit tests — no platform channels.
class InMemorySecureStorageService extends SecureStorageService {
  InMemorySecureStorageService();

  final Map<String, String> _data = {};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async {
    _data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _data.remove(key);
  }

  @override
  Future<void> clearAll() async {
    _data.clear();
  }
}

/// In-memory unprefixed [KeyMaterialStore] — physical key == logical key.
///
/// Mirrors [UnprefixedFlutterSecureStorageKeyMaterialStore] encoding
/// (`base64Encode` at the logical key, no `vm_flutter_` prefix) so goldens
/// can lock vault keychain placement without platform channels.
class InMemoryUnprefixedKeyMaterialStore implements KeyMaterialStore {
  final Map<String, String> physical = {};

  @override
  Future<Uint8List?> readKey(String logicalKey) async {
    final stored = physical[logicalKey];
    if (stored == null || stored.isEmpty) return null;
    return Uint8List.fromList(base64Decode(stored));
  }

  @override
  Future<void> writeKey(String logicalKey, Uint8List material) async {
    physical[logicalKey] = base64Encode(material);
  }

  @override
  Future<void> deleteKey(String logicalKey) async {
    physical.remove(logicalKey);
  }
}
