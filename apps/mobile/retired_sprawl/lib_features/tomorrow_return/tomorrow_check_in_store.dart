import 'package:archiveme_mobile/features/tomorrow_return/tomorrow_check_in_model.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

class TomorrowCheckInStore {
  TomorrowCheckInStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _activeKey = 'tomorrowCheckInActive';
  static const _historyKey = 'tomorrowCheckInHistory';
  static const _historyMax = 100;

  Future<void> save(TomorrowCheckIn checkIn) async {
    await _prefs.writeMap(_activeKey, checkIn.toJson());
  }

  Future<TomorrowCheckIn?> loadActive() async {
    final raw = await _prefs.readMap(_activeKey);
    return TomorrowCheckIn.fromJson(raw);
  }

  Future<TomorrowCheckIn?> loadDueToday({DateTime? now}) async {
    final active = await loadActive();
    if (active == null || active.isCompleted) return null;
    final today = tomorrowCheckInDateKey(now ?? DateTime.now());
    if (active.targetDate == today) return active;
    return null;
  }

  Future<TomorrowCheckIn?> selectOption({
    required String checkInId,
    required String optionId,
  }) async {
    final active = await loadActive();
    if (active == null || active.id != checkInId) return null;
    final updated = active.copyWith(selectedOptionId: optionId);
    await save(updated);
    return updated;
  }

  Future<TomorrowCheckIn?> markCompleted(
    String checkInId, {
    DateTime? now,
  }) async {
    final active = await loadActive();
    if (active == null || active.id != checkInId) return null;
    final clock = now ?? DateTime.now();
    final completed = active.copyWith(completedAt: clock);
    await _appendHistory(completed);
    await _prefs.writeMap(_activeKey, {});
    return completed;
  }

  Future<void> clearActive() async {
    await _prefs.writeMap(_activeKey, {});
  }

  Future<void> clear() async {
    await clearActive();
    await _prefs.writeMap(_historyKey, {'items': []});
  }

  /// Overdue check-in removed from active without completing.
  Future<void> archiveOverdue(TomorrowCheckIn checkIn) async {
    await _appendHistory(checkIn);
    await clearActive();
  }

  Future<List<TomorrowCheckIn>> loadHistory({int limit = 20}) async {
    final raw = await _prefs.readMap(_historyKey);
    if (raw == null || raw.isEmpty) return const [];
    final list = raw['items'];
    if (list is! List) return const [];
    return list
        .map(
          (e) => TomorrowCheckIn.fromJson(
            e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map),
          ),
        )
        .whereType<TomorrowCheckIn>()
        .take(limit)
        .toList();
  }

  /// Missed: overdue, not completed, still in history.
  Future<TomorrowCheckIn?> loadRecentMissed({DateTime? now}) async {
    final clock = now ?? DateTime.now();
    final today = tomorrowCheckInDateKey(clock);
    final history = await loadHistory();
    for (final item in history) {
      if (item.isCompleted) continue;
      if (item.targetDate.compareTo(today) >= 0) continue;
      return item;
    }
    return null;
  }

  Future<TomorrowCheckIn?> loadRecentlyCompleted({
    Duration within = const Duration(days: 2),
  }) async {
    final history = await loadHistory(limit: 5);
    final cutoff = DateTime.now().subtract(within);
    for (final item in history) {
      final at = item.completedAt;
      if (at != null && !at.isBefore(cutoff)) return item;
    }
    return null;
  }

  Future<void> _appendHistory(TomorrowCheckIn item) async {
    final history = await loadHistory(limit: _historyMax);
    final next = [
      item,
      ...history.where((h) => h.id != item.id),
    ].take(_historyMax).toList();
    await _prefs.writeMap(_historyKey, {
      'items': next.map((c) => c.toJson()).toList(),
    });
  }
}