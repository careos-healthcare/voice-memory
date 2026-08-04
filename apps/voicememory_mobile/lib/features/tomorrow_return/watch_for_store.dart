import '../../storage/mobile_prefs_store.dart';
import 'watch_for_model.dart';

class WatchForStore {
  WatchForStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _pendingKey = 'watchForPending';
  static const _activeKey = 'watchForActive';
  static const _completedKey = 'watchForLatestCompleted';
  static const _historyKey = 'watchForHistory';
  static const _historyMax = 14;

  Future<WatchForItem?> readPending() async {
    final raw = await _prefs.readMap(_pendingKey);
    final item = WatchForItem.fromJson(raw);
    if (item == null || item.status != WatchForStatus.pending) return null;
    return item;
  }

  Future<List<WatchForItem>> readActive() async {
    final raw = await _prefs.readMap(_activeKey);
    final items = raw?['items'];
    if (items is List) {
      final active = items
          .map(
            (item) => WatchForItem.fromJson(
              item is Map<String, dynamic>
                  ? item
                  : Map<String, dynamic>.from(item as Map),
            ),
          )
          .whereType<WatchForItem>()
          .where((item) => item.status == WatchForStatus.pending)
          .toList();
      if (active.isNotEmpty) return active;
    }

    // Migrate the original single-target representation lazily.
    final pending = await readPending();
    return pending == null ? const [] : [pending];
  }

  Future<WatchForAddResult> addActive(
    WatchForItem item, {
    required bool isPro,
  }) async {
    final active = await readActive();
    if (active.any((existing) => existing.id == item.id)) {
      return WatchForAddResult.added;
    }
    if (!isPro && active.isNotEmpty) {
      return WatchForAddResult.requiresPro;
    }

    final next = [...active, item];
    await _writeActive(next);
    if (active.isEmpty) {
      await _prefs.writeMap(_pendingKey, item.toJson());
    }
    return WatchForAddResult.added;
  }

  Future<void> removeActive(String id) async {
    final active = await readActive();
    final next = active.where((item) => item.id != id).toList();
    await _writeActive(next);
    final current = await readPending();
    if (current?.id == id) {
      if (next.isEmpty) {
        await _prefs.writeMap(_pendingKey, {});
      } else {
        await _prefs.writeMap(_pendingKey, next.first.toJson());
      }
    }
  }

  Future<void> updateActive(WatchForItem item) async {
    final active = await readActive();
    if (!active.any((existing) => existing.id == item.id)) return;
    final next = [
      for (final existing in active)
        if (existing.id == item.id) item else existing,
    ];
    await _writeActive(next);
    final current = await readPending();
    if (current?.id == item.id) {
      await _prefs.writeMap(_pendingKey, item.toJson());
    }
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
      await _writeActive(const []);
      return;
    }
    await _prefs.writeMap(_pendingKey, item.toJson());
    await _writeActive([item]);
  }

  Future<void> _writeActive(List<WatchForItem> items) {
    return _prefs.writeMap(_activeKey, {
      'items': items.map((item) => item.toJson()).toList(),
    });
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

enum WatchForAddResult { added, requiresPro }
