import 'package:flutter/foundation.dart';

import '../../services/app_services.dart';

/// Session + daily dismiss for the monthly private report preview.
abstract final class MonthlyPrivateReportDismissStore {
  MonthlyPrivateReportDismissStore._();

  static const prefsKey = 'monthlyPrivateReportDismissedDateKey_v1';

  static bool _sessionDismissed = false;
  static String? _loadedDateKey;
  static bool _loaded = false;

  static Future<void> ensureLoaded() async {
    if (_loaded || !AppServices.isInitialized) return;
    _loadedDateKey = await AppServices.instance.prefs.readString(prefsKey);
    _loaded = true;
  }

  static bool isDismissed({DateTime? now}) {
    if (_sessionDismissed) return true;
    final stored = _loadedDateKey;
    if (stored == null || stored.isEmpty) return false;
    return stored == _dateKey(now ?? DateTime.now());
  }

  static Future<void> dismiss({DateTime? now}) async {
    _sessionDismissed = true;
    final day = _dateKey(now ?? DateTime.now());
    _loadedDateKey = day;
    _loaded = true;
    if (!AppServices.isInitialized) return;
    await AppServices.instance.prefs.writeString(prefsKey, day);
  }

  static String _dateKey(DateTime when) {
    final utc = when.toUtc();
    return '${utc.year.toString().padLeft(4, '0')}-'
        '${utc.month.toString().padLeft(2, '0')}-'
        '${utc.day.toString().padLeft(2, '0')}';
  }

  @visibleForTesting
  static void invalidateSessionForTest() {
    _sessionDismissed = false;
    _loadedDateKey = null;
    _loaded = false;
  }

  static Future<void> clear() async {
    invalidateSessionForTest();
    if (!AppServices.isInitialized) return;
    await AppServices.instance.prefs.writeString(prefsKey, '');
  }

  @visibleForTesting
  static Future<void> resetForTest() => clear();
}
