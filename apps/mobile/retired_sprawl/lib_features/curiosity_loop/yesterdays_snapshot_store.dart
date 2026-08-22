import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter/foundation.dart';

/// Local once-per-day presentation state for Yesterday's Snapshot.
class YesterdaysSnapshotStore {
  YesterdaysSnapshotStore(this._prefs);

  static const presentPrefsKey = 'yesterdaysSnapshotPresent_v1';
  static const dismissPrefsKey = 'yesterdaysSnapshotDismiss_v1';

  final MobilePrefsStore _prefs;

  static String? _presentedHookId;
  static String? _presentedDay;
  static String? _dismissedUntilDay;
  static bool _loaded = false;

  static bool get isDismissedToday {
    final day = _dismissedUntilDay;
    return day != null && day.isNotEmpty && day == _todayUtc();
  }

  static bool presentedTodayForHook(String hookId) {
    if (hookId.isEmpty) return false;
    return _presentedDay == _todayUtc() && _presentedHookId == hookId;
  }

  static YesterdaysSnapshotStore instance() =>
      YesterdaysSnapshotStore(AppServices.instance.prefs);

  static YesterdaysSnapshotStore forPrefs(MobilePrefsStore prefs) =>
      YesterdaysSnapshotStore(prefs);

  static Future<void> ensureLoaded() async {
    if (!AppServices.isInitialized) return;
    if (_loaded) return;
    final store = instance();
    _presentedHookId = await store._loadPresentedHookId();
    _presentedDay = await store._loadPresentedDay();
    _dismissedUntilDay = await store._loadDismissDay();
    _loaded = true;
  }

  Future<String?> _loadPresentedHookId() async {
    final raw = await _prefs.readMap(presentPrefsKey);
    final hookId = raw?['hookId'];
    return hookId is String && hookId.isNotEmpty ? hookId : null;
  }

  Future<String?> _loadPresentedDay() async {
    final raw = await _prefs.readMap(presentPrefsKey);
    final day = raw?['dateKey'];
    return day is String && day.isNotEmpty ? day : null;
  }

  Future<String?> _loadDismissDay() async {
    final raw = await _prefs.readMap(dismissPrefsKey);
    final day = raw?['dismissedUntilDay'];
    return day is String && day.isNotEmpty ? day : null;
  }

  Future<void> markPresentedToday(String hookId) async {
    if (hookId.isEmpty) return;
    final day = _todayUtc();
    _presentedHookId = hookId;
    _presentedDay = day;
    _loaded = true;
    await _prefs.writeMap(presentPrefsKey, {
      'hookId': hookId,
      'dateKey': day,
      'presentedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> dismissForDay() async {
    final day = _todayUtc();
    _dismissedUntilDay = day;
    _loaded = true;
    await _prefs.writeMap(dismissPrefsKey, {
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

  @visibleForTesting
  static Future<void> resetForTest(MobilePrefsStore? prefs) async {
    _presentedHookId = null;
    _presentedDay = null;
    _dismissedUntilDay = null;
    _loaded = false;
    if (prefs == null) return;
    await prefs.writeMap(presentPrefsKey, {});
    await prefs.writeMap(dismissPrefsKey, {});
  }
}