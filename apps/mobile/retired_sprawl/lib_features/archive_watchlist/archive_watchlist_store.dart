import 'package:archiveme_mobile/features/archive_watchlist/archive_watchlist_models.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

/// Local-only persistence for archive watch themes — separate from journal.
class ArchiveWatchlistStore {
  ArchiveWatchlistStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const stateKey = 'archiveWatchlistItems';

  Future<List<ArchiveWatchlistItem>> loadItems() async {
    final raw = await _prefs.readJsonMap(stateKey);
    if (raw == null || raw.isEmpty) return const [];
    final itemsRaw = raw['items'];
    if (itemsRaw is! List) return const [];
    return itemsRaw
        .whereType<Map>()
        .map((e) => ArchiveWatchlistItem.fromJson(Map<String, dynamic>.from(e)))
        .where((item) => item.isValid)
        .toList();
  }

  Future<void> saveItems(List<ArchiveWatchlistItem> items) async {
    await _prefs.writeJsonMap(stateKey, {
      'items': items.map((item) => item.toJson()).toList(),
    });
  }

  Future<void> addItem(ArchiveWatchlistItem item) async {
    if (!item.isValid) return;
    final items = [...await loadItems()];
    if (items.any((existing) => existing.id == item.id)) return;
    items.add(item);
    await saveItems(items);
  }

  Future<void> removeItem(String id) async {
    final items = [...await loadItems()];
    items.removeWhere((item) => item.id == id);
    await saveItems(items);
  }

  Future<void> clear() async {
    await _prefs.writeJsonMap(stateKey, {});
  }

  static Future<ArchiveWatchlistStore> open(String prefsPath) async {
    final prefs = await MobilePrefsStore.open(prefsPath);
    return ArchiveWatchlistStore(prefs);
  }

  static ArchiveWatchlistStore fromAppPrefs(MobilePrefsStore prefs) =>
      ArchiveWatchlistStore(prefs);
}