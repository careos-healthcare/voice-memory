import 'package:archiveme_mobile/features/memory_resurfacing/memory_resurfacing_models.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

/// Persists which entries were shown and aggregate resurfacing metrics.
class MemoryResurfacingStore {
  MemoryResurfacingStore(this._prefs);

  final MobilePrefsStore _prefs;
  static const _key = 'memoryResurfacing';

  Future<Map<String, dynamic>> _read() async =>
      await _prefs.readJsonMap(_key) ?? {};

  Future<void> _write(Map<String, dynamic> data) async {
    await _prefs.writeJsonMap(_key, data);
  }

  Future<Set<String>> resurfacedEntryIds() async {
    final raw = (await _read())['resurfacedEntryIds'];
    if (raw is! List) return {};
    return raw.map((e) => e.toString()).toSet();
  }

  Future<int> resurfacedCount() async =>
      ((await _read())['resurfacedCount'] as num?)?.toInt() ?? 0;

  Future<int> openedCount() async =>
      ((await _read())['openedCount'] as num?)?.toInt() ?? 0;

  Future<MemoryResurfacingStats> stats() async {
    return MemoryResurfacingStats(
      resurfacedCount: await resurfacedCount(),
      openedCount: await openedCount(),
    );
  }

  Future<void> markResurfaced(Iterable<String> entryIds) async {
    final data = await _read();
    final ids = await resurfacedEntryIds();
    var added = 0;
    for (final id in entryIds) {
      if (ids.add(id)) added++;
    }
    data['resurfacedEntryIds'] = ids.toList();
    data['resurfacedCount'] =
        ((data['resurfacedCount'] as num?)?.toInt() ?? 0) + added;
    await _write(data);
  }

  Future<void> markOpened(String entryId) async {
    final data = await _read();
    data['openedCount'] = ((data['openedCount'] as num?)?.toInt() ?? 0) + 1;
    data['lastOpenedEntryId'] = entryId;
    data['lastOpenedAt'] = DateTime.now().toUtc().toIso8601String();
    await _write(data);
  }
}