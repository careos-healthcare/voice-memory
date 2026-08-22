import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

/// Persists first-pattern correction events for activation summaries.
class FirstPatternCorrectionStore {
  FirstPatternCorrectionStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _key = 'activation_first_pattern_corrections';

  Future<List<Map<String, dynamic>>> readAll() async {
    final map = await _prefs.readMap(_key);
    final raw = map?['items'];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .toList();
  }

  Future<void> record({
    required String originalTitle,
    required String selectedTitle,
    required double confidenceScore,
  }) async {
    final items = await readAll();
    items.add({
      'at': DateTime.now().toUtc().toIso8601String(),
      'originalTitle': originalTitle,
      'selectedTitle': selectedTitle,
      'confidenceScore': confidenceScore,
    });
    await _prefs.writeMap(_key, {'items': items});
  }

  Future<int> correctionCount() async => (await readAll()).length;
}