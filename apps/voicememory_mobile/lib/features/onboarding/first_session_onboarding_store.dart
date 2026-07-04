import 'package:flutter/foundation.dart';

import '../../services/app_services.dart';
import '../../storage/mobile_prefs_store.dart';

/// Local dismiss state for first-session onboarding — no fake saves.
class FirstSessionOnboardingStore {
  FirstSessionOnboardingStore(this._prefs);

  static const prefsKey = 'first_session_onboarding_dismissed_v1';

  final MobilePrefsStore _prefs;

  static bool _dismissed = false;
  static bool _loaded = false;

  static bool get isDismissed => _dismissed;

  static FirstSessionOnboardingStore instance() =>
      FirstSessionOnboardingStore(AppServices.instance.prefs);

  static Future<void> ensureLoaded() async {
    if (_loaded || !AppServices.isInitialized) return;
    _dismissed = await instance()._readDismissed();
    _loaded = true;
  }

  static bool shouldShow({
    required bool loaded,
    required int entryCount,
    required bool isReady,
    required bool isPostSave,
  }) =>
      loaded &&
      isReady &&
      !isPostSave &&
      entryCount == 0 &&
      !_dismissed;

  Future<bool> _readDismissed() async {
    final raw = await _prefs.readMap(prefsKey);
    return raw?['dismissed'] == true;
  }

  Future<void> markDismissed() async {
    _dismissed = true;
    _loaded = true;
    try {
      await _prefs.writeMap(prefsKey, {
        'dismissed': true,
        'dismissedAt': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {
      // Persistence failures never block capture — card stays hidden this session.
    }
  }

  @visibleForTesting
  static Future<void> resetForTest() async {
    _dismissed = false;
    _loaded = true;
    if (AppServices.isInitialized) {
      try {
        await AppServices.instance.prefs.writeMap(prefsKey, {'dismissed': false});
      } catch (_) {}
    }
  }
}
