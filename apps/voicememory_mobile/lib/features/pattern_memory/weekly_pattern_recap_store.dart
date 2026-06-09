import '../../storage/mobile_prefs_store.dart';
import 'weekly_pattern_recap_model.dart';

/// Persists the latest weekly recap plus a capped, de-duplicated history.
class WeeklyPatternRecapStore {
  WeeklyPatternRecapStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _latestKey = 'weeklyPatternRecapLatest';
  static const _historyKey = 'weeklyPatternRecapHistory';
  static const _historyMax = 20;

  Future<WeeklyPatternRecap?> loadLatest() async {
    final raw = await _prefs.readMap(_latestKey);
    return WeeklyPatternRecap.fromJson(raw);
  }

  Future<void> saveLatest(WeeklyPatternRecap recap) async {
    await _prefs.writeMap(_latestKey, recap.toJson());
  }

  Future<List<WeeklyPatternRecap>> loadHistory({int limit = 20}) async {
    final raw = await _prefs.readMap(_historyKey);
    if (raw == null || raw.isEmpty) return const [];
    final list = raw['items'];
    if (list is! List) return const [];
    final recaps = list
        .map((e) => WeeklyPatternRecap.fromJson(
              e is Map<String, dynamic>
                  ? e
                  : Map<String, dynamic>.from(e as Map),
            ))
        .whereType<WeeklyPatternRecap>()
        .toList();
    return recaps.take(limit).toList();
  }

  Future<void> appendHistory(WeeklyPatternRecap recap) async {
    final history = await loadHistory(limit: _historyMax);
    final next = [
      recap,
      // De-duplicate by memory + week + type (encoded in the recap id).
      ...history.where((h) => h.id != recap.id),
    ].take(_historyMax).toList();
    await _prefs.writeMap(_historyKey, {
      'items': next.map((m) => m.toJson()).toList(),
    });
  }

  Future<void> clear() async {
    await _prefs.writeMap(_latestKey, {});
    await _prefs.writeMap(_historyKey, {'items': []});
  }
}
