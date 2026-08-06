import 'package:flutter/foundation.dart';

import '../../services/app_services.dart';
import '../../storage/mobile_prefs_store.dart';

/// Local-only importance markers keyed by entry id.
class EntryImportanceStore {
  EntryImportanceStore(this._prefs);

  static const _prefsKey = 'entry_importance_markers_v1';

  final MobilePrefsStore _prefs;

  static Set<String> _cached = {};
  static bool _loaded = false;

  static EntryImportanceStore instance() =>
      EntryImportanceStore(AppServices.instance.prefs);

  static Future<void> ensureLoaded() async {
    if (_loaded || !AppServices.isInitialized) return;
    _cached = await instance().loadAll();
    _loaded = true;
  }

  static Set<String> get cached => Set<String>.unmodifiable(_cached);

  Future<Set<String>> loadAll() async {
    final raw = await _prefs.readJsonMap(_prefsKey);
    if (raw == null || raw.isEmpty) return {};
    final idsRaw = raw['entry_ids'];
    if (idsRaw is! List) return {};
    return idsRaw
        .whereType<String>()
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  static bool isImportant(String entryId) => _cached.contains(entryId);

  Future<void> mark(String entryId) async {
    if (entryId.trim().isEmpty) return;
    _cached = {..._cached, entryId};
    _loaded = true;
    await _persist();
  }

  Future<void> unmark(String entryId) async {
    if (entryId.trim().isEmpty) return;
    _cached = {..._cached}..remove(entryId);
    _loaded = true;
    await _persist();
  }

  Future<void> _persist() async {
    await _prefs.writeJsonMap(_prefsKey, {
      'entry_ids': _cached.toList()..sort(),
    });
  }

  static Future<void> clearAll() async {
    _cached = {};
    _loaded = false;
    if (!AppServices.isInitialized) return;
    await AppServices.instance.prefs.writeJsonMap(_prefsKey, {});
  }

  static void invalidateAfterRestore() => invalidateCache();

  @visibleForTesting
  static void invalidateCache() {
    _cached = {};
    _loaded = false;
  }

  static Future<void> resetForTest() async {
    await clearAll();
  }
}
