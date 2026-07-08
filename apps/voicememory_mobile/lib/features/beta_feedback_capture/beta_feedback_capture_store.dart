import 'package:flutter/foundation.dart';

import '../../services/app_services.dart';
import '../../storage/mobile_prefs_store.dart';
import 'beta_feedback_capture_model.dart';

/// Local-only beta feedback capture — metadata answers, optional free text.
class BetaFeedbackCaptureStore {
  BetaFeedbackCaptureStore(this._prefs);

  static const prefsKey = 'betaFeedbackCapture_v1';

  final MobilePrefsStore _prefs;

  static final Map<BetaFeedbackCaptureMoment, BetaFeedbackCaptureRecord> _cached =
      {};
  static bool _loaded = false;

  static BetaFeedbackCaptureRecord recordFor(BetaFeedbackCaptureMoment moment) =>
      _cached[moment] ?? BetaFeedbackCaptureRecord.empty;

  static bool isAnsweredToday(BetaFeedbackCaptureMoment moment) {
    final record = recordFor(moment);
    final day = record.dateKey;
    return record.answered &&
        day != null &&
        day.isNotEmpty &&
        day == _todayUtc();
  }

  static bool isDismissedToday(BetaFeedbackCaptureMoment moment) {
    final record = recordFor(moment);
    final day = record.dateKey;
    return record.dismissed &&
        !record.answered &&
        day != null &&
        day.isNotEmpty &&
        day == _todayUtc();
  }

  static bool isResolvedToday(BetaFeedbackCaptureMoment moment) =>
      isAnsweredToday(moment) || isDismissedToday(moment);

  static BetaFeedbackCaptureRecord? get latestAnsweredRecord {
    BetaFeedbackCaptureRecord? latest;
    for (final record in _cached.values) {
      if (!record.answered || record.answeredAt == null) continue;
      if (latest == null ||
          record.answeredAt!.isAfter(latest.answeredAt!)) {
        latest = record;
      }
    }
    return latest;
  }

  static BetaFeedbackCaptureStore instance() =>
      BetaFeedbackCaptureStore(AppServices.instance.prefs);

  static BetaFeedbackCaptureStore forPrefs(MobilePrefsStore prefs) =>
      BetaFeedbackCaptureStore(prefs);

  static Future<void> ensureLoaded() async {
    if (!AppServices.isInitialized) return;
    if (_loaded) return;
    final store = instance();
    final raw = await store._prefs.readMap(prefsKey);
    _hydrateFromRaw(raw);
    _loaded = true;
  }

  static void _hydrateFromRaw(Map<String, dynamic>? raw) {
    _cached.clear();
    if (raw == null || raw.isEmpty) return;
    final answers = raw['answers'];
    if (answers is! Map) return;
    for (final moment in BetaFeedbackCaptureMoment.values) {
      final entry = answers[moment.storageValue];
      if (entry is Map<String, dynamic>) {
        _cached[moment] = BetaFeedbackCaptureRecord.fromJson(entry);
      } else if (entry is Map) {
        _cached[moment] =
            BetaFeedbackCaptureRecord.fromJson(Map<String, dynamic>.from(entry));
      }
    }
  }

  Future<void> saveAnswer({
    required BetaFeedbackCaptureMoment moment,
    required String answerId,
    required int entryCount,
    required String source,
    String? freeTextLocal,
  }) async {
    final day = _todayUtc();
    final record = BetaFeedbackCaptureRecord(
      moment: moment,
      answerId: answerId,
      dateKey: day,
      source: source,
      entryCount: entryCount,
      freeTextLocal: freeTextLocal,
      answeredAt: DateTime.now().toUtc(),
    );
    _cached[moment] = record;
    _loaded = true;
    await _persist();
  }

  static Future<void> dismissForDay(BetaFeedbackCaptureMoment moment) async {
    if (!AppServices.isInitialized) {
      final day = _todayUtc();
      _cached[moment] = BetaFeedbackCaptureRecord(
        moment: moment,
        dateKey: day,
        dismissed: true,
        answeredAt: DateTime.now().toUtc(),
      );
      _loaded = true;
      return;
    }
    await dismissForDayWithPrefs(AppServices.instance.prefs, moment);
  }

  static Future<void> dismissForDayWithPrefs(
    MobilePrefsStore prefs,
    BetaFeedbackCaptureMoment moment,
  ) async {
    final day = _todayUtc();
    _cached[moment] = BetaFeedbackCaptureRecord(
      moment: moment,
      dateKey: day,
      dismissed: true,
      answeredAt: DateTime.now().toUtc(),
    );
    _loaded = true;
    await BetaFeedbackCaptureStore(prefs)._persist();
  }

  Future<void> dismissMomentForDay(BetaFeedbackCaptureMoment moment) async {
    await BetaFeedbackCaptureStore.dismissForDayWithPrefs(_prefs, moment);
  }

  Future<void> _persist() async {
    final answers = <String, dynamic>{
      for (final item in BetaFeedbackCaptureMoment.values)
        item.storageValue: (_cached[item] ?? BetaFeedbackCaptureRecord.empty)
            .toJson(),
    };
    await _prefs.writeMap(prefsKey, {'answers': answers});
  }

  static String _todayUtc() {
    final now = DateTime.now().toUtc();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  @visibleForTesting
  static Future<void> resetForTest(MobilePrefsStore? prefs) async {
    _cached.clear();
    _loaded = false;
    if (prefs == null) return;
    await prefs.writeMap(prefsKey, {});
  }
}
