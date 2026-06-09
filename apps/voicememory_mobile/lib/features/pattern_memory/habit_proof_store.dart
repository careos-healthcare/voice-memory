import '../../storage/mobile_prefs_store.dart';
import 'habit_proof_model.dart';

/// Persists the latest habit proof moment plus a capped history.
class HabitProofStore {
  HabitProofStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _latestKey = 'habitProofLatest';
  static const _historyKey = 'habitProofHistory';
  static const _historyMax = 20;

  Future<HabitProofMoment?> loadLatest() async {
    final raw = await _prefs.readMap(_latestKey);
    return HabitProofMoment.fromJson(raw);
  }

  Future<void> saveLatest(HabitProofMoment moment) async {
    await _prefs.writeMap(_latestKey, moment.toJson());
  }

  Future<List<HabitProofMoment>> loadHistory({int limit = 20}) async {
    final raw = await _prefs.readMap(_historyKey);
    if (raw == null || raw.isEmpty) return const [];
    final list = raw['items'];
    if (list is! List) return const [];
    final moments = list
        .map((e) => HabitProofMoment.fromJson(
              e is Map<String, dynamic>
                  ? e
                  : Map<String, dynamic>.from(e as Map),
            ))
        .whereType<HabitProofMoment>()
        .toList();
    return moments.take(limit).toList();
  }

  Future<void> appendHistory(HabitProofMoment moment) async {
    final history = await loadHistory(limit: _historyMax);
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
