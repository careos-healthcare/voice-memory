import 'package:flutter/foundation.dart';

import '../../services/app_services.dart';
import '../../storage/mobile_prefs_store.dart';
import 'come_back_tomorrow_v2_model.dart';

/// Local-only storage for the active watch target.
class ComeBackTomorrowV2Store {
  ComeBackTomorrowV2Store(this._prefs);

  static const prefsKey = 'comeBackTomorrowV2Watch_v1';

  final MobilePrefsStore _prefs;

  static ActiveWatchTarget? _active;
  static bool _loaded = false;

  static ActiveWatchTarget? get active => _active;

  static bool get hasActive =>
      _active != null && _active!.groundedPhrase.trim().isNotEmpty;

  static ComeBackTomorrowV2Store instance() =>
      ComeBackTomorrowV2Store(AppServices.instance.prefs);

  static ComeBackTomorrowV2Store forPrefs(MobilePrefsStore prefs) =>
      ComeBackTomorrowV2Store(prefs);

  static Future<void> ensureLoaded() async {
    if (!AppServices.isInitialized) return;
    if (_loaded) return;
    final store = instance();
    _active = await store._load();
    _loaded = true;
  }

  Future<ActiveWatchTarget?> _load() async {
    final raw = await _prefs.readMap(prefsKey);
    if (raw == null || raw.isEmpty) return null;
    final phrase = raw['groundedPhrase'];
    final key = raw['watchKey'];
    final created = raw['createdDateKey'];
    final source = raw['source'];
    if (phrase is! String ||
        phrase.trim().isEmpty ||
        key is! String ||
        key.trim().isEmpty ||
        created is! String ||
        created.isEmpty ||
        source is! String ||
        source.isEmpty) {
      return null;
    }
    return ActiveWatchTarget(
      watchKey: key,
      groundedPhrase: phrase,
      createdDateKey: created,
      source: source,
      lastAnsweredDateKey: raw['lastAnsweredDateKey'] as String?,
      lastResponseType: raw['lastResponseType'] as String?,
      unrelatedSaveCount: raw['unrelatedSaveCount'] is int
          ? raw['unrelatedSaveCount'] as int
          : 0,
      quietSignalDismissed: raw['quietSignalDismissed'] == true,
      lastSeenDateKey: raw['lastSeenDateKey'] as String?,
      quietDetectedDateKey: raw['quietDetectedDateKey'] as String?,
    );
  }

  Map<String, dynamic> _serialize(ActiveWatchTarget target) => {
    'watchKey': target.watchKey,
    'groundedPhrase': target.groundedPhrase,
    'createdDateKey': target.createdDateKey,
    'source': target.source,
    if (target.lastAnsweredDateKey != null)
      'lastAnsweredDateKey': target.lastAnsweredDateKey,
    if (target.lastResponseType != null)
      'lastResponseType': target.lastResponseType,
    'unrelatedSaveCount': target.unrelatedSaveCount,
    'quietSignalDismissed': target.quietSignalDismissed,
    if (target.lastSeenDateKey != null)
      'lastSeenDateKey': target.lastSeenDateKey,
    if (target.quietDetectedDateKey != null)
      'quietDetectedDateKey': target.quietDetectedDateKey,
    'updatedAt': DateTime.now().toUtc().toIso8601String(),
  };

  Future<void> saveWatchTarget(ActiveWatchTarget target) async {
    _active = target;
    _loaded = true;
    await _prefs.writeMap(prefsKey, _serialize(target));
  }

  Future<void> setWatchTarget({
    required String watchKey,
    required String groundedPhrase,
    required String source,
    DateTime? now,
  }) async {
    final day = _dateKey(now ?? DateTime.now());
    await saveWatchTarget(
      ActiveWatchTarget(
        watchKey: watchKey,
        groundedPhrase: groundedPhrase,
        createdDateKey: day,
        source: source,
      ),
    );
  }

  Future<void> recordAnswer({
    required ComeBackTomorrowAnswerType answer,
    DateTime? now,
  }) async {
    final current = _active;
    if (current == null) return;
    final day = _dateKey(now ?? DateTime.now());
    final responseType = _answerKey(answer);
    await saveWatchTarget(
      current.copyWith(
        lastAnsweredDateKey: day,
        lastResponseType: responseType,
        unrelatedSaveCount: answer == ComeBackTomorrowAnswerType.cameBack
            ? 0
            : current.unrelatedSaveCount,
      ),
    );
  }

  Future<void> incrementUnrelatedSaveCount() async {
    final current = _active;
    if (current == null) return;
    await saveWatchTarget(
      current.copyWith(unrelatedSaveCount: current.unrelatedSaveCount + 1),
    );
  }

  Future<void> dismissQuietSignal() async {
    final current = _active;
    if (current == null) return;
    await saveWatchTarget(current.copyWith(quietSignalDismissed: true));
  }

  Future<void> recordQuietDetection({
    String? lastSeenDateKey,
    DateTime? now,
  }) async {
    final current = _active;
    if (current == null) return;
    final day = _dateKey(now ?? DateTime.now());
    await saveWatchTarget(
      current.copyWith(
        lastSeenDateKey: lastSeenDateKey ?? current.lastSeenDateKey,
        quietDetectedDateKey: current.quietDetectedDateKey ?? day,
      ),
    );
  }

  static String watchKeyForPhrase(String phrase) =>
      phrase.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static String _answerKey(ComeBackTomorrowAnswerType answer) =>
      switch (answer) {
        ComeBackTomorrowAnswerType.cameBack => 'came_back',
        ComeBackTomorrowAnswerType.notToday => 'not_today',
        ComeBackTomorrowAnswerType.different => 'different',
      };

  static String _dateKey(DateTime when) {
    final utc = when.toUtc();
    return '${utc.year.toString().padLeft(4, '0')}-'
        '${utc.month.toString().padLeft(2, '0')}-'
        '${utc.day.toString().padLeft(2, '0')}';
  }

  static int daysSinceDateKey(String dateKey, {DateTime? now}) {
    final parts = dateKey.split('-');
    if (parts.length != 3) return 0;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return 0;
    final created = DateTime.utc(year, month, day);
    final clock = (now ?? DateTime.now()).toUtc();
    final today = DateTime.utc(clock.year, clock.month, clock.day);
    return today.difference(created).inDays;
  }

  @visibleForTesting
  static void seedForTest(ActiveWatchTarget? target) {
    _active = target;
    _loaded = true;
  }

  static Future<void> resetPersistedState(MobilePrefsStore? prefs) async {
    _active = null;
    _loaded = false;
    if (prefs == null) return;
    await prefs.writeMap(prefsKey, {});
  }

  @visibleForTesting
  static Future<void> resetForTest(MobilePrefsStore? prefs) =>
      resetPersistedState(prefs);
}
