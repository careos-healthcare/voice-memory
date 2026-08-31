import 'dart:typed_data';

import 'package:archiveme_crypto/src/key_material_store.dart';

/// In-memory [KeyMaterialStore] for package and unit tests.
final class MemoryKeyMaterialStore implements KeyMaterialStore {
  final Map<String, Uint8List> _keys = {};

  @override
  Future<Uint8List?> readKey(String logicalKey) async {
    final stored = _keys[logicalKey];
    if (stored == null) return null;
    return Uint8List.fromList(stored);
  }

  @override
  Future<void> writeKey(String logicalKey, Uint8List material) async {
    _keys[logicalKey] = Uint8List.fromList(material);
  }

  @override
  Future<void> deleteKey(String logicalKey) async {
    _keys.remove(logicalKey);
  }
}
