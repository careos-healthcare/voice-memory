import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Stable archive hash for cache keys (matches server canonical JSON).
String computeArchiveHashFromPack(Map<String, dynamic> pack) {
  final sorted = _sortKeys(pack);
  final canonical = jsonEncode(sorted);
  return sha256.convert(utf8.encode(canonical)).toString().substring(0, 32);
}

dynamic _sortKeys(dynamic value) {
  if (value == null || value is! Map && value is! List) return value;
  if (value is List) return value.map(_sortKeys).toList();
  final map = value as Map;
  final keys = map.keys.map((k) => k.toString()).toList()..sort();
  final out = <String, dynamic>{};
  for (final key in keys) {
    out[key] = _sortKeys(map[key]);
  }
  return out;
}

String synthesisCacheKey({
  required String userId,
  required String monthKey,
  required String archiveHash,
}) => '$userId|$monthKey|$archiveHash';
