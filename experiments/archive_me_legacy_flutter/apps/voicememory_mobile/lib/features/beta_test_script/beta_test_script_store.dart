import 'package:flutter/foundation.dart';

import '../../services/app_services.dart';
import '../../storage/mobile_prefs_store.dart';

/// Local-only beta tester script progress — never touches journal data.
class BetaTestScriptStore {
  BetaTestScriptStore(this._prefs);

  static const prefsKey = 'betaTestScriptProgress_v1';

  final MobilePrefsStore _prefs;

  static BetaTestScriptProgressRecord _cached =
      BetaTestScriptProgressRecord.empty;
  static bool _loaded = false;

  static BetaTestScriptProgressRecord get cached => _cached;

  static BetaTestScriptStore instance() =>
      BetaTestScriptStore(AppServices.instance.prefs);

  static BetaTestScriptStore forPrefs(MobilePrefsStore prefs) =>
      BetaTestScriptStore(prefs);

  static Future<void> ensureLoaded() async {
    if (_loaded || !AppServices.isInitialized) return;
    _cached = await instance()._load();
    _loaded = true;
  }

  Future<BetaTestScriptProgressRecord> _load() async {
    final raw = await _prefs.readMap(prefsKey);
    if (raw == null || raw.isEmpty) {
      return BetaTestScriptProgressRecord.empty;
    }
    return BetaTestScriptProgressRecord(
      day1Seen: raw['day1Seen'] == true,
      day2Seen: raw['day2Seen'] == true,
      day3Seen: raw['day3Seen'] == true,
      dismissed: raw['dismissed'] == true,
      startedDateKey: raw['startedDateKey'] as String?,
    );
  }

  Map<String, dynamic> _serialize(BetaTestScriptProgressRecord record) => {
    'day1Seen': record.day1Seen,
    'day2Seen': record.day2Seen,
    'day3Seen': record.day3Seen,
    'dismissed': record.dismissed,
    if (record.startedDateKey != null) 'startedDateKey': record.startedDateKey,
    'updatedAt': DateTime.now().toUtc().toIso8601String(),
  };

  Future<void> save(BetaTestScriptProgressRecord record) async {
    _cached = record;
    _loaded = true;
    await _prefs.writeMap(prefsKey, _serialize(record));
  }

  Future<void> markStepSeen(String stepKey) async {
    final current = _cached;
    final started = current.startedDateKey ?? _dateKey(DateTime.now());
    await save(
      current.copyWith(
        startedDateKey: started,
        day1Seen: stepKey == 'day_1' ? true : current.day1Seen,
        day2Seen: stepKey == 'day_2' ? true : current.day2Seen,
        day3Seen: stepKey == 'day_3' ? true : current.day3Seen,
      ),
    );
  }

  Future<void> dismiss() async {
    await save(_cached.copyWith(dismissed: true));
  }

  Future<void> resetProgress() async {
    await save(BetaTestScriptProgressRecord.empty);
  }

  static String _dateKey(DateTime when) {
    final utc = when.toUtc();
    return '${utc.year.toString().padLeft(4, '0')}-'
        '${utc.month.toString().padLeft(2, '0')}-'
        '${utc.day.toString().padLeft(2, '0')}';
  }

  @visibleForTesting
  static void seedForTest(BetaTestScriptProgressRecord? record) {
    _cached = record ?? BetaTestScriptProgressRecord.empty;
    _loaded = true;
  }

  static Future<void> clear(MobilePrefsStore? prefs) async {
    _cached = BetaTestScriptProgressRecord.empty;
    _loaded = false;
    if (prefs == null) return;
    await prefs.writeMap(prefsKey, {});
  }

  @visibleForTesting
  static Future<void> resetForTest(MobilePrefsStore? prefs) => clear(prefs);
}

class BetaTestScriptProgressRecord {
  const BetaTestScriptProgressRecord({
    this.day1Seen = false,
    this.day2Seen = false,
    this.day3Seen = false,
    this.dismissed = false,
    this.startedDateKey,
  });

  static const empty = BetaTestScriptProgressRecord();

  final bool day1Seen;
  final bool day2Seen;
  final bool day3Seen;
  final bool dismissed;
  final String? startedDateKey;

  BetaTestScriptProgressRecord copyWith({
    bool? day1Seen,
    bool? day2Seen,
    bool? day3Seen,
    bool? dismissed,
    String? startedDateKey,
  }) => BetaTestScriptProgressRecord(
    day1Seen: day1Seen ?? this.day1Seen,
    day2Seen: day2Seen ?? this.day2Seen,
    day3Seen: day3Seen ?? this.day3Seen,
    dismissed: dismissed ?? this.dismissed,
    startedDateKey: startedDateKey ?? this.startedDateKey,
  );
}
