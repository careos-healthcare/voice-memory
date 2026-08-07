import 'package:flutter/foundation.dart';

import '../../services/app_services.dart';
import '../../storage/mobile_prefs_store.dart';
import 'pattern_changed_engine.dart';

/// Local dismiss state for pattern-changed wins — keyed by entry and change type.
class PatternChangedStore {
  PatternChangedStore(this._prefs);

  static const _prefsKey = 'patternChangedDismissed_v1';

  final MobilePrefsStore _prefs;

  static Set<String> _dismissedKeys = {};
  static bool _loaded = false;

  static PatternChangedStore instance() =>
      PatternChangedStore(AppServices.instance.prefs);

  static Future<void> ensureLoaded() async {
    if (_loaded || !AppServices.isInitialized) return;
    _dismissedKeys = await instance().loadDismissedKeys();
    _loaded = true;
  }

  static bool isDismissed({
    required String entryId,
    required PatternChangedType type,
  }) => _dismissedKeys.contains(_key(entryId: entryId, type: type));

  static String dismissKey({
    required String entryId,
    required PatternChangedType type,
  }) => _key(entryId: entryId, type: type);

  Future<Set<String>> loadDismissedKeys() async {
    final raw = await _prefs.readJsonMap(_prefsKey);
    if (raw == null) return {};
    final keys = raw['keys'];
    if (keys is! List) return {};
    return keys.whereType<String>().toSet();
  }

  Future<void> dismiss({
    required String entryId,
    required PatternChangedType type,
  }) async {
    final next = {..._dismissedKeys, _key(entryId: entryId, type: type)};
    await _prefs.writeJsonMap(_prefsKey, {'keys': next.toList()});
    _dismissedKeys = next;
    _loaded = true;
  }

  static String _key({
    required String entryId,
    required PatternChangedType type,
  }) => '$entryId:${type.name}';

  @visibleForTesting
  static Future<void> resetForTest() async {
    _dismissedKeys = {};
    _loaded = false;
    if (!AppServices.isInitialized) return;
    await AppServices.instance.prefs.writeJsonMap(_prefsKey, {});
  }
}
