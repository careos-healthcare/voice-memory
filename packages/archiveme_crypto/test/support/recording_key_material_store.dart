import 'dart:typed_data';

import 'package:archiveme_crypto/archiveme_crypto.dart';

/// Host-side [KeyMaterialStore] for package tests.
///
/// Records every call so tests can assert the interface contract without
/// depending on [MemoryKeyMaterialStore] as both subject and double.
class RecordingKeyMaterialStore implements KeyMaterialStore {
  final Map<String, Uint8List> _keys = {};
  final List<String> reads = [];
  final List<String> writes = [];
  final List<String> deletes = [];

  Map<String, Uint8List> get snapshot => {
    for (final entry in _keys.entries)
      entry.key: Uint8List.fromList(entry.value),
  };

  @override
  Future<Uint8List?> readKey(String logicalKey) async {
    reads.add(logicalKey);
    final stored = _keys[logicalKey];
    if (stored == null) return null;
    return Uint8List.fromList(stored);
  }

  @override
  Future<void> writeKey(String logicalKey, Uint8List material) async {
    writes.add(logicalKey);
    _keys[logicalKey] = Uint8List.fromList(material);
  }

  @override
  Future<void> deleteKey(String logicalKey) async {
    deletes.add(logicalKey);
    _keys.remove(logicalKey);
  }
}

Uint8List freshKeyBytes({int fill = 0x5e}) {
  return Uint8List.fromList(List<int>.filled(32, fill));
}
