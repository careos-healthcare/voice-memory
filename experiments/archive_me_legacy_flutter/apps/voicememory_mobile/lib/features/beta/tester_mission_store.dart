import 'package:flutter/foundation.dart';

import '../../services/app_services.dart';
import '../../storage/mobile_prefs_store.dart';

/// Local dismiss state for the tester mission card — session or day only.
class TesterMissionStore {
  TesterMissionStore(this._prefs);

  static const prefsKey = 'archiveTesterMissionDismiss_v1';

  final MobilePrefsStore _prefs;

  static bool _sessionDismissed = false;
  static String? _dismissedUntilDay;
  static bool _loaded = false;

  static bool get sessionDismissed => _sessionDismissed;

  static String? get dismissedUntilDay => _dismissedUntilDay;

  static bool get isDismissed {
    if (_sessionDismissed) return true;
    final day = _dismissedUntilDay;
    if (day == null || day.isEmpty) return false;
    return day == _todayUtc();
  }

  static TesterMissionStore instance() =>
      TesterMissionStore(AppServices.instance.prefs);

  static Future<void> ensureLoaded() async {
    if (_loaded || !AppServices.isInitialized) return;
    final record = await instance().loadDismissDay();
    _dismissedUntilDay = record;
    _loaded = true;
  }

  Future<String?> loadDismissDay() async {
    final raw = await _prefs.readMap(prefsKey);
    final day = raw?['dismissedUntilDay'];
    return day is String && day.isNotEmpty ? day : null;
  }

  void dismissForSession() {
    _sessionDismissed = true;
  }

  Future<void> dismissForDay() async {
    final day = _todayUtc();
    _dismissedUntilDay = day;
    _loaded = true;
    await _prefs.writeMap(prefsKey, {
      'dismissedUntilDay': day,
      'dismissedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  static String _todayUtc() {
    final now = DateTime.now().toUtc();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  static Future<void> clear() async {
    _sessionDismissed = false;
    _dismissedUntilDay = null;
    _loaded = false;
    if (!AppServices.isInitialized) return;
    await AppServices.instance.prefs.writeMap(prefsKey, {});
  }

  @visibleForTesting
  static Future<void> resetForTest() => clear();
}
