import 'dart:async';

import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

/// Local-only suppression for surfaced archive insights.
abstract final class MemoryTransparencyStore {
  MemoryTransparencyStore._();

  static const prefsKey = 'memory_transparency_suppressed_v1';

  static final Set<String> _suppressed = <String>{};
  static bool _loaded = false;

  static Future<void> ensureLoaded() async {
    if (_loaded) return;
    if (!AppServices.isInitialized) {
      _loaded = true;
      return;
    }
    final raw = await AppServices.instance.prefs.readJsonMap(prefsKey);
    final ids = raw?['suppressedIds'];
    if (ids is List) {
      _suppressed
        ..clear()
        ..addAll(ids.whereType<String>());
    }
    _loaded = true;
  }

  static bool isSuppressed(String insightId) => _suppressed.contains(insightId);

  static Future<void> suppress(String insightId) async {
    _suppressed.add(insightId);
    await _persist();
  }

  static Future<void> unsuppress(String insightId) async {
    _suppressed.remove(insightId);
    await _persist();
  }

  static Set<String> suppressedIds() => Set<String>.unmodifiable(_suppressed);

  static Future<void> _persist() async {
    if (!AppServices.isInitialized) return;
    await AppServices.instance.prefs.writeJsonMap(prefsKey, {
      'suppressedIds': _suppressed.toList(),
    });
  }

  static Future<void> resetForTest() async {
    _suppressed.clear();
    _loaded = false;
    if (AppServices.isInitialized) {
      await AppServices.instance.prefs.writeJsonMap(prefsKey, {});
    }
  }
}

/// Test helper when AppServices is not bootstrapped.
class MemoryTransparencyStoreForTest {
  MemoryTransparencyStoreForTest(this._prefs);

  final MobilePrefsStore _prefs;

  Future<void> suppress(String insightId) async {
    final raw = await _prefs.readJsonMap(MemoryTransparencyStore.prefsKey) ?? {};
    final ids = {...?((raw['suppressedIds'] as List?)?.whereType<String>())};
    ids.add(insightId);
    await _prefs.writeJsonMap(MemoryTransparencyStore.prefsKey, {
      'suppressedIds': ids.toList(),
    });
  }

  Future<Set<String>> readSuppressed() async {
    final raw = await _prefs.readJsonMap(MemoryTransparencyStore.prefsKey);
    final ids = raw?['suppressedIds'];
    if (ids is! List) return {};
    return ids.whereType<String>().toSet();
  }
}
