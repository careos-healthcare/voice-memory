import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter/foundation.dart';

abstract final class ProUnderstandingLiftStore {
  ProUnderstandingLiftStore._();

  static const dismissPrefsKey = 'proUnderstandingLiftDismiss_v1';

  static String? _dismissedUntilDay;
  static bool _loaded = false;

  static bool get isDismissedToday {
    final day = _dismissedUntilDay;
    return day != null && day.isNotEmpty && day == _todayUtc();
  }

  static Future<void> ensureLoaded() async {
    if (!AppServices.isInitialized) return;
    if (_loaded) return;
    final raw = await AppServices.instance.prefs.readMap(dismissPrefsKey);
    final day = raw?['dismissedUntilDay'];
    _dismissedUntilDay = day is String && day.isNotEmpty ? day : null;
    _loaded = true;
  }

  static Future<void> dismissForDay() async {
    final day = _todayUtc();
    _dismissedUntilDay = day;
    _loaded = true;
    if (!AppServices.isInitialized) return;
    await AppServices.instance.prefs.writeMap(dismissPrefsKey, {
      'dismissedUntilDay': day,
      'dismissedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  static Future<void> dismissForDayWithPrefs(MobilePrefsStore prefs) async {
    final day = _todayUtc();
    _dismissedUntilDay = day;
    _loaded = true;
    await prefs.writeMap(dismissPrefsKey, {
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
    _dismissedUntilDay = null;
    _loaded = false;
    if (prefs == null) return;
    await prefs.writeMap(dismissPrefsKey, {});
  }
}