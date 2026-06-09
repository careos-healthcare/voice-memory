import '../../storage/mobile_prefs_store.dart';
import 'active_pattern_thread_model.dart';

class ActivePatternThreadStore {
  ActivePatternThreadStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _currentKey = 'activePatternThreadCurrent';
  static const _inactiveKey = 'activePatternThreadLatestInactive';
  static const _historyKey = 'activePatternThreadHistory';
  static const _historyMax = 10;

  Future<ActivePatternThread?> readCurrent() async {
    final raw = await _prefs.readMap(_currentKey);
    final thread = ActivePatternThread.fromJson(raw);
    if (thread == null) return null;
    if (thread.status == ActivePatternThreadStatus.paused) return null;
    return thread.isActive ? thread : null;
  }

  Future<ActivePatternThread?> readCurrentIncludingPaused() async {
    final raw = await _prefs.readMap(_currentKey);
    return ActivePatternThread.fromJson(raw);
  }

  Future<ActivePatternThread?> readLatestInactive() async {
    final raw = await _prefs.readMap(_inactiveKey);
    return ActivePatternThread.fromJson(raw);
  }

  Future<List<ActivePatternThread>> readHistory() async {
    final raw = await _prefs.readMap(_historyKey);
    if (raw == null || raw.isEmpty) return const [];
    final list = raw['items'];
    if (list is! List) return const [];
    return list
        .map((e) => ActivePatternThread.fromJson(
              e is Map<String, dynamic>
                  ? e
                  : Map<String, dynamic>.from(e as Map),
            ))
        .whereType<ActivePatternThread>()
        .toList();
  }

  Future<void> writeCurrent(ActivePatternThread? thread) async {
    if (thread == null) {
      await _prefs.writeMap(_currentKey, {});
      return;
    }
    await _prefs.writeMap(_currentKey, thread.toJson());
  }

  Future<void> writeLatestInactive(ActivePatternThread? thread) async {
    if (thread == null) {
      await _prefs.writeMap(_inactiveKey, {});
      return;
    }
    await _prefs.writeMap(_inactiveKey, thread.toJson());
  }

  Future<void> appendHistory(ActivePatternThread thread) async {
    final history = await readHistory();
    final next = [
      thread,
      ...history.where((h) => h.id != thread.id),
    ].take(_historyMax).toList();
    await _prefs.writeMap(_historyKey, {
      'items': next.map((t) => t.toJson()).toList(),
    });
  }
}
