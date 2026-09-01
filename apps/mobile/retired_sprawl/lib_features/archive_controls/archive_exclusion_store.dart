import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter/foundation.dart';

/// Local-only pattern evidence exclusions keyed by pattern + entry id.
class ArchiveExclusionStore {
  ArchiveExclusionStore(this._prefs);

  static const _prefsKey = 'archive_pattern_exclusions_v1';

  final MobilePrefsStore _prefs;

  static Set<String> _cached = {};
  static bool _loaded = false;

  static ArchiveExclusionStore instance() =>
      ArchiveExclusionStore(AppServices.instance.prefs);

  /// Loads persisted exclusions.
  ///
  /// [prefs] is the restore-reload path: [LocalBackupRestoreService]
  /// writes the backup into its own store, then must rehydrate from that
  /// handle. Do not call [AppServices.initialize] from here —
  /// `initializeEssential` is not re-entrant, and the live restore flow
  /// already refuses to run when services are down. A missing prefs
  /// source leaves [_loaded] false so a later load can still succeed.
  static Future<void> ensureLoaded({MobilePrefsStore? prefs}) async {
    if (_loaded) return;
    final resolved =
        prefs ??
        (AppServices.isInitialized ? AppServices.instance.prefs : null);
    if (resolved == null) return;
    _cached = await ArchiveExclusionStore(resolved).loadAll();
    _loaded = true;
  }

  static Set<String> get cached => Set<String>.unmodifiable(_cached);

  static String _storageKey({
    required String entryId,
    required String patternKey,
  }) => '${patternKey.trim()}|${entryId.trim()}';

  Future<Set<String>> loadAll() async {
    final raw = await _prefs.readJsonMap(_prefsKey);
    if (raw == null || raw.isEmpty) return {};
    final keysRaw = raw['exclusion_keys'];
    if (keysRaw is! List) return {};
    return keysRaw
        .whereType<String>()
        .map((key) => key.trim())
        .where((key) => key.contains('|') && key.isNotEmpty)
        .toSet();
  }

  static bool isExcluded({
    required String entryId,
    required String patternKey,
  }) {
    if (entryId.trim().isEmpty || patternKey.trim().isEmpty) return false;
    return _cached.contains(
      _storageKey(entryId: entryId, patternKey: patternKey),
    );
  }

  Future<void> exclude({
    required String entryId,
    required String patternKey,
  }) async {
    if (entryId.trim().isEmpty || patternKey.trim().isEmpty) return;
    _cached = {
      ..._cached,
      _storageKey(entryId: entryId, patternKey: patternKey),
    };
    _loaded = true;
    await _persist();
  }

  Future<void> _persist() async {
    await _prefs.writeJsonMap(_prefsKey, {
      'exclusion_keys': _cached.toList()..sort(),
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
