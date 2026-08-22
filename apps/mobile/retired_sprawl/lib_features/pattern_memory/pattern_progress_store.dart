import 'package:archiveme_mobile/features/pattern_memory/pattern_progress_model.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

/// Persists the latest pattern progress moment plus a capped history.
class PatternProgressStore {
  PatternProgressStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _latestKey = 'patternProgressLatest';
  static const _historyKey = 'patternProgressHistory';
  static const _historyMax = 20;

  Future<PatternProgressMoment?> loadLatest() async {
    final raw = await _prefs.readMap(_latestKey);
    return PatternProgressMoment.fromJson(raw);
  }

  Future<void> saveLatest(PatternProgressMoment moment) async {
    await _prefs.writeMap(_latestKey, moment.toJson());
  }

  Future<List<PatternProgressMoment>> loadHistory({int limit = 20}) async {
    final raw = await _prefs.readMap(_historyKey);
    if (raw == null || raw.isEmpty) return const [];
    final list = raw['items'];
    if (list is! List) return const [];
    final moments = list
        .map(
          (e) => PatternProgressMoment.fromJson(
            e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map),
          ),
        )
        .whereType<PatternProgressMoment>()
        .toList();
    return moments.take(limit).toList();
  }

  Future<void> appendHistory(PatternProgressMoment moment) async {
    final history = await loadHistory();
    final next = [
      moment,
      ...history.where((h) => h.id != moment.id),
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