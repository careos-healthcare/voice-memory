import 'package:archiveme_mobile/features/early_archive/confirmed_repeat_thought_map_models.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter/foundation.dart';

/// Lightweight local metadata for Thought Map — section ids only, no transcript.
class ConfirmedRepeatThoughtMapStore {
  ConfirmedRepeatThoughtMapStore(this._prefs);

  static const prefsKey = 'confirmedRepeatThoughtMap_v1';

  final MobilePrefsStore _prefs;

  static String? _cachedLastMissingSection;
  static bool _loaded = false;

  static String? get cachedLastMissingSection => _cachedLastMissingSection;

  static ConfirmedRepeatThoughtMapStore instance() =>
      ConfirmedRepeatThoughtMapStore(AppServices.instance.prefs);

  static Future<void> ensureLoaded() async {
    if (_loaded || !AppServices.isInitialized) return;
    _cachedLastMissingSection = await instance().loadLastMissingSection();
    _loaded = true;
  }

  Future<String?> loadLastMissingSection() async {
    final raw = await _prefs.readMap(prefsKey);
    return raw?['lastMissingSection'] as String?;
  }

  Future<void> markMissingPieceTarget(ThoughtMapSectionId section) async {
    final id = section.name;
    _cachedLastMissingSection = id;
    _loaded = true;
    await _prefs.writeMap(prefsKey, {
      'lastMissingSection': id,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  static Future<void> resetPersistedState() async {
    _cachedLastMissingSection = null;
    _loaded = false;
    if (!AppServices.isInitialized) return;
    await AppServices.instance.prefs.writeMap(prefsKey, {});
  }

  @visibleForTesting
  static Future<void> resetForTest() => resetPersistedState();
}