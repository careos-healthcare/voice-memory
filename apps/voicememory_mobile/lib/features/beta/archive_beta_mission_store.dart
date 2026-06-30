import 'package:flutter/foundation.dart';

import '../../services/app_services.dart';
import '../../storage/mobile_prefs_store.dart';

/// Local dismiss state for the beta mission card — never uploads content.
class ArchiveBetaMissionStore {
  ArchiveBetaMissionStore(this._prefs);

  static const prefsKey = 'archiveBetaMissionDismissed_v1';

  final MobilePrefsStore _prefs;

  static bool _cachedDismissed = false;
  static bool _loaded = false;

  static bool get cachedDismissed => _cachedDismissed;

  static ArchiveBetaMissionStore instance() =>
      ArchiveBetaMissionStore(AppServices.instance.prefs);

  static Future<void> ensureLoaded() async {
    if (_loaded || !AppServices.isInitialized) return;
    _cachedDismissed = await instance().loadDismissed();
    _loaded = true;
  }

  Future<bool> loadDismissed() async {
    final raw = await _prefs.readMap(prefsKey);
    return raw?['dismissed'] == true;
  }

  Future<void> dismiss() async {
    _cachedDismissed = true;
    _loaded = true;
    await _prefs.writeMap(prefsKey, {
      'dismissed': true,
      'dismissedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  @visibleForTesting
  static Future<void> resetForTest() async {
    _cachedDismissed = false;
    _loaded = false;
    if (!AppServices.isInitialized) return;
    await AppServices.instance.prefs.writeMap(prefsKey, {});
  }
}
