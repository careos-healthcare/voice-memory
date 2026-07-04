import 'package:flutter/foundation.dart';

import '../../services/app_services.dart';
import '../../storage/mobile_prefs_store.dart';
import 'return_day_flow_model.dart';

/// Local dismiss and answer state for Return Day Flow v2.
class ReturnDayFlowStore {
  ReturnDayFlowStore(this._prefs);

  static const dismissPrefsKey = 'returnDayFlowDismiss_v1';
  static const answerPrefsKey = 'returnDayFlowAnswer_v1';

  final MobilePrefsStore _prefs;

  static String? _dismissedUntilDay;
  static String? _answeredDay;
  static ReturnDayFlowAnswer? _todayAnswer;
  static bool _loaded = false;

  static ReturnDayFlowAnswer? get todayAnswer => _todayAnswer;

  static bool get isDismissedToday {
    final day = _dismissedUntilDay;
    return day != null && day.isNotEmpty && day == _todayUtc();
  }

  static bool get answeredToday {
    return _answeredDay == _todayUtc() && _todayAnswer != null;
  }

  static ReturnDayFlowStore instance() =>
      ReturnDayFlowStore(AppServices.instance.prefs);

  static ReturnDayFlowStore forPrefs(MobilePrefsStore prefs) =>
      ReturnDayFlowStore(prefs);

  static Future<void> ensureLoaded() async {
    if (!AppServices.isInitialized) return;
    if (_loaded) return;
    final store = instance();
    _dismissedUntilDay = await store._loadDismissDay();
    final answer = await store._loadTodayAnswer();
    _answeredDay = answer?.$1;
    _todayAnswer = answer?.$2;
    _loaded = true;
  }

  Future<String?> _loadDismissDay() async {
    final raw = await _prefs.readMap(dismissPrefsKey);
    final day = raw?['dismissedUntilDay'];
    return day is String && day.isNotEmpty ? day : null;
  }

  Future<(String, ReturnDayFlowAnswer)?> _loadTodayAnswer() async {
    final raw = await _prefs.readMap(answerPrefsKey);
    final day = raw?['dateKey'];
    final answerRaw = raw?['answer'];
    if (day is! String || day.isEmpty) return null;
    final answer = _parseAnswer(answerRaw);
    if (answer == null) return null;
    return (day, answer);
  }

  static ReturnDayFlowAnswer? _parseAnswer(Object? raw) => switch (raw) {
        'came_back' => ReturnDayFlowAnswer.cameBack,
        'not_today' => ReturnDayFlowAnswer.notToday,
        'different' => ReturnDayFlowAnswer.different,
        _ => null,
      };

  static String _answerKey(ReturnDayFlowAnswer answer) => switch (answer) {
        ReturnDayFlowAnswer.cameBack => 'came_back',
        ReturnDayFlowAnswer.notToday => 'not_today',
        ReturnDayFlowAnswer.different => 'different',
      };

  Future<void> dismissForDay() async {
    final day = _todayUtc();
    _dismissedUntilDay = day;
    _loaded = true;
    await _prefs.writeMap(dismissPrefsKey, {
      'dismissedUntilDay': day,
      'dismissedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> saveTodayAnswer(ReturnDayFlowAnswer answer) async {
    final day = _todayUtc();
    _answeredDay = day;
    _todayAnswer = answer;
    _loaded = true;
    if (answer == ReturnDayFlowAnswer.notToday) {
      await dismissForDay();
      return;
    }
    await _prefs.writeMap(answerPrefsKey, {
      'dateKey': day,
      'answer': _answerKey(answer),
      'answeredAt': DateTime.now().toUtc().toIso8601String(),
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
    _answeredDay = null;
    _todayAnswer = null;
    _loaded = false;
    if (prefs == null) return;
    await prefs.writeMap(dismissPrefsKey, {});
    await prefs.writeMap(answerPrefsKey, {});
  }
}
