import '../../storage/mobile_prefs_store.dart';
import 'pattern_next_action_model.dart';

/// Persists the latest next action plus a capped history.
class PatternNextActionStore {
  PatternNextActionStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _latestKey = 'patternNextActionLatest';
  static const _historyKey = 'patternNextActionHistory';
  static const _historyMax = 20;

  Future<PatternNextAction?> loadLatest() async {
    final raw = await _prefs.readMap(_latestKey);
    return PatternNextAction.fromJson(raw);
  }

  Future<void> saveLatest(PatternNextAction action) async {
    await _prefs.writeMap(_latestKey, action.toJson());
  }

  Future<List<PatternNextAction>> loadHistory({int limit = 20}) async {
    final raw = await _prefs.readMap(_historyKey);
    if (raw == null || raw.isEmpty) return const [];
    final list = raw['items'];
    if (list is! List) return const [];
    final actions = list
        .map((e) => PatternNextAction.fromJson(
              e is Map<String, dynamic>
                  ? e
                  : Map<String, dynamic>.from(e as Map),
            ))
        .whereType<PatternNextAction>()
        .toList();
    return actions.take(limit).toList();
  }

  Future<void> appendHistory(PatternNextAction action) async {
    final history = await loadHistory(limit: _historyMax);
    final next = [
      action,
      ...history.where((h) => h.id != action.id),
    ].take(_historyMax).toList();
    await _prefs.writeMap(_historyKey, {
      'items': next.map((a) => a.toJson()).toList(),
    });
  }

  Future<void> clear() async {
    await _prefs.writeMap(_latestKey, {});
    await _prefs.writeMap(_historyKey, {'items': []});
  }
}
