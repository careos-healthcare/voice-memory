import 'package:flutter/foundation.dart';

import '../../services/app_services.dart';
import '../../storage/mobile_prefs_store.dart';
import 'core_value_feedback_model.dart';

/// Local dismiss and answer state for core value beta feedback.
class CoreValueFeedbackStore {
  CoreValueFeedbackStore(this._prefs);

  static const prefsKey = 'archiveCoreValueFeedback_v1';
  static const dismissPrefsKey = 'archiveCoreValueFeedbackDismiss_v1';

  final MobilePrefsStore _prefs;

  static CoreValueFeedbackRecord _cached = CoreValueFeedbackRecord.empty;
  static bool _answerLoaded = false;

  static bool _sessionDismissed = false;
  static String? _dismissedUntilDay;
  static bool _dismissLoaded = false;

  static CoreValueFeedbackRecord get cached => _cached;

  static bool get sessionDismissed => _sessionDismissed;

  static bool get isDismissed {
    if (_sessionDismissed) return true;
    final day = _dismissedUntilDay;
    if (day == null || day.isEmpty) return false;
    return day == _todayUtc();
  }

  static CoreValueFeedbackStore instance() =>
      CoreValueFeedbackStore(AppServices.instance.prefs);

  static Future<void> ensureLoaded() async {
    if (!AppServices.isInitialized) return;
    if (!_answerLoaded) {
      _cached = await instance().loadAnswer();
      _answerLoaded = true;
    }
    if (!_dismissLoaded) {
      _dismissedUntilDay = await instance().loadDismissDay();
      _dismissLoaded = true;
    }
  }

  Future<CoreValueFeedbackRecord> loadAnswer() async {
    final raw = await _prefs.readMap(prefsKey);
    return CoreValueFeedbackRecord.fromJson(raw);
  }

  Future<String?> loadDismissDay() async {
    final raw = await _prefs.readMap(dismissPrefsKey);
    final day = raw?['dismissedUntilDay'];
    return day is String && day.isNotEmpty ? day : null;
  }

  Future<void> saveAnswer({
    required CoreValueFeedbackAnswer answer,
    required int entryCount,
    required CoreValueFeedbackSource source,
  }) async {
    final record = CoreValueFeedbackRecord(
      answer: answer,
      timestamp: DateTime.now().toUtc(),
      entryCount: entryCount,
      source: source,
    );
    await _prefs.writeMap(prefsKey, record.toJson());
    _cached = record;
    _answerLoaded = true;
    _sessionDismissed = false;
    _dismissedUntilDay = null;
    _dismissLoaded = true;
    await _prefs.writeMap(dismissPrefsKey, {});
  }

  void dismissForSession() {
    _sessionDismissed = true;
  }

  Future<void> dismissForDay() async {
    final day = _todayUtc();
    _dismissedUntilDay = day;
    _dismissLoaded = true;
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

  static Future<void> resetPersistedState() async {
    _cached = CoreValueFeedbackRecord.empty;
    _answerLoaded = false;
    _sessionDismissed = false;
    _dismissedUntilDay = null;
    _dismissLoaded = false;
    if (!AppServices.isInitialized) return;
    final prefs = AppServices.instance.prefs;
    await prefs.writeMap(prefsKey, {});
    await prefs.writeMap(dismissPrefsKey, {});
  }

  @visibleForTesting
  static Future<void> resetForTest() => resetPersistedState();
}
