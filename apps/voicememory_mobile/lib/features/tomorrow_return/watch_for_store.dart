import '../../storage/mobile_prefs_store.dart';
import 'watch_for_model.dart';

class WatchForStore {
  WatchForStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _pendingKey = 'watchForPending';
  static const _completedKey = 'watchForLatestCompleted';
  static const _historyKey = 'watchForHistory';
  static const _historyMax = 14;

  Future<WatchForItem?> readPending() async {
    final raw = await _prefs.readMap(_pendingKey);
    final item = WatchForItem.fromJson(raw);
    if (item == null || item.status != WatchForStatus.pending) return null;
    return item;
  }

  Future<WatchForItem?> readLatestCompleted() async {
    final raw = await _prefs.readMap(_completedKey);
    return WatchForItem.fromJson(raw);
  }

  Future<List<WatchForItem>> readHistory() async {
    final raw = await _prefs.readMap(_historyKey);
    if (raw == null || raw.isEmpty) return const [];
    final list = raw['items'];
    if (list is! List) return const [];
    return list
        .map(
          (e) => WatchForItem.fromJson(
            e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map),
          ),
        )
        .whereType<WatchForItem>()
        .toList();
  }

  Future<void> writePending(WatchForItem? item) async {
    if (item == null) {
      await _prefs.writeMap(_pendingKey, {});
      return;
    }
    await _prefs.writeMap(_pendingKey, item.toJson());
  }

  Future<void> writeLatestCompleted(WatchForItem? item) async {
    if (item == null) {
      await _prefs.writeMap(_completedKey, {});
      return;
    }
    await _prefs.writeMap(_completedKey, item.toJson());
  }

  Future<void> appendHistory(WatchForItem item) async {
    final history = await readHistory();
    final next = [
      item,
      ...history.where((h) => h.id != item.id),
    ].take(_historyMax).toList();
    await _prefs.writeMap(_historyKey, {
      'items': next.map((w) => w.toJson()).toList(),
    });
  }
}
