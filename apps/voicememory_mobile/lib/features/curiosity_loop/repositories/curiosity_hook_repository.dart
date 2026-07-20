import 'package:flutter/foundation.dart';

import '../../../services/app_services.dart';
import '../../../storage/mobile_prefs_store.dart';
import '../models/curiosity_hook.dart';

/// Persistence boundary for post-save curiosity hooks.
abstract interface class CuriosityHookRepository {
  Future<void> saveHook(CuriosityHook hook);

  Future<CuriosityHook?> fetchLatestUnconsumed();

  Future<CuriosityHook?> fetchById(String hookId);

  Future<void> markConsumed(String hookId);

  Future<List<CuriosityHook>> loadAll();

  Future<List<CuriosityHookType>> recentHookTypes({int limit = 4});
}

/// Local-only curiosity hook store — entry ids and hook metadata only.
class LocalCuriosityHookRepository implements CuriosityHookRepository {
  LocalCuriosityHookRepository(this._prefs);

  static const prefsKey = 'curiosityHooks_v1';

  final MobilePrefsStore _prefs;

  static List<CuriosityHook> _cached = const [];
  static bool _loaded = false;

  static List<CuriosityHook> get cached => List.unmodifiable(_cached);

  static LocalCuriosityHookRepository instance() =>
      LocalCuriosityHookRepository(AppServices.instance.prefs);

  static LocalCuriosityHookRepository forPrefs(MobilePrefsStore prefs) =>
      LocalCuriosityHookRepository(prefs);

  static Future<void> ensureLoaded() async {
    if (_loaded || !AppServices.isInitialized) return;
    _cached = await instance().loadAll();
    _loaded = true;
  }

  @override
  Future<List<CuriosityHook>> loadAll() async {
    final raw = await _prefs.readJsonMap(prefsKey);
    if (raw == null || raw.isEmpty) return const [];
    final hooksRaw = raw['hooks'];
    if (hooksRaw is! List) return const [];
    final hooks = hooksRaw
        .whereType<Map>()
        .map((entry) => CuriosityHook.fromJson(Map<String, dynamic>.from(entry)))
        .whereType<CuriosityHook>()
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _cached = hooks;
    _loaded = true;
    return hooks;
  }

  @override
  Future<void> saveHook(CuriosityHook hook) async {
    final hooks = [
      for (final existing in await loadAll())
        if (existing.id != hook.id) existing,
      hook,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await _persist(hooks);
  }

  @override
  Future<CuriosityHook?> fetchLatestUnconsumed() async {
    final hooks = await loadAll();
    for (final hook in hooks) {
      if (!hook.isConsumed) return hook;
    }
    return null;
  }

  @override
  Future<CuriosityHook?> fetchById(String hookId) async {
    final trimmed = hookId.trim();
    if (trimmed.isEmpty) return null;
    final hooks = await loadAll();
    for (final hook in hooks) {
      if (hook.id == trimmed) return hook;
    }
    return null;
  }

  @override
  Future<void> markConsumed(String hookId) async {
    if (hookId.isEmpty) return;
    final hooks = await loadAll();
    final index = hooks.indexWhere((hook) => hook.id == hookId);
    if (index < 0) return;
    final updated = hooks[index].copyWith(isConsumed: true);
    final next = [
      for (var i = 0; i < hooks.length; i++)
        if (i == index) updated else hooks[i],
    ];
    await _persist(next);
  }

  Future<void> _persist(List<CuriosityHook> hooks) async {
    await _prefs.writeJsonMap(prefsKey, {
      'hooks': hooks.map((hook) => hook.toJson()).toList(),
    });
    _cached = hooks;
    _loaded = true;
  }

  /// Recent hook types for engine de-duplication — newest first.
  @override
  Future<List<CuriosityHookType>> recentHookTypes({int limit = 4}) async {
    final hooks = await loadAll();
    return hooks.take(limit).map((hook) => hook.hookType).toList();
  }

  @visibleForTesting
  static Future<void> resetForTest(MobilePrefsStore? prefs) async {
    _cached = const [];
    _loaded = false;
    if (prefs == null) return;
    await prefs.writeJsonMap(prefsKey, {});
  }
}
